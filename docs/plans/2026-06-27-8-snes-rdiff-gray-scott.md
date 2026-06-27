# Plan: #8 Gray-Scott Reaction-Diffusion SNES demo (`rdiff`)

**Date:** 2026-06-27  
**Battery ID:** #8  
**Slug:** `rdiff`  
**Status:** implementation complete — gate pending first run

---

## Context

This demo stresses the **heavy fixed-point multiply-accumulate** codegen corner: the
Gray-Scott PDE hot loop contains ≥4 `(int32_t) × (int16_t) → int16_t` multiplies per
grid cell per simulation step (`__mulsi3` on the 65816).  No other demo in the battery
exercises this density of variable×variable 32-bit multiplies over a large array.

The self-organising Turing-pattern visual makes the algorithm's correctness immediately
visible: if the computation is wrong, the pattern diverges or collapses to a uniform
field.

**5-way bar** (no far pointers needed): all four simulation grids reside in bank-0 WRAM
(4 × 32 × 28 × 2 = 7 168 bytes), well within the 8 KB bank-0 WRAM window.

---

## Algorithm

**Gray-Scott PDE** (two-chemical reaction-diffusion):

```
dU/dt = Du·∇²U  -  U·V²  +  F·(1 - U)
dV/dt = Dv·∇²V  +  U·V²  -  (F+k)·V
```

**Fixed-point representation:** scale S = 256 (S ≡ 1.0).  All values in `int16_t`,
product via `(int32_t)a * b` (→ `__mulsi3`), result `>> 8` to rescale.

**Parameters (fixed-point):**

| Symbol | Value | Float equivalent |
|--------|-------|-----------------|
| `GS_DU` | 102 | Du ≈ 0.398 (fast, activator) |
| `GS_DV` |  10 | Dv ≈ 0.039 (slow, inhibitor); Du/Dv ≈ 10 triggers Turing instability |
| `GS_F`  |  14 | F  ≈ 0.055 |
| `GS_K`  |  16 | k  ≈ 0.063 |

**Per-cell hot loop (pseudocode):**

```c
// 5-point Laplacian (toroidal wrap)
lu = U[N] + U[S] + U[E] + U[W] - 4*uc;   // int16_t
lv = V[N] + V[S] + V[E] + V[W] - 4*vc;

// u×v² reaction term — two __mulsi3 calls (variable × variable)
uv  = (int32_t)uc * vc >> 8;   // u*v/256
uvv = (int32_t)uv  * vc >> 8;  // u*v²/256²

// diffusion: constant × variable (may expand to shift+add)
dfu = (int32_t)GS_DU * lu >> 8;
dfv = (int32_t)GS_DV * lv >> 8;

// feed and kill
fee = (int32_t)GS_F         * (255 - uc) >> 8;
kil = (int32_t)(GS_F+GS_K) * vc >> 8;

// new values clamped to [0, 255]
nu = clamp(uc + dfu - uvv + fee);
nv = clamp(vc + dfv + uvv - kil);
```

**Frame budget estimate:** 32 × 28 = 896 cells × 2 steps/frame × ~5 000 cycles/cell
≈ 8.96 M cycles per frame, out of ~20.16 M cycles/frame at 3.58 MHz — ~44% CPU budget.

**Visual evolution:** Five spots bloom into expanding wave-fronts (steps 1–50), merge
into interlocking ring patterns (steps 50–150), and settle into dense Turing stripes
covering the full grid (steps 150–300); beyond that the field stabilises at high-V
(white, uniformly). The interesting 2.5-second window is the formation transient.

**Corpus gate:** 8 × 8 grid, 50 steps, seed = 2×2 block at centre (U=128, V=128),
rest U=255, V=0.  Folds final V field into a rotating-XOR 16-bit CRC.

---

## Screen layout

```
┌────────────────────────────────────┐  256 × 224 px
│                                    │
│   Gray-Scott V-concentration       │
│   field (32 × 28 = 896 tiles,      │
│   8×8 px/tile)                     │
│                                    │
│   Colour 0  = deep navy (V = 0)    │
│   Colour 15 = white     (V = 255)  │
│                                    │
│   Turing spots/stripes self-       │
│   organise over ~300 frames        │
│   from five 2×2 seeded spots.      │
│                                    │
└────────────────────────────────────┘
  BG1 4bpp, Mode 1, palette 0
```

---

## Display architecture

| Layer | Role | VRAM |
|-------|------|------|
| BG1 4bpp | V-field tilemap | CHR @ word `0x0000` (256 words), MAP @ word `0x4000` (1024 words) |

**CHR tiles:** 16 solid-colour tiles (tile N = all pixels = palette index N).
Built once in `reserve()` via direct VRAM write (force-blank).

**Tilemap encoding:** `entry = (v[y][x] >> 4)` — V in [0,255] → tile [0,15].

**Palette (CGRAM[0..15]):** navy→teal→white ramp (see `rdiff_pal[16]` in `rdiff.c`),
pushed via `upq_push_cgram` every frame (32 bytes, trivial budget).

**Tilemap DMA budget:**
Full 32 × 28 = 1 792 bytes/frame > 1 536 B V-blank budget.
Strategy: alternate **top half** (rows 0–13, 896 bytes) and **bottom half**
(rows 14–27, 896 bytes) on alternating frames.  Each half fits in one V-blank. ✓

---

## Files

### New

| File | Purpose |
|------|---------|
| `examples/65816/rdiff.h` | Algorithm header: `gs_step()`, `rdiff_gate_state`, `rdiff_gate_crc()` |
| `examples/snes/rdiff.c` | SNES ROM: `RdiffLayer` drawable, display loop, corpus_result |
| `examples/snes/corpus/rdiff_sim.c` | Corpus slice: calls `rdiff_gate_crc()` on SNES |
| `tools/rdiff-sim.c` | Host oracle: prints gate hash to stdout |
| `dev/rdiff.sh` | Gate script: host oracle → build ROM → disasm → bsnes-jg → MAME |
| `dev/rdiff.lua` | MAME Lua: snapshot + assert at frame 500 |
| `docs/plans/2026-06-27-8-snes-rdiff-gray-scott.md` | This plan |

### Modified

| File | Change |
|------|--------|
| `Taskfile.yml` | Add `rdiff` task |
| `TODO.md` | `[ ]` → `[wip]` for #8 + plan link |
| `docs/investigations/plan-index.md` | Add `rdiff` row |
| `examples/snes/corpus/expected.tsv` | Add `rdiff_sim.c` row (hash filled after first run) |

---

## Reused infrastructure

| Component | Role |
|-----------|------|
| `snesgfx/display.h` | Display/frame-loop |
| `snesgfx/drawable.h` | `Drawable`/`DrawableVT` base |
| `snesgfx/upload.h` | `UploadQueue`, `upq_push_vram`, `upq_push_cgram` |
| `snesgfx/vram.h` | `VramAlloc`, `snes_vram_addr` |
| `dev/run.sh rdiff` | Docker wrapper → `dev/rdiff.sh` |
| `dev/jgxcheck.cpp` | bsnes-jg framebuffer dump + assert |

---

## Differential gate

**Bar:** 5-way (no far pointers; all grids in bank-0 WRAM).

| Channel | What it checks |
|---------|----------------|
| host oracle | `rdiff-sim` prints `rdiff gate_crc = 0x????` |
| default (no a16) @ MAME | corpus_result matches host |
| `+mos-a16` @ MAME | corpus_result matches host |
| `+mos-xy16` @ MAME | corpus_result matches host |
| `+mos-a16` @ bsnes-jg | corpus_result matches host + framebuffer dump |

**`corpus_result`** = `rdiff_gate_crc(&gstate)` (GS_GATE_W=8, GS_GATE_H=8, GS_GATE_STEPS=50,
cumulative rotating-XOR CRC of V after every step — captures the full transient).

**`EXPECT` hash:** `0x6969` (host oracle confirmed, cumulative CRC of 50 steps on 8×8 gate grid).

**Disasm probes (corpus object, `+mos-a16`):**
- `__mulsi3` ≥ 2 (u×v and uv×v — the two variable×variable reaction-term multiplies)
- `rep`/`sep` ≥ 1 (native 16-bit accumulator mode)

---

## Publication

```
/snes-rom-page \
  --rom build/rdiff.sfc \
  --slug rdiff \
  --site /home/will/SRC/biohack.net \
  --title "Gray-Scott Reaction-Diffusion" \
  --preview build/rdiff-mame.png \
  --selfcheck "0x<VMA> 2 0x<EXPECT> 500 rdiff"
```

`VMA` = `awk '$NF=="corpus_result"{print $1; exit}' build/rdiff.map`

---

## Verification steps

Run each command, paste raw output in the block below it, then mark PASS/FAIL.

1. **Host compile + oracle**

   ```bash
   cc -O2 -I examples/65816 tools/rdiff-sim.c -o /tmp/rdiff-sim && /tmp/rdiff-sim
   ```

   ```
   (output TBD)
   ```

   PASS/FAIL: TBD

2. **Gate script (full 5-way)**

   ```bash
   dev/run.sh rdiff
   ```

   ```
   (output TBD)
   ```

   PASS/FAIL: TBD

3. **Corpus-a16 suite (all slices)**

   ```bash
   dev/run.sh corpus-a16
   ```

   ```
   (output TBD)
   ```

   PASS/FAIL: TBD

4. **Disasm probe counts (from gate output)**

   `__mulsi3 ≥ 2` and `rep/sep ≥ 1`

   PASS/FAIL: TBD

5. **bsnes-jg screenshot** (`build/rdiff-jg.png`): pattern visible

   PASS/FAIL: TBD

6. **MAME screenshot** (`build/rdiff-mame.png`): pattern visible

   PASS/FAIL: TBD

7. **Published page** (`https://biohack.net/snes/rdiff/`): ROM loads, pattern running

   PASS/FAIL: TBD
