# SNES display-quality contract

This is the required display contract for SNES ROMs in this repository.

## Safe PPU access

VRAM (`$2118/$2119`), CGRAM (`$2122`), and OAM (`$2104`) writes are legal only
while force blank is active during boot, or during VBlank. HBlank is not a
practical general-purpose upload window. Use HDMA for controlled per-scanline
register changes.

New demos should use `snesgfx/display.h` and `snesgfx/upload.h`:

1. Build the next frame in WRAM.
2. Queue bounded upload jobs.
3. Call `display_frame()` once.
4. `display_frame()` emits register state, waits for a fresh VBlank, flushes
   queued DMA, and enables the already-complete frame.

Do not write PPU data ports from the paint/computation loop. Boot-time helpers
may write directly only before the first visible application frame.

## No runtime reblanking

After application video is enabled, do not set bit 7 of `INIDISP`. Runtime
force blank turns a missed upload deadline into a visible black band.

The sole standard exception is the title-to-application handoff: the title
returns with force blank active, then application setup completes and enables
video. It is a one-way startup state transition, not a frame update technique.

## Cadence and atomic presentation

The default target is one presentation per NTSC VBlank (approximately 60 Hz).
Simulation or rendering work may span frames, but input and presentation must
continue each frame. A completed logical image becomes visible atomically in
VBlank; do not reveal half-painted state.

Keep the worst-case queued transfer below `UPQ_VBLANK_BUDGET`. Prefer dirty
tiles, bounded bands, double buffering, or staged work over a large synchronous
upload. OAM should be built in shadow memory and transferred as one unit.

“60 fps” describes presentation cadence, not a requirement to finish one whole
simulation step per frame. PAL remains safe but naturally presents at 50 Hz.

## Other quality rules

- Sample the controller once per frame; navigation/cancel input preempts work.
- Give each DMA/HDMA channel one documented owner.
- Do not modify an enabled HDMA channel's table or registers.
- Commit mutually dependent palette, tile, tilemap, and OAM changes together.
- Avoid unbounded work between presentations.
- Keep overscan and visible-line assumptions explicit.
- Never use forced blank to hide tearing or missed deadlines.

## Running the gates

```sh
task snes-display-quality
task snes-display-quality-emulator SITE=/home/will/biohack.net
```

The first command is dependency-free and runs on each commit. It compares
sensitive access sites with `dev/snes-display-quality-baseline.json`, so legacy
code cannot normalize new unsafe accesses. If an intentional access is added,
first make its timing proof clear in code review, then regenerate and inspect:

```sh
dev/snes-display-quality.py --update-baseline
git diff -- dev/snes-display-quality-baseline.json
```

`SNESDQ_SKIP=1 git commit ...` is an emergency local bypass. It does not bypass
CI. The emulator gate uses the built `jgxcheck` and published manifest to verify
ROM self-checks and scan every rendered frame for transient force-blank bleed.
