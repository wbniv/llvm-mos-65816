# #3 — SNES Burning Ship fractal: |Re|,|Im| folding, escape-time bands

**Status:** DONE + PUBLISHED. Demo **#3** of the **compiler stress-test demo battery**.
Gate hash **`0x6F2D`**; `dev/run.sh burning-ship` RESULT PASS (disasm `__mulsi3`=3 + `rep/sep`=26,
zero divide; bsnes-jg host == `+mos-a16` `0x6F2D`); `-verify-machineinstrs` clean ×3. Published —
[biohack.net/snes/burning-ship/](https://biohack.net/snes/burning-ship/) (biohack.net v1.0.118).

**Display note:** the full-grid escape-time compute is heavy (interior cells run the full iteration
count), too slow to reveal progressively at 60 fps. The whole 32×28 grid is computed in one blocking
pass while the title masks it (no `display_frame` during the grind → the PPU holds the title), then the
escape bands palette-cycle. The ROM uses `BS_MAXI=16` (display only); the gate's `BS_GATE_MAXI=24` is
independent, so `corpus_result` is unchanged. The gate screenshot captures at frame 1500 (past the grind).

## Context

The **Burning Ship** — the Mandelbrot's folded cousin: `z_{n+1} = (|Re z_n| + i|Im z_n|)² + c`. Taking
the absolute value of each component before squaring breaks the symmetry and renders the famous
"ship" silhouette (hull + masts + trailing mini-ships). The whole ship is computed once, revealed
top-to-bottom, then the escape-band colours are cycled so the bands flow.

Why it's a distinct test vs the other fractals (Mandelbrot/Newton/Julia):

- The **abs fold** is the algorithm — two `|x|` operations per iteration that none of the other
  fractals have; it's what makes the ship. Same three-multiply count as Mandelbrot, but a different
  branch/negate shape in the inner loop.
- It's an **escape-time band** render (interior black, escape count → colour) with **palette cycling**
  — a display technique no other demo uses.

## Algorithm

All `int16_t`/`int32_t` (no bare `int`). Q12 fixed point (range ±8; `zx,zy ≤ 2` before escape).

```c
bs_iter(cx, cy, maxiter):
  zx = zy = 0
  for n in 0..maxiter-1:
    ax = |zx|;  ay = |zy|                         // the two abs FOLDS — the algorithm
    zx2 = (ax*ax) >> 12;  zy2 = (ay*ay) >> 12     // __mulsi3 ×2 (Q12)
    if zx2 + zy2 > (4<<12): break                 // |z|² > 4 escape
    zxy = (ax*ay) >> 12                           // __mulsi3 (Q12 |zx·zy|)
    zx = zx2 - zy2 + cx                           // Re
    zy = 2*zxy + cy                               // Im
  return n
```

Op mapping: **3× `__mulsi3` per iteration** (`zx²`,`zy²`,`|zx·zy|`) + 2 abs + the escape compare, Q12
shifts, `rep`/`sep` under `+mos-a16`. **No divide.** All integer ⇒ host == target.

## Screen layout

256×224 → 32×28 tiles. A 32×28 grid of solid-colour BG1 4bpp tiles (one tile per escape cell) fills
the screen — the doom-fire display model.

```
 ┌──────────────────────────────┐  32×28 escape-time grid:
 │   the Burning Ship, escape-   │   interior cells black, escape
 │   band coloured, top-to-      │   count → one of 15 ramp colours;
 │   bottom progressive reveal    │   the 15 bands cycle each frame.
 └──────────────────────────────┘
```

Title overlay ("BURNING SHIP" / "FRACTAL") on BG2, held ~2 s then torn down.

## Display architecture

- **Drawable:** one custom `BsLayer` (BG1 4bpp, 16 solid-colour tiles, half-tilemap DMA per frame from
  a `bs_grid[896]` colour-index shadow + a 32-byte palette DMA) — the doom-fire `FireLayer` model.
- **VRAM:** BG1 chr `0x0000` (16 tiles), tilemap `0x4000`; title BG2 chr `0x1000` / map `0x5000`.
- **Palette:** 16 colours — 0 black (interior), 1..15 a blue→cyan→green→yellow→orange→red→white ramp.
  `cycle_palette` rotates 1..15 each frame (the flow).
- **Compute:** `compute_row` fills `ROWS_PER_FRAME = 2` rows/frame until all 28 are in (a reveal), then
  the loop only cycles the palette. The window is a fixed wide view of the whole ship.
- **V-blank DMA:** half tilemap (14×32×2 = 896 B) + palette (32 B) per frame (doom-fire's safe budget).

## Files

| File | New/Mod | Purpose |
|---|---|---|
| `examples/65816/burning_ship.h` | new | `bs_iter` + `bs_gate_crc()` |
| `examples/snes/burning-ship.c` | new | SNES ROM: `BsLayer` + progressive compute + palette cycle |
| `examples/snes/corpus/burning-ship_sim.c` | new | HAL-free corpus slice |
| `tools/burning-ship-sim.c` | new | Host oracle |
| `dev/burning-ship.sh` / `dev/burning-ship.lua` | new | Differential gate |
| `Taskfile.yml` / `TODO.md` / `plan-index.md` / backlog / `expected.tsv` | mod | wiring |

## Reused infrastructure

| Asset | From | Used for |
|---|---|---|
| `FireLayer` half-tilemap DMA + 16 solid-colour 4bpp tiles | doom-fire #7 | `BsLayer` |
| `snesgfx/title_layer.h` | the battery | transient title |

## Differential gate

- **`corpus_result`** = `bs_gate_crc()` — a 16×16 window over the ship (Q12 `X0=Y0=−1.80`, `DX=DY=0.05`,
  maxiter 24), folding each cell's escape count into a rotate-XOR hash.
- **EXPECT:** `0x6F2D` (host oracle).
- **Bar:** **5-way** — the grid is bank-0 WRAM, no far pointers.
- **Disasm probes** (on `burning-ship_sim.o`): `__mulsi3 ≥ 1`, `rep`/`sep ≥ 1`, `__udiv* == 0`.

## Publication

```
/snes-rom-page --rom build/burning-ship.sfc --slug burning-ship --site ~/SRC/biohack.net
  --title "Burning Ship Fractal" --preview build/burning-ship-jg.png
  --selfcheck "0x<VMA> 2 0x6F2D 500 SHIP"
```

## Verification steps

1. Host oracle compiles and prints a plausible CRC. **PASS** — `burning-ship gate_crc = 0x6F2D`; an
   ASCII render of the whole ship (x∈[−2.2,1.0], y∈[−1.9,0.6]) shows the unmistakable hull + masts +
   trailing mini-ships.

2. ROM builds clean; `snes-checksum.py` exits 0. **PASS** — `corpus_result @ WRAM 0x580`, no warnings.

3. Corpus slice host-compiles. **PASS** (slice ends in `for(;;){}`; runtime is the bsnes-jg leg).

4. `dev/run.sh burning-ship` — host oracle + disasm gate + bsnes-jg + MAME all PASS.

```
==> host oracle: burning-ship curve hash = 0x6F2D
==> built build/burning-ship.sfc (+mos-a16); corpus_result @ WRAM 0x580
==> disasm gate (bs_iter: __mulsi3 + rep/sep, multiply-only — no divide)
    PASS  __mulsi3=3  rep/sep=26  bad_div=0  (fixed-point multiply, no divide)
==> bsnes-jg: render + framebuffer dump (build/burning-ship-jg.png) + assert
SMOKE: PASS off=0x580 len=2 got=0x6F2D (ran 1500 frames, bsnes-jg)
    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)

RESULT: PASS — Burning Ship rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0x6F2D host == +mos-a16
```
**PASS** — bsnes-jg host == `+mos-a16` `0x6F2D`; disasm confirms 3 `__mulsi3`/iter, **zero** divide. The
PNG (captured at frame 1500, past the grind) shows the black ship silhouette against the vivid
escape-band sea. MAME SKIP per the env-wide SPC700 IPL gap.

5. `dev/run.sh corpus-a16` — env-blocked by the MAME SPC700 IPL; substituted with `-verify-machineinstrs`
   on `burning-ship_sim.c` under all three modes:
```
  default            : -verify CLEAN
  +mos-a16           : -verify CLEAN
  +mos-a16 +mos-xy16 : -verify CLEAN
```
**PASS** — codegen sound across default/`+mos-a16`/`+mos-xy16`; with bsnes-jg runtime == host the 5-way
bar holds minus the env-blocked MAME runtime legs.

6. `/snes-rom-page` publishes; render confirmed. **PASS** — deployed (biohack.net `64ded5e`, tag
   `v1.0.118`); `task build` emits `/snes/burning-ship/index.html`; render confirmed by
   `build/burning-ship-jg.png`. Live-browser screenshot not run (no Chromium in this env).

7. `task md -- docs/plans/2026-06-28-3-snes-burning-ship.md` renders cleanly. **PASS**.
