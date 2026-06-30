# Plan: SNES Title Screen Upgrade — 16×16 font across all 35 demos

**Date:** 2026-06-30
**Refs:** investigation `docs/investigations/snes-title-screens.md`,
          implementation plan `docs/plans/2026-06-30-title-screen-16px-font.md`

## Motivation

The `TitleLayer` introduced in June 2026 used an 8×8 font — correct behaviour, but the text
occupies only ~11% of screen height vs the 24–40 px logos seen in reference SNES titles. A
nine-game reference survey (DKC, Super Metroid, F-Zero, Zelda, Mega Man X, etc.) identified
font scale as the highest-impact improvement.

## What shipped

### 1. `title_layer.h` — dual-mode font (`7f80226`, `feat(snesgfx)`)

Added `title_begin16()` alongside the existing `title_begin()`. A `uint8_t font16` field in
`TitleLayer` selects the mode at load time; `_title_reserve()` and `_title_emit()` branch on it.

**8×8 mode** (existing, `title_begin`):
- 64 glyphs × 1 tile × 16 words = 1024 words at `TITLE_CHR_WORD`
- HDMA channel 3 on `BG2HOFS` for sub-tile pixel centring of odd-length strings
- Max 32 chars/line

**16×16 mode** (new, `title_begin16`):
- Each 8×8 glyph pixel-doubled into 4 tiles (TL/TR/BL/BR = tiles `4g+0..4g+3`)
- Horizontal: each bit → 2 adjacent bits. Vertical: each row emitted twice.
- 64 glyphs × 4 tiles × 16 words = 4096 words at `TITLE_CHR_WORD` (0x1000–0x1FFF)
- No HDMA needed — centering is exact at the 16 px boundary for all string lengths
- Max 16 chars/line

**`splash16()`** — added to `title_layer.h` as a drop-in for `splash_show()`:
```c
static inline void splash16(const char *l0, const char *l1, uint16_t frames) {
    Display _d; display_init(&_d);
    static TitleLayer _t;
    title_begin16(&_d, &_t, l0, l1);
    title_end(&_d, &_t, frames);
    REG_INIDISP = 0x80;   // re-enter force-blank for Mode 7 / VRAM setup
}
```

### 2. Hilbert switched (`d56fd23`)

First demo on 16×16: `"HILBERT CURVE"` / `"SPACE-FILLING"` (both 13 chars). Confirmed live
on [biohack.net/snes/hilbert/](https://biohack.net/snes/hilbert/) before bulk rollout.

### 3. All 26 `title_begin` demos switched (`91b68fc`)

Bulk `sed` across 26 .c files:
```
title_begin(& → title_begin16(&
```
All 26 demos fit ≤16 chars on both lines. Two strings pre-abbreviated to fit:
- `rdiff.c`: `"REACTION DIFFUSION"` (18) → `"REACT DIFFUSION"` (15)
- `1d-ca.c`: `"CELLULAR AUTOMATA"` (17) → `"CELL AUTOMATA"` (13)

Gates spot-checked: fn-plot `0x2EBE`, doom-fire `0x3C59`, spirograph `0x32D4` — all PASS.

### 4. All 6 `splash_show` demos switched (`fbaf268`, via concurrent Opus 4.8 worker)

```c
#include "snesgfx/splash.h"  →  #include "snesgfx/title_layer.h"
splash_show(l0, l1, n)       →  splash16(l0, l1, n)
```

Two overlong subtitles abbreviated:
- `buddha.c`: `"ESCAPE-ORBIT DENSITY"` (20) → `"ORBIT DENSITY"` (13)
- `blossom.c`: `"HOPALONG ATTRACTOR"` (18) → `"HOPALONG ATTR"` (13)

Gates verified: julia `0x3490`, avalanche `0x27EA`, mandel-float `0x4169`,
mandel-display `0x204F`, blossom `0x7F9A`, buddha `0x7C31` — all PASS.

## VRAM layout after change

```
0x0000  demo BG1/BG3 char data
0x1000  TitleLayer BG2 char data
          8×8 mode:   1024 words (0x1000–0x13FF) — not used by any demo now
          16×16 mode: 4096 words (0x1000–0x1FFF)
0x2000  free
0x5000  TitleLayer BG2 tilemap (1024 words, unchanged)
```

## Demos affected (35 total)

| Demo | Title | Subtitle | Mode |
|---|---|---|---|
| hilbert | HILBERT CURVE | SPACE-FILLING | 16×16 |
| fn-plot | FN-PLOT | RECURSIVE PARSER | 16×16 |
| doom-fire | DOOM FIRE | HEAT FIELD | 16×16 |
| spirograph | SPIROGRAPH | HYPOTROCHOID | 16×16 |
| 1d-ca | CELL AUTOMATA | RULE 90 / 110 | 16×16 |
| rdiff | REACT DIFFUSION | GRAY-SCOTT | 16×16 |
| boids | BOIDS | STRUCT-BY-VALUE | 16×16 |
| burning-ship | BURNING SHIP | FRACTAL | 16×16 |
| cardioid | CARDIOID | TIMES TABLE | 16×16 |
| double-pendulum | DOUBLE PENDULUM | CHAOS | 16×16 |
| epicycles | FOURIER | EPICYCLES | 16×16 |
| fft | FFT SPECTRUM | RADIX-2 DIT | 16×16 |
| harmonograph | HARMONOGRAPH | LISSAJOUS | 16×16 |
| invaders | SPACE INVADERS | SPRITES + OAM | 16×16 |
| life | CONWAY LIFE | GLIDER GUN | 16×16 |
| lsystem | L-SYSTEM | PLANT | 16×16 |
| maze | MAZE | GENERATE + SOLVE | 16×16 |
| n-body | N-BODY ORBITS | GRAVITY | 16×16 |
| newton | NEWTON FRACTAL | COMPLEX DIVISION | 16×16 |
| raycaster | RAYCASTER | MAZE | 16×16 |
| sort-race | SORTING RACE | QUICK HEAP MERGE | 16×16 |
| spigot | PI SPIGOT | MONTE CARLO | 16×16 |
| tea | TEA CIPHER | (varies) | 16×16 |
| truchet | TRUCHET | BITFIELDS | 16×16 |
| turtle-vm | BYTECODE VM | TURTLE | 16×16 |
| vaprintf | (varies) | LISSAJOUS | 16×16 |
| wireframe | 3D WIREFRAME | SPINNING SOLID | 16×16 |
| julia | JULIA SET | Z^2 + C | 16×16 (splash16) |
| avalanche | 64-BIT | AVALANCHE | 16×16 (splash16) |
| mandel-float | SOFT-FLOAT | MANDELBROT | 16×16 (splash16) |
| mandel-display | MANDELBROT | ESCAPE TIME | 16×16 (splash16) |
| blossom | BLOSSOM | HOPALONG ATTR | 16×16 (splash16) |
| buddha | BUDDHABROT | ORBIT DENSITY | 16×16 (splash16) |

## Verification

| Step | Status |
|---|---|
| title_begin16 gate-neutral (fn-plot 0x2EBE) | ✅ PASS |
| 16×16 pixel measurement (FN-PLOT: x=72–184 ≈ 7×16px) | ✅ PASS |
| hilbert gate (0x5999) after title_begin16 | ✅ PASS |
| doom-fire gate (0x3C59) after bulk switch | ✅ PASS |
| spirograph gate (0x32D4) after bulk switch | ✅ PASS |
| julia gate (0x3490) after splash16 | ✅ PASS |
| avalanche gate (0x27EA) after splash16 | ✅ PASS |
| mandel-float gate (0x4169) after splash16 | ✅ PASS |
| mandel-display gate (0x204F) after splash16 | ✅ PASS |
| blossom gate (0x7F9A) after splash16 | ✅ PASS |
| buddha gate (0x7C31) after splash16 | ✅ PASS |
| Live visual on biohack.net/snes/hilbert/ | ✅ PASS (2×2 pixel blocks visible) |
| Publish all 35 ROMs to biohack.net | ⬜ pending |
