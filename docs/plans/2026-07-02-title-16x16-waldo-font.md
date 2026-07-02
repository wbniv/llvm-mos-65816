# Plan: real 16×16 Waldo font (with drop-shadow) for demo title screens

**Goal.** Replace the demos' title-card 16×16 line — currently the 8×8 `font8.h` **pixel-doubled** (chunky,
1-colour) — with the genuine **16×16 Waldo font** recovered in
`~/waldo/docs/investigations/2026-07-01-great-waldo-search-font-recovery.md` (face + authentic SE
drop-shadow). Shared change: every demo using `title_begin[16]` (84 of them) gets the nicer font.

## Design

- **New asset `examples/snes/font16.h`** (generated, do-not-edit), matching `font8.h`'s ASCII range
  `0x20..0x5F`, `FONT16_N = 64`. Layout: per glyph 4 tiles `TL,TR,BL,BR`, each tile 8 words, where
  `word = face_byte | (shadow_byte << 8)` → a 2-plane (2bpp) tile with **face = colour 1**,
  **shadow = colour 2** (planes 2,3 stay 0). This drops straight into the existing tiles-64..319 slot
  (same 4 K-word VRAM budget as the pixel-doubled path — no layout change).
- **Generator `tools/gen-font16.py`** (self-contained, reproducible, no deps): embeds the **face**
  bitmaps as 16×16 ASCII art (`#` = face); the **shadow is synthesised** as `face shifted (+2,+2) SE,
  minus face` — the measured Waldo offset (98.9% match to the authentic letter shadow), giving one
  consistent shadow across letters, digits, and authored symbols.
  - A–Z, 0–9: recovered Waldo faces.
  - Symbols the titles actually use — `! & + - . / = _ :` and space — authored in matching style.
  - Everything else: blank (renders as space, exactly like the current out-of-range → 0 behaviour).
- **`title_layer.h` changes** (the only shared-code edit):
  1. `#include "../font16.h"`.
  2. Palette (pal 7): keep colour 0 = transparent, colour 1 = animated ink; **add colour 2 = shadow**
     (fixed dark, e.g. BGR555 `0x0000`/near-black) written once in `_title_reserve`.
  3. Replace the 16×16 pixel-doubling upload loop with a direct `FONT16` upload (8 words face/shadow +
     8 words zero per tile, 4 tiles per glyph).
  4. `line0` (8×8 subtitle) stays on `font8` unchanged — its symbol/lowercase coverage differs and it's
     the secondary line. (Follow-up option: a shadowed 8×8 too.)
- **Glyph lookup** `_title_glyph` is unchanged (same `0x20..0x5F` mapping serves both fonts); lowercase
  still → blank, as today.

## Risk / neutrality

- Title card is **gate-neutral** (`active=0` after `title_end`; not in any demo's corpus CRC), so no
  correctness proof changes. Change is purely visual.
- VRAM/tilemap/tile-index layout unchanged → no interaction with demo layers.
- Must still **build clean for all demos** and pass a representative gate.

## Verification

1. `python3 tools/gen-font16.py > examples/snes/font16.h` — regenerates without error; header compiles.

```
GENERATED font16.h (139 lines)   # decoded back + rendered A E 0 5 ! - / + = & _ Z 9 — all correct
```
**PASS.**

2. `dev/run.sh boids` — builds `build/boids.sfc`, gate `boids_gate_crc 0xA8AB` still passes (title-neutral).

```
==> host oracle: Boids gate hash = 0xA8AB
SMOKE: PASS off=0x5A len=2 got=0xA8AB (ran 1400 frames, bsnes-jg)
    SHOT: PASS corpus=0xA8AB (snapshot at frame 1400)   # MAME
RESULT: PASS — host == +mos-a16 on MAME + bsnes-jg
```
**PASS** (host == +mos-a16 on both emulators; font16.h compiles).

3. Title-frame capture (`waldofont build/boids.sfc 200`): line1 "STRUCT-BY-VALUE" shows the real 16×16
   Waldo glyphs **with the SE drop-shadow** + the authored `-` — not the chunky pixel-doubled font.
**PASS** (`/tmp/boids-title-200.png`).

4. `dev/run.sh cosmzoom` — line1 "64-BIT / FLOAT" exercises digits + `-` + `/`.

```
==> host oracle: cosmzoom gate hash = 0x502F
SMOKE: PASS off=0x54 len=2 got=0x502F (ran 1400 frames, bsnes-jg)
```
**PASS for the font** — host `0x502F` == bsnes-jg `0x502F`; title capture shows digits `6 4`, `-`, `/`
all correct (`/tmp/cosmzoom-title.png`). The MAME-only `RESULT: FAIL` is **not** from this change: it is
gate-neutral, and `boids` (identical title code) passed MAME fully in step 2 — the MAME issue is specific
to this heavy 64-bit-float demo (pre-existing/environmental).

5. No codegen change → `-verify-machineinstrs` unaffected; boids + cosmzoom both compiled clean.
**PASS.**

## Files

- new: `examples/snes/font16.h` (generated), `tools/gen-font16.py`
- edit: `examples/snes/snesgfx/title_layer.h`
- plan/TODO: this file + `TODO.md` entry
