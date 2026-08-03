# The on-screen FPS gauge: sweep, and extract it to one shared component

**Date:** 2026-08-03 · **Status:** PLANNED
**Prompted by:** a live-page defect on [/snes/apollo-daylight/](https://biohack.net/snes/apollo-daylight/) —
the gauge read **59.1** once at startup and then settled at **60.1** on a cartridge billed as
59.94 fps. Fixed in `2db2cf0`; see
[the Apollo plan](2026-08-02-apollo-daylight-video-rom.md) §8 for that diagnosis.
**Follow-on question from the user:** *are the other FPS readouts behaving the same, and can this be
one file/function instead of copies?*

## The sweep — done first, because it decides the scope

Every `.c` under `examples/snes/` mentioning fps/FPS was inspected. **Only two ROMs draw a live
gauge**; the other seven mention 60 fps in comments and draw nothing.

| ROM | scale constant | sampler called | verdict |
|---|---|---|---|
| `snes-video-reel.c` | **600** (correct) | `dashboard_prepare()`, *before* the deadline wait *and* before `present_frame()` | **reads a flat 60.0 — correct, but by luck** |
| `apollo-reel.c` (before `2db2cf0`) | **601** | `dashboard_update()`, *after* the deadline wait, before `present_frame()` | 59.1 once, then 60.1 |
| `blossom.c`, `burning-ship.c`, `julia.c`, `mvscrl.c`, `polyfill.c`, `trimerge.c`, `truncstair.c` | — | — | no gauge; comments only |

Both verdicts are **measured, not reasoned**. `dashboard_fps` is a 5-byte string in low WRAM, so it
can be read straight out of the running console:

```
$ build/jgxcheck build/svx2-video-reel.sfc … 0x20 4 0 <N>      # snes-video-reel, WRAM $0020
VBlank   100  dashboard_fps='00.0'  fps_tenths=  0
VBlank   200  dashboard_fps='00.0'  fps_tenths=  0
VBlank   400  dashboard_fps='60.0'  fps_tenths=600
VBlank   900  dashboard_fps='60.0'  fps_tenths=600
VBlank  1800  dashboard_fps='60.0'  fps_tenths=600

$ build/jgxcheck build/apollo-daylight.sfc … 0x20 4 0 <N>      # apollo-reel, after 2db2cf0
VBlank   100  '00.0'   VBlank 160  '00.0'   VBlank 300  '60.0'
VBlank   700  '60.0'   VBlank 1400 '60.0'   VBlank 2600 '60.0'
```

### The interesting part: the reel is correct by an accident that does not survive being copied

The sampler reads `presented_total` **before** the present it is about to do — that is an off-by-one
in both ROMs. The reel gets away with it because `dashboard_prepare()` is also called one VBlank
**early**, before the deadline wait, so `dv` is short by one at exactly the same moment `dp` is
short by one:

```
reel     iteration k:  sample at vblank t0+k-1  ->  dv = k-1,  dp = k-1   ->  ratio right
apollo   iteration k:  sample at vblank t0+k    ->  dv = k,    dp = k-1   ->  first window reads 59/60
```

Two compensating errors that happen to cancel. Apollo was copied from the reel, moved the call after
the deadline wait for a good and unrelated reason (formatting must not straddle the wait), and the
cancellation silently broke. **That is the whole argument for this change:** the gauge is correct in
one ROM for a reason that is invisible at the call site and destroyed by a legitimate edit anywhere
near it.

### Second finding: no gate has ever asserted the gauge

`snes-video-reel.c` exports `fps_tenths` as a `volatile` — and **nothing reads it**.
`dev/snes-video-reel.sh`, `dev/snes-video-native60.sh` and `dev/snes-video-artemis-apollo.sh` all
read `video_reel_presented_total` and compute cadence themselves; none looks at the number the
cartridge actually *displays*. That is exactly why a wrong gauge reached a published page and was
found by a human watching it rather than by CI.

## What the gauge means — settled here, once

Units are **presented frames per 600 VBlanks, shown with one decimal**. This is deliberately the
same measurement the build gates' cadence tables publish, so the HUD and the docs cannot disagree.
One frame per VBlank reads `60.0`; a 2-VBlank cadence reads `30.0`.

Rejected: scaling by the true NTSC VBlank rate (60.0988 Hz), which is what Apollo's `601` did. It is
arithmetically honest — one frame per VBlank really is 60.1 presents per wall second — and it is the
wrong number to show, because it invites "why does the 59.94 fps demo say 60.1?" from every viewer,
forever. The source rate is a property of the *source*; this gauge measures the *presentation*.

`"00.0"` before the first sample lands is **kept and specified**, not a placeholder to be tidied
away. It means "not measured yet" for the first second of playback. Seeding the gauge with a number
the ROM has not measured is the decorative-gauge failure mode this project keeps catching (the
cartsize canary's vacuous entropy step, #138's silently-skipped producer, and Apollo's own 37 s of
black behind four green gates).

## Design

**`examples/snes/video_fps.h`** — header-only, `static inline` + file-static state, matching
`video_hud.h`'s existing pattern exactly (both ROMs already include it, and it needs no build-system
change).

```c
video_fps_reset(uint16_t presented, uint16_t vblank);   /* after the first present */
video_fps_sample(uint16_t presented, uint16_t vblank);  /* AFTER present_frame(), every frame */
const char *video_fps_text(void);                       /* "00.0" | "60.0" | … */
uint16_t video_fps_tenths(void);                        /* the same value as a number, for gates */
```

Both counters are passed in rather than read from globals, because the two ROMs name them
differently (`video_reel_*` vs `apollo_reel_*`) and deliberately do not share symbols — the ROMs
must stay separately linkable in one session.

The contract that fixes the class of bug: **`video_fps_sample()` is called after the present, always,
and its doc comment says why in one line.** The compensating-offsets trick is deleted, not
preserved; the reel moves to the explicit ordering even though its current output is already right.

Deliberately **not** in scope: the `TIME` field, the `SLIP` indicator, the transport row. They are
per-ROM and share no arithmetic.

## Visible surface

The gauge is the visible surface, so the states are mocked in
[`2026-08-03-snes-fps-gauge-sweep-and-shared-component/`](2026-08-03-snes-fps-gauge-sweep-and-shared-component/):

[![HUD FPS field states](2026-08-03-snes-fps-gauge-sweep-and-shared-component/fps-states.png)](2026-08-03-snes-fps-gauge-sweep-and-shared-component/fps-states.html)

Four real states, including the two wrong ones for contrast: unsampled `00.0`, locked `60.0`, the
shipped-and-fixed `59.1`/`60.1`, and a slipping build showing both a reduced rate and `SLIP`.

## Verification

1. `video_fps.h` exists; both ROMs include it and neither carries its own copy of the arithmetic —
   `grep -c 'dp \* 60' examples/snes/*.c` returns 0.
2. Reel gauge unchanged by the refactor: `dashboard_fps` reads `00.0` then a flat `60.0` at
   VBlanks 100/200/400/900/1800, matching the pre-refactor capture above byte for byte.
3. Apollo gauge unchanged: `00.0` then flat `60.0` at VBlanks 100/160/300/700/1400/2600.
4. A 2-VBlank-cadence build reads `30.0`, proving the units are cadence-derived and not hardcoded.
5. Both ROMs' existing gates still pass in full (`dev/snes-video-reel.sh`, `dev/apollo-reel.sh`) —
   whole-loop byte-correct decode, negative control, cadence, entropy, black-screen guard.
6. **New gate step in both scripts:** assert the displayed gauge, not just the internal counter —
   fail if the steady-state reading is not `60.0`, and fail if any sample before it is anything
   other than `00.0`. This is the step whose absence let 59.1/60.1 reach the live page.
7. `-verify-machineinstrs` clean on both ROMs.

## Risk

Low and bounded: no codec, stream, DMA or timing path is touched, and both streams stay
byte-identical. The real risk is the refactor perturbing VBlank timing in the reel, whose margin is
thinner than Apollo's — so step 5 runs the reel's full cadence gate rather than trusting that a
header-only change is free.
