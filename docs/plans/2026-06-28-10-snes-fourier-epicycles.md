# #10 — SNES Fourier Epicycles: sum of rotating vectors traces a shape

**Status:** BUILT + VERIFIED + **PUBLISHED** — live at [biohack.net/snes/epicycles/](https://biohack.net/snes/epicycles/)
(biohack.net v1.0.113), 2026-06-28. bsnes-jg + host + `-verify` clean (default/+mos-a16/+mos-xy16). Demo
**#10** of the **compiler stress-test demo battery**. Only the MAME leg remains pending (SPC700 IPL absent here).

## Context

A sum of rotating vectors (epicycles) traces a baked outline — the **many-multiply / sin-cos**
member of the battery. Distinct from Spirograph (#11, two epicycles, gear-ratio divide) and N-body
(#13, divide-bound): epicycles has **no 32-bit divide** — its hot loop is a sin/cos-LUT sweep with
**four 16×16→32 multiplies per harmonic** (the complex multiply `re·cos − im·sin` / `re·sin + im·cos`)
plus 32-bit accumulation across all harmonics, per traced point. That is `__mulsi3`-dense and a
different codegen profile from every other demo.

Shared portable logic: [`examples/65816/epicycles.h`](../../examples/65816/epicycles.h) +
[`epicycles_tables.h`](../../examples/65816/epicycles_tables.h) (baked DFT coefficients of a
5-pointed-star outline, from `tools/gen-epicycles-tables.py`).

## Algorithm

```
P(t) = Σ_k c_k · exp(i·2π·f_k·t)              # EPI_NHARM rotating vectors (epicycles)
```
Per traced phase `step` (0..255), per harmonic k (uint8/16, no bare int):
```
idx = (uint8_t)(EPI_FREQ[k] * step)          # f_k·step mod 256 — LUT index (periodic ⇒ neg freq OK)
c   = EPI_COS(idx);  s = EPI_SIN(idx)         # Q8.8 sin/cos LUT (256 = 1.0)
rx += (int32_t)re * c - (int32_t)im * s       # __mulsi3 ×2  (Re of c_k·e^{iθ})
ry += (int32_t)re * s + (int32_t)im * c       # __mulsi3 ×2  (Im)
tip = (rx >> EPI_SHIFT, ry >> EPI_SHIFT)      # EPI_SHIFT = 8 (LUT) + 6 (coeff bits) = 14 → pixels
```
Coefficients are the DFT of a star perimeter, rotated ~23° off-vertical so **both** `re` and `im`
are non-zero (a vertically-symmetric star gives purely-imaginary `c_k`, folding the `re` multiplies
to ×0 — half the intended stress). Ordered by |c_k| (largest vector first) so a prefix is the best
low-order approximation. EPI_NHARM = 8 at the default radius.

**Gate CRC** (`epi_gate_crc`): fold `EPI_GATE_N=32` tip points at stride 8 (the full 256 period) →
**`EXPECT = 0x4F6C`**. No 32-bit divide; `__mulsi3` is the probe.

## Screen layout

```
row 1:   FOURIER EPICYCLES                          (BG3 text HUD, top bar)
rows 6..21, cols 8..23:  128x128 BitmapCanvas       (BG3 2bpp, centred)
           dim nested generating circles (scaffold) + the bright star outline drawing itself
row 25:  N=8  STAR  PT NNN                           (BG3 text HUD, bottom bar)
```

## Display architecture

- **`BitmapCanvas`** (128×128, BG3 2bpp) — reused verbatim from Spirograph: the outline blooms via
  `canvas_line` between consecutive tips; a one-time dim scaffold of the 8 generating circles
  (midpoint-circle) shows the "nested circles". **`TextLayer`** (2 HUD bars) + **`TitleLayer`** (BG2).
- Palette CGRAM[0..3]: black / dim (scaffold) / spare / bright cyan (outline).
- DMA: `canvas` capped at 64 tiles/frame; one CGRAM push. Well under 1.5 KB.
- RAM: canvas 4 KB + small state — fits the 7680 B low-WRAM budget with room.

## Files

| File | Purpose |
|---|---|
| `tools/gen-epicycles-tables.py` (new) | Bake DFT coefficients of a star → `epicycles_tables.h` |
| `examples/65816/epicycles_tables.h` (new, generated) | `EPI_FREQ/RE/IM`, `EPI_NHARM`, `EPI_SHIFT` |
| `examples/65816/epicycles.h` (new) | sin/cos LUT + `epi_point`/`epi_chain` + `epi_gate_crc` |
| `examples/snes/epicycles.c` (new) | ROM: canvas bloom of the outline + scaffold circles |
| `examples/snes/corpus/epicycles_sim.c` (new) | HAL-free corpus slice (5-way differential) |
| `tools/epicycles-sim.c` (new) | Host oracle (prints `0x4F6C`) |
| `dev/epicycles.sh`, `dev/epicycles.lua` (new) | Gate: host oracle + disasm probe + bsnes-jg + MAME |
| `Taskfile.yml`, `expected.tsv`, `TODO.md`, `plan-index.md`, `…demo-ideas.md`, `dev/run.sh` | wiring |

## Reused infrastructure

| Asset | From | Used for |
|---|---|---|
| `bitmap_canvas.h` (`canvas_plot`/`canvas_line`) | spirograph | outline bloom + scaffold circles |
| `text_layer.h` / `title_layer.h` / `font8.h` | snesgfx | HUD + title |
| Q8.8 sin/cos LUT + `*_fold` CRC idiom | spiro.h | trig + gate hash |
| `jgxcheck.cpp`, `snes-checksum.py` | dev harness | bsnes-jg assert, checksum |

## Differential gate

- `corpus_result = epi_gate_crc()` → **`0x4F6C`**. **5-way bar** (no far pointers, all bank-0 WRAM).
- Verified: host == default == +mos-a16 == +mos-xy16 on bsnes-jg; `-verify-machineinstrs` clean (3);
  UBSan clean. Disasm probe (a16 slice): `__mulsi3` = 4, `rep`/`sep` = 28, **zero 32-bit divides**.

## Publication

```
/snes-rom-page --rom build/epicycles.sfc --slug epicycles --site ~/SRC/biohack.net \
  --title "Fourier Epicycles" --preview build/epicycles-jg.png \
  --selfcheck "0x<VMA> 2 0x4F6C 500 epicycles"
```

## Verification steps

1. Host oracle compiles and prints a plausible CRC.  → `epicycles gate_crc = 0x4F6C`. PASS.
2. ROM builds clean; snes-checksum.py exits 0.  → built `build/epicycles.sfc`; checksum exit 0; `corpus_result @ WRAM 0x1366`. PASS.
3. Corpus slice host-compiles + UBSan clean; target `-verify` clean (default/a16/xy16).  → all exit 0; UBSan clean (`0x4F6C`). PASS.
4. `dev/run.sh epicycles` — host oracle + disasm gate + bsnes-jg PASS (MAME SKIP w/o IPL).
```
==> host oracle: Fourier-epicycles gate hash = 0x4F6C
==> built build/epicycles.sfc (+mos-a16); corpus_result @ WRAM 0x1366
==> disasm gate (complex-multiply + native-16, no divide)
    PASS  __mulsi3=4  rep/sep=28  divide=0  (complex multiply + native-16, divide-free)
==> bsnes-jg: render + framebuffer dump (build/epicycles-jg.png) + assert
SMOKE: PASS off=0x1366 len=2 got=0x4F6C (ran 500 frames, bsnes-jg)
    SKIP MAME snapshot (no xvfb-run or no SPC700 IPL — bsnes-jg + browser carry the bar)
RESULT: PASS — Fourier epicycles rendered on SNES; bsnes-jg + corpus hash 0x4F6C host == +mos-a16
```
PASS (MAME SKIP — SPC700 IPL not present here; non-blocking per the demos bar).
5. Corpus differential on bsnes-jg: default == +mos-a16 == +mos-xy16 == host == `0x4F6C`.
```
  default:   SMOKE: PASS off=0x200 len=2 got=0x4F6C
  +mos-a16:  SMOKE: PASS off=0x200 len=2 got=0x4F6C
  +mos-xy16: SMOKE: PASS off=0x200 len=2 got=0x4F6C
```
PASS (5-way bar minus the BIOS-gated MAME legs).
6. On-screen render shows the nested circles + the star outline drawing itself.  → `build/epicycles-jg.png` (frame 500): the complete 5-pointed star (PT 256) over its dim generating circle. PASS.
7. `/snes-rom-page` publishes; headless screenshot shows the ROM running.  PENDING (user-triggered).
8. `task md -- docs/plans/...` renders cleanly.  PENDING.
