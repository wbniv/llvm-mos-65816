# #84 — SNES Montgomery Orbit: Modmul Without Division

<p align="center"><img src="screenshots/montorbit.png" width="512" alt="Montgomery Orbit running on SNES (bsnes-jg render)"></p>

**Status:** DONE. Demo **#84** of the **compiler stress-test demo battery** (Round 5).

## Context

Montgomery modular multiplication (REDC) computes `a*b mod N` using only **multiply, shift, mask,
and a conditional subtract** — **no division/modulo libcall** (`__udivsi3`/`__umodsi3`). This is the
codegen corner: a hot loop that forms 32-bit products (`__mulsi3`), extracts the high word via a
16-bit logical shift-right / masks the low word (`G_LSHR`/`G_AND`), and branches on a compare — the
exact instruction mix real crypto code uses to avoid the 65816's expensive software divide.

Distinct from:
- **#61 dhmix** — 64-bit modular exponentiation using full-width `__udivdi3`/`__umoddi3` (division-based).
- **#20 factorial / #19 pi** — base-10000 bignum with `__udivmodsi4` (division-based).

Montgomery is the *division-free* member: it never emits `__udivsi3`/`__umodsi3`.

## Algorithm

```
Modulus N (16-bit odd), R = 2^16, N' = -N^{-1} mod 2^16 (precomputed constant).
REDC(T) with T a 32-bit product:                       // T = a*b, both < N
    m = ((uint16_t)T * N') & 0xFFFF                     // __mulhi3 (16-bit mul), G_AND
    t = (T + (uint32_t)m * N) >> 16                     // __mulsi3, add, G_LSHR by 16
    if (t >= N) t -= N                                  // conditional subtract
    return (uint16_t)t                                  // in [0, N)
mont_mul(a,b) = REDC((uint32_t)a * b)                   // __mulsi3

Orbit: x_i = g^i in Montgomery form (repeated mont_mul by g), i = 0..K-1.
Each residue maps to an angle θ = x_i * (65536 / N) → point on a circle → polyline.
The multiplicative-group orbit traces a star polygon whose density depends on ord(g) mod N.

GATE_N: fold K residues of the orbit. No division anywhere.
```

## Screen layout

```
row 1:  [HUD top: "MONTORBIT CRC=XXXX  N=XXXX"]
rows 3-20: 128×128 BG3 canvas — star-polygon polyline of the orbit
row 25: [HUD bot: "MONTGOMERY REDC (NO DIV)"]
```

## Display architecture

- BG3 2bpp BitmapCanvas (chr=0x0000, map=0x4000), Bresenham polyline via `canvas_line`.
- TextLayer top/bottom HUD. TitleLayer "MONT REDC" / "MODMUL NO DIV".
- Palette: dark bg, cyan orbit, magenta vertices, white current point.

## Files

| File | Purpose |
|------|---------|
| `examples/65816/montorbit.h` | Montgomery REDC + orbit + gate CRC |
| `examples/snes/montorbit.c` | SNES ROM (animated star-polygon orbit) |
| `examples/snes/corpus/montorbit_sim.c` | Corpus slice |
| `tools/montorbit-sim.c` | Host oracle |
| `dev/montorbit.sh` | Gate script |
| `dev/montorbit.lua` | MAME Lua assert |

## Differential gate

- `corpus_result = montorbit_gate_crc()` — folds the orbit residues.
- **EXPECT `0xBA9B`** — fill after first run.
- **5-way bar** — no far pointers.
- **Disasm probes:** `__mulsi3 ≥ 1`, `rep/sep ≥ 1`, and **`__udivsi3`/`__umodsi3` == 0** (the point:
  division-free).

## Verification steps

1. Host oracle compiles and prints a plausible CRC.
2. ROM builds clean; snes-checksum.py exits 0.
3. Corpus slice host-compiles; exits 0.
4. `dev/run.sh montorbit` — gate PASS (incl. no-division probe).
5. `dev/run.sh corpus-a16` — all slices PASS.
6. Inspect `build/montorbit-jg.png` — star-polygon orbit visible.
7. Copy screenshot → `docs/plans/screenshots/montorbit.png`.
8. /snes-rom-page publishes.

## Verification results (2026-07-01)

Gate (`dev/run.sh montorbit`):
```
==> host oracle: montorbit gate hash = 0xBA9B
    __mulsi3/__mulhi3=5  rep/sep=13  division-libcalls=0 (want 0)
    PASS  Montgomery modmul confirmed (multiply+shift+mask, division-free)
SMOKE: PASS off=0x69 len=2 got=0xBA9B (ran 500 frames, bsnes-jg)
    SHOT: PASS corpus=0xBA9B (snapshot at frame 500)  [MAME]
RESULT: PASS
```
5-way (`dev/run.sh _demo5 montorbit`): host==default==a16==xy16==0xBA9B on bsnes-jg, -verify clean.
**No compiler bug.** The Montgomery REDC path emits __mulsi3/__mulhi3 + shift + mask + conditional
subtract with **zero** division libcalls — exactly the division-free modmul this demo targets.
Montgomery constants verified (N'=40959, R mod N=24575, R²mod N=1641; 7·11 mod N=77).
