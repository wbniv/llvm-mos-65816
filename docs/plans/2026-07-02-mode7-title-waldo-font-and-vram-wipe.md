# Plan: Mode-7 title (hilbert) — Waldo font + fix the long-standing VRAM-leftover bands

**Status: DONE (2026-07-02).** `hilbert`'s Mode-7 zoom/spin title now renders in the 16×16 Waldo font
(commit `cc7b3cc`), and the long-standing "vertical portions seen through / others block" artifact is
fixed by wiping the Mode-7 VRAM at title teardown (commit `7487130`). Gate `0x5999` host == +mos-a16 on
MAME + bsnes-jg; steady demo shows zero per-column luma variance.

## Context

`snesgfx/m7title.h` is a *separate* title system from `title_layer.h` (BG2) — it's used by exactly one
demo, `hilbert`, for a Mode-7 zoom-in / shimmer / 360°-spin-out splash. It previously rendered the 8×8
`font8` as Mode-7 8bpp tiles. Two goals:

1. **Font:** bring it onto the same recovered Waldo font as the 90 BG2-title demos (see
   `2026-07-02-title-16x16-waldo-font.md` and `~/waldo/docs/investigations/2026-07-01-…`).
2. **Bug:** the user reports vertical bands / see-through that "has always been problematic" — a
   pre-existing Mode-7 clearing defect, made more visible by the font change.

## Design

### Font (16×16 Waldo on Mode 7)
Mode 7's char-data budget is **256 tiles** (8bpp, 64 B each) = `FONT16_N`(64) × 4 tiles **exactly**, so
all 64 Waldo glyphs upload as 256 Mode-7 tiles: glyph `g` → tiles `4g+0..3` (TL,TR,BL,BR). Each 8×8 tile
is written from `FONT16` (`word = face | shadow<<8`) as one byte per pixel: **face → palette index 1,
shadow → index 2, else 0**. Each character is placed as a **2×2 tile-cell** block across two tilemap
rows (top row TL,TR at `row`; bottom row BL,BR at `row+1`). Palette: 0 = black, 1 = white face
(shimmer drives CGRAM 1), 2 = dark shadow (`0x1084`). Zoom/shimmer/spin animation unchanged.

### The bands bug — root cause
Mode 7 **packs the tilemap and char data into the same words**: word `W` LOW byte = tilemap entry `W`,
HIGH byte = char-data byte `W`. The tilemap is 128×128 = 16384 words; the 256 tiles' char data is 256×64
= 16384 bytes = the HIGH plane of those same words. `m7splash` populated this region but **never wiped
it**. When the demo took over — `hilbert` calls `display_init()` which switches to **BGMODE_1**, a
*different* interpretation of the same VRAM — the leftover glyph pixels rendered as **vertical bands /
see-through** garbage. The old font8 path (128 char tiles) already had this; the font16 path (all 256
tiles populated with real glyph pixels) made it worse.

### Fix
Add `_m7t_wipe_vram()`: two DMAs zeroing the **LOW plane** ($2118) then the **HIGH plane** ($2119) over
`M7_TILEMAP_WORDS` (16384) words, called from `m7splash_end()` **under force-blank** at teardown. The
demo's `display_init()` then starts from clean VRAM. Cost: 2 DMAs (~32 KB) once per title, force-blank.

## Verification

1. `dev/run.sh hilbert` — gate unchanged (title is gate-neutral).

```
==> host oracle: Hilbert gate hash = 0x5999
SMOKE: PASS ... got=0x5999 (bsnes-jg)
    SHOT: PASS corpus=0x5999 (MAME)
RESULT: PASS — host == +mos-a16
```
**PASS.**

2. **No banding in the steady demo** — per-column luma standard deviation:

```
frame 220 colluma stddev=0     (perfectly uniform — no leftover bands)
frame 300 colluma stddev=18    (the curve being drawn; clean)
```
**PASS.**

3. **Title correctness verified in VRAM** (captures kept hitting force-blank frames during the long
   `hilbert_gate_crc` compute, so verified directly): tilemap row 13 col 3 = tile 160 = glyph 40 = `H`
   TL; that tile's char data is face=`1`/shadow=`2`/bg=`0`. Reconstructed render reads "SPACE-FILLING /
   HILBERT CURVE" in white with the SE shadow, centred (`docs/plans/screenshots/m7title-waldo-hilbert.png`).
**PASS.**

4. Pre/post-fix transition captures: frame 66 was green-band leftover before the wipe, clean black after.
**PASS.**

## Files

- edit: `examples/snes/snesgfx/m7title.h` (font16 upload + 2×2 tilemap placement + `_m7t_wipe_vram`)
- screenshot: `docs/plans/screenshots/m7title-waldo-hilbert.png`
- ROM: `build/hilbert.sfc` → site `public/play/roms/hilbert.sfc` (bulk loop:
  `docs/howto-bulk-rebuild-republish-web-roms.md`)
- commits: `cc7b3cc` (font), `7487130` (wipe fix)
