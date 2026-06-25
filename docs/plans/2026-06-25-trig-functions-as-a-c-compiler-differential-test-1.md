# Trig functions as a C-compiler differential test (16-bit + 32-bit fixed point)

**Status:** Phase 1 DONE + VERIFIED 2026-06-25 (worktree `wt/321-trig`) — 4-way differential PASS on
both emulators, `corpus_result == 0x068A6933`, accuracy within precision, no 64-bit libcall leak;
regression k_hopalong PASS + corpus 7/7. Phases 2–3 (16-bit CORDIC, hyperbolic) DEFERRED. Extends the
standing project guide; generic conventions in `~/SRC/CLAUDE.md` and the project `CLAUDE.md`.

## Context

Goal (user): **test the C compiler** — this `llvm-mos-65816` fork, specifically `+mos-a16`
16-bit-accumulator codegen and the 32-bit (s32) libcall paths — with a substantial, realistic math
workload: fixed-point trig implemented two ways (16-bit and 32-bit), **verified against a host golden
reference** and **compared against each other / against true math within the precision each format
allows**.

Two distinct comparisons, kept separate:
- **Bit-exact differential** (proves the *compiler*): the *same integer C* compiled
  host / default(non-`+mos-a16`) / `+mos-a16` must produce identical bytes on MAME and bsnes-jg. This
  is the project's existing bar; `examples/65816/k_hopalong.c` + `dev/k_hopalong.sh` is the template.
- **Accuracy within precision** (proves the *math*): a host-only harness compares the fixed-point
  results to `libm` and to each other, each held to its format's tolerance.

**Reference-implementation policy (user directives):** prefer existing, established references over
hand-written code; **take whatever functions each reference ships — the two sides may cover different
sets**; **defer all re-implementation to a later phase** (Phase 1 is pure drop-in). There is no
fixed-point trig in the repo (only the SDK's `fixed_point.h` arithmetic class), so references come
from outside.

| Side | Reference | Functions (as shipped) | Phase |
|---|---|---|---|
| 32-bit Q16.16 | **libfixmath** (vendored, MIT) — drop-in | `sin cos tan asin acos atan atan2` | **1** |
| 16-bit Q2.14 | **CORDIC** — re-implementation | `sin cos atan atan2` (direct) | 2 |
| both | derived `tan/asin/acos` (16-bit) + optional hyperbolic `sinh/cosh/tanh` | | 3 (optional) |

Golden reference = host `libm` (`<math.h>`).

## What was built (Phase 1)

- **Vendored libfixmath** at `examples/65816/libfixmath/` (tracked, MIT `LICENSE` preserved).
  Upstream `PetteriAimonen/libfixmath` @ **`9318ccd9428114d318eb8703a7e40c152b9059c7`**. Minimal set:
  `fix16.{c,h}`, `fix16_trig.c`, `fix16_trig_sin_lut.h`, `fix16_exp.c` (Phase 3 only), `fix16_sqrt.c`,
  `fixmath.h`, `int64.h`, `uint32.{c,h}`. Compiled **verbatim** — this is *use*, not re-implementation.
- **`examples/65816/k_trig32.c`** — a thin headless driver (no trig logic of our own) that sweeps all
  seven `fix16_*` functions over 32 samples each (both signs / all quadrants), folds every result into
  a 32-bit rotate-xor checksum `corpus_result` (seed `0xACE1ACE1`), and under `#ifdef HOST` also runs
  a `libm` accuracy comparison. `volatile` step seeds defeat constant-folding (cf. k_hopalong). A
  `TRIG_NO_MAIN` guard lets the Phase-2 cross-width harness `#include` it.

### Design decisions (the load-bearing ones)

1. **Build contract — identical on BOTH host and target** (else the differential fails for the wrong
   reason): `-DFIXMATH_NO_64BIT -DFIXMATH_NO_HARD_DIVISION -DFIXMATH_NO_CACHE`.
   - `NO_64BIT`: `fix16_mul` uses 16×16→32 products (no `int64`); host and target take the same path.
   - `NO_HARD_DIVISION`: the **default `fix16_div` uses `uint64_t`** (fix16.c lines 302–333) — would
     diverge / is expensive on the FPU-less, divide-less 65816. This flag selects the uint32 restoring
     division. **Required**, not optional.
   - `NO_CACHE`: drops the 48 KB mutable static sin/atan cache → fully deterministic, smaller.
   - Overflow detection left **ON**: `fix16_mul/div` return the `fix16_overflow` sentinel
     (`0x80000000`) deterministically, with no signed-overflow UB.
   - `FIXMATH_SIN_LUT` **not** defined: its LUT (`fix16_trig_sin_lut.h`, 12 844 lines ≈ 51 KB) exceeds
     the 32 KiB LoROM. The default `fix16_sin` is a 6-term Taylor series instead.
2. **Compile only what Phase 1 needs**: `fix16.c`, `fix16_trig.c`, `fix16_sqrt.c` (+ `k_trig32.c`).
   `fix16_exp.c` is vendored but uncompiled until Phase 3 (hyperbolic).
3. **Sweep stays inside each function's accurate, non-overflowing domain** so the checksum never folds
   a sentinel and the accuracy numbers are meaningful: sin/cos angle ∈ [−2.36, 2.21] (Taylor-safe,
   reduced |arg| < 2.57 where `r^11` overflows Q16.16); tan ∈ [−1.34, 1.26] (far from ±π/2); asin/acos
   x ∈ [−0.93, 0.87] (away from the ±1 singularity); atan x ∈ [−3.9, 3.7]; atan2 over all 4 quadrants,
   never (0,0). The HOST oracle asserts no sentinel was hit.
4. **Accuracy ceilings reflect libfixmath's *real* precision**, not the Q16.16 LSB — the Taylor sin and
   3rd-order atan2 polynomial are far coarser than the format. Calibrated ~1.3–1.5× above measured.

## Verification

Prereqs: from-source toolchain + SDK (`dev/run.sh toolchain`, `dev/run.sh build`); `dev/run.sh xcheck`
once for the bsnes-jg leg. Run on a QUIET box (MAME settle-window rule).

### Step 1 — host oracle: compile libfixmath + reproduce golden + accuracy within precision

```
cc -DHOST -DFIXMATH_NO_64BIT -DFIXMATH_NO_HARD_DIVISION -DFIXMATH_NO_CACHE -O2 -I examples/65816 \
   examples/65816/k_trig32.c examples/65816/libfixmath/{fix16,fix16_trig,fix16_sqrt}.c -lm -o k_trig32_host
./k_trig32_host            # stdout = golden;  stderr = accuracy table
```

```
host accuracy (libfixmath fix16 vs libm, 32 samples/fn, max |err|):
  sin   1.46e-05  (eps 1.00e-04)
  cos   6.21e-03  (eps 8.00e-03)
  tan   3.07e-02  (eps 4.00e-02)
  asin  1.01e-02  (eps 1.50e-02)
  acos  1.02e-02  (eps 1.50e-02)
  atan  6.45e-03  (eps 8.00e-03)
  atan2 2.65e-03  (eps 4.00e-03)
ACCURACY: PASS
golden: 0x068A6933
```

**PASS** — libfixmath compiles for the host, every function is within the precision its algorithm
allows, no overflow sentinel, golden = `0x068A6933`.

### Step 2 — `dev/run.sh k_trig32`: 4-way differential (the compiler bar)

`+mos-a16 -verify-machineinstrs` clean + s32 codegen present + **no 64-bit `__*di3` libcall leak**;
host == default@MAME == `+mos-a16`@MAME == `+mos-a16`@bsnes-jg, all == `0x068A6933`.

```
==> 1) +mos-a16 -verify-machineinstrs clean + s32 codegen + native 16-bit + NO 64-bit leak
  PASS: no 64-bit libcall (FIXMATH_NO_64BIT/NO_HARD_DIVISION held on target)
  PASS: 32-bit libcall paths exercised (5 distinct __*si3)
  PASS: native 16-bit active (49 rep / 49 sep brackets)
==> 2) host oracle reproduces the golden (0x068A6933) + libm accuracy within precision
  PASS: host oracle corpus_result=0x068A6933 == golden 0x068A6933
  PASS: every function within libm precision
==> 3) build default + +mos-a16 ROMs
==> 4) MAME: host == default == +mos-a16 (corpus_result == 0x068A6933)
  default:  SMOKE: PASS addr=0x7E0200 len=4 got=0x068A6933 (ran 720 ticks)
  +mos-a16: SMOKE: PASS addr=0x7E0200 len=4 got=0x068A6933 (ran 720 ticks)
==> 5) bsnes-jg: +mos-a16 corpus_result == 0x068A6933 (independent confirmation)
  SMOKE: PASS off=0x200 len=4 got=0x068A6933 (ran 900 frames, bsnes-jg)
RESULT: PASS — libfixmath Q16.16 trig (7 fns) ... host == default == +mos-a16 (both emulators)
```

**PASS.** Note: the libfixmath software-32-bit-divide sweep takes ~600 emulated frames to store
`corpus_result` — far past the harness's old 3 s / 60-tick MAME defaults. `dev/_emu.sh` gained a
backward-compatible `SMOKE_SECONDS` knob (default 3, every existing test unchanged); `dev/k_trig32.sh`
sets `SMOKE_SETTLE=720`, `SMOKE_SECONDS=14`, `JG_FRAMES=900`.

### Step 3 — regression: `dev/run.sh k_hopalong` and `dev/run.sh corpus` (expect 7/7)

```
# k_hopalong (also confirms the _emu.sh SMOKE_SECONDS default-3 path is unchanged):
  default:  SMOKE: PASS addr=0x7E0200 len=2 got=0x1BBC (ran 120 ticks)
  +mos-a16: SMOKE: PASS addr=0x7E0200 len=2 got=0x1BBC (ran 120 ticks)
  bsnes-jg: SMOKE: PASS off=0x200 len=2 got=0x1BBC (ran 180 frames, bsnes-jg)
RESULT: PASS — Hopalong (Blossom) Q8.8 attractor ... host == default == +mos-a16 (both emulators)

# corpus:
  hello PASS / arith PASS / control PASS / arrays PASS / structs PASS / funcs PASS / globals PASS
==> corpus: 7/7 passed
```

**PASS** — additive change; existing tests unaffected (k_hopalong exercises the same MAME+bsnes-jg
assert path as the modified `_emu.sh`).

## Deferred

- **Phase 2 — 16-bit CORDIC** (`k_trig16.c`, `tools/gen-cordic-tables.py`): Q2.14 sin/cos/atan/atan2,
  4-way differential, and the cross-width accuracy harness `tools/trig-accuracy.c`
  (`max|int16−int32| ≤ eps16` on the shared functions). Note: libfixmath's atan/asin/acos are coarse
  (~6e-3–1e-2), so the cross-width eps will be bounded by the 32-bit side, not the 16-bit CORDIC.
- **Phase 3 (optional)** — derived 16-bit `tan/asin/acos`; hyperbolic `sinh/cosh/tanh` (32-bit via the
  already-vendored `fix16_exp`; 16-bit via CORDIC hyperbolic mode, sweep restricted to |x| ≤ 1.0 for
  Q2.14 range).
