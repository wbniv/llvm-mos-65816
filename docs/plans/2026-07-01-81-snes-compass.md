# #81 — SNES Copysign Compass: Sign-Bit Flow

<p align="center"><img src="screenshots/compass.png" width="512" alt="Copysign Compass running on SNES (bsnes-jg render)"></p>

**Status:** DONE. Demo **#81** of the **compiler stress-test demo battery** (Round 5).

## Context

`G_FCOPYSIGN` routes to `LegalizerHelper::lowerFCopySign` (LegalizerHelper.cpp:8899-8960): it expands
inline as AND/OR of sign bits — no libcall, no round-trip through memory. Similarly `G_IS_FPCLASS`
(the `signbitf` path) becomes an inline sign-bit integer test. Both are single-bit operations that are
genuinely fast on the 65816.

Distinct from:
- **#45 metaball** — uses a `union float/uint32` type-pun to read sign bits through the integer ALU;
  `G_FCOPYSIGN` is never formed.
- **#57 medfilt** — uses integer `G_ABS`/`G_SMIN` (no float sign ops at all).

The vector-field algorithm: each cell `(tx, ty)` in a 16×16 grid computes sign sources as integer sums
cast to float, then `copysignf(1.0f, float_src)` to get ±1.0 (sign transplant), then `signbitf` to
reduce the sign back to 0/1 and pack two bits into a colour index. The output is a rotating quadrant
map — as phase sweeps, the sign-zero crossing sweeps across the field and the quadrant boundaries
swirl visibly.

## Algorithm

```
for each tile (tx, ty) in [0..15]×[0..15], for each phase in 0,3,6,...,(GATE_N-1)*3:
    dx = tx - 8;  dy = ty - 8             // center-relative
    src_x = (int16_t)(dx + phase)         // G_SITOFP sign source
    src_y = (int16_t)(dy - phase)
    fsrc_x = (float)src_x                 // __floatsisf × 2
    fsrc_y = (float)src_y
    vx = copysignf(1.0f, fsrc_x)          // G_FCOPYSIGN → inline AND/OR
    vy = copysignf(1.0f, fsrc_y)
    sx = signbitf(vx) ? 1 : 0             // G_IS_FPCLASS → inline sign test
    sy = signbitf(vy) ? 1 : 0
    colour = sx | (sy << 1)               // 0=NE, 1=NW, 2=SE, 3=SW
    h = fold(h, colour, pos++)
GATE_N = 16, phase_step = 3 (coprime with 16 to avoid period reset)
```

## Files

| File | Purpose |
|------|---------|
| `examples/65816/compass.h` | Algorithm + gate CRC |
| `examples/snes/compass.c` | SNES ROM (16×16 animated quadrant map) |
| `examples/snes/corpus/compass_sim.c` | Corpus slice |
| `tools/compass-sim.c` | Host oracle |
| `dev/compass.sh` | Gate script |
| `dev/compass.lua` | MAME Lua assert |

## Differential gate

- `corpus_result = compass_gate_crc()` — folds 16×16 cell colours across GATE_N=16 phases.
- **EXPECT `0xB9CB`** — `host == default == +mos-a16 == +mos-xy16` on bsnes-jg and MAME.
- **5-way bar** — no far pointers.
- **Disasm probes:** `__floatsisf ≥ 2`, `rep/sep ≥ 1`.

## Verification steps

### Step 1 — Gate (`dev/run.sh compass`)

```
==> host oracle: compass gate hash = 0xB9CB
==> built build/compass.sfc (+mos-a16); corpus_result @ WRAM 0x64
==> disasm gate (G_FCOPYSIGN inline AND/OR + G_IS_FPCLASS + rep/sep)
    __floatsisf=2  rep/sep=38
    PASS  copysign path confirmed (__floatsisf=2 >= 2, rep/sep=38 >= 1)
==> bsnes-jg: render + assert (build/compass-jg.png)
SMOKE: PASS off=0x64 len=2 got=0xB9CB (ran 500 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/compass-mame.png)
    SHOT: PASS corpus=0xB9CB (snapshot at frame 500)

RESULT: PASS — Copysign Compass on SNES; MAME + bsnes-jg + corpus hash 0xB9CB host == +mos-a16
```
PASS. `G_FCOPYSIGN` inline AND/OR + `G_IS_FPCLASS` both produce bit-exact results across all modes.
First demo to fire `lowerFCopySign`.

### Step 2 — 5-way differential (`dev/run.sh _demo5 compass`)

```
host oracle = 0xB9CB
== -verify-machineinstrs ==
  +mos-a16: verify OK
  +mos-xy16: verify OK
== build + bsnes-jg each variant ==
  vmas: default=0x64 a16=0x64 xy16=0x64
SMOKE: PASS off=0x64 len=2 got=0xB9CB (ran 500 frames, bsnes-jg)
SMOKE: PASS off=0x64 len=2 got=0xB9CB (ran 500 frames, bsnes-jg)
SMOKE: PASS off=0x64 len=2 got=0xB9CB (ran 500 frames, bsnes-jg)

RESULT: PASS — host==default==a16==xy16==0xB9CB on bsnes-jg
```
PASS. 5-way green, `-verify-machineinstrs` clean.
