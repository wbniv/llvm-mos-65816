# snesgfx formal verification: `mandel-oop.c`

**Date:** 2026-06-30
**Status:** IN PROGRESS
**Issue:** #321 (M2) — closes snesgfx `[ ]` and Space Invaders `[ ]` TODOs

## Context

The `snesgfx` OOP-in-C library is complete: 12 committed headers, all 29 SNES demos use it.
Space Invaders proved the full OOP stack at production scale (SpriteSet + Controller + TitleLayer,
CRC `0x9D57`, five-way GREEN, live at biohack.net/snes/space-invaders/). The snesgfx TODO item
`[ ]` has one outstanding deliverable: `mandel-oop.c` — a formal verification client that:

1. Wraps **Mode 7** in an OOP `Drawable` (the one rendering mode not yet in the snesgfx repertoire)
2. Reproduces `mandel-display.c`'s CRC **`0x204F`** via the OOP interface, proving zero regression
   from encapsulation
3. Shows the dispatch is coarse-grained (one virtual call/drawable/frame, never in the escape-time
   loop) — measurable by disasm since MandelLayer is the only drawable

Once the gate passes, both TODOs close: `snesgfx [ ]` formally proved, `Space Invaders [ ]` stale
(already live).

## Design

### `MandelLayer` — custom Mode 7 Drawable

OOP rules observed throughout:
- `main()` zero bare `REG_*`/`snes_*` calls — only `display_init`, `display_add`, `display_frame`
- `reserve()`: Mode 7 setup + full grid computation + VRAM upload (direct PPU writes OK in
  force-blank — the established pattern in bitmap_canvas, sprite_set, etc.)
- `emit()`: colour cycle via `upq_push_cgram`, matrix animation via `upq_push_scroll` (UPQ_REG
  write-twice poke reused for M7A/B/C/D) — all queued, flushed in v-blank

`base.tm_bits = TM_BG1` — Display manages `REG_TM` via its shadow; `reserve()` must NOT call
`m7_begin()` (which writes `REG_TM` directly, bypassing the shadow). Instead set `REG_BGMODE =
BGMODE_7` and `REG_M7SEL = 0` directly.

### Computation (in `reserve()`, force-blanked)

Same grid and math as `mandel-display.c`:
- 64×56 = DW×DH pixels, DN=15 iterations, Q5.10 fixed-point
- Far stores to `fb` at `$7E2000` via `mandel_cell()` from `../65816/mandel.h`
- `corpus_result = crc_fb()` (far loads over the whole buffer) → `0x204F`
- Upload to Mode 7 VRAM via 7 coarse tile-row DMAs (still force-blanked)
- Center at (32,28), scroll at (-96,-84) for the 4× framed view

Since computation + VRAM upload happen in `reserve()` (force-blank), `display_frame()` releases
force-blank on the very first call — screen goes from black straight to the full Mandelbrot.

### Steady-state `emit()` (v-blank, via queue)

Each frame enqueues 5 jobs (within UPQ_MAX_JOBS=16):
1. `upq_push_cgram` — rotated palette (32 bytes) for colour shimmer
2–5. `upq_push_scroll` × 4 — M7A, M7B, M7C, M7D for the spin+zoom animation

### Gate

- **Frames:** 500 (computation finishes within ~50 frames; 450 frames of steady state for screenshot)
- **MAME:** skip if no SPC700 IPL (env-wide non-blocker, same policy as other demos)
- **Disasm check:** `llvm-objdump -d build/mandel-oop.sfc.elf | grep 'jmp\b'` → exactly 2 indirect
  jumps per frame (one for `scene_emit`→`drawable_emit` dispatch, one for the vtable call) —
  confirms coarse-grained virtual dispatch, zero in the inner loop

## Files

| File | Action |
|---|---|
| `examples/snes/mandel-oop.c` | Create |
| `dev/mandel-oop.sh` | Create (modelled on `dev/mandel-shot.sh`) |
| `Taskfile.yml` | Add `mandel-oop` + `mandel-oop-play` tasks |
| `docs/oop-in-c.md` | Create with §4 dispatch cost + §5 size delta |
| `docs/plans/2026-06-26-snes-rendering-oop-library.md` | Paste verification output §8 |
| `TODO.md` | Mark snesgfx `[x]` and Space Invaders `[x]` |

## Verification §

1. Host oracle confirms `corpus_result` == `0x204F`
2. `dev/run.sh mandel-oop` → bsnes-jg PASS (`0x204F` @ WRAM `corpus_result` offset)
3. `-verify-machineinstrs` clean under `+mos-a16`
4. Disasm: indirect jumps in `scene_emit` path only — zero in `mandel_cell` / `mandel_fill` loop
5. Size delta (`mandel-oop.map` vs `mandel-display.map`) recorded in `oop-in-c.md`
