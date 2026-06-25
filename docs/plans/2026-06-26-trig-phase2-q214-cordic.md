# Trig Phase 2 — 16-bit Q2.14 CORDIC as the native-s16 / zero-libcall differential

**Status:** DONE + VERIFIED 2026-06-26 (worktree `wt/321-trig-phase2`). 4-way differential PASS on
both emulators, `corpus_result == 0x9446C734`; `+mos-a16` compiles native 16-bit with **zero
arithmetic libcalls**; cross-width accuracy PASS. Extends Phase 1
([2026-06-25-trig-functions-as-a-c-compiler-differential-test-1.md](2026-06-25-trig-functions-as-a-c-compiler-differential-test-1.md));
generic conventions in `~/SRC/CLAUDE.md` and the project `CLAUDE.md`.

## Context

Goal (user, from the master trig plan): **test the C compiler** — this fork's `+mos-a16`
16-bit-accumulator codegen — with a realistic fixed-point trig workload, two ways. Phase 1 shipped
the **Q16.16** side (vendored libfixmath): a 32-bit fixed-point payload that leans on the **s32
libcall paths** (`__mulsi3`/`__divsi3`/`__udivsi3`) and 16×16→32 products. That left the *other*
half of the `+mos-a16` surface — **pure native 16-bit arithmetic with no libcalls** — under-exercised.

Phase 2 fills that gap with the master plan's specified deliverable (lines 147–153): a **Q2.14
16-bit CORDIC** for `sin/cos/atan/atan2`, a **fresh re-implementation** (the plan marks CORDIC as
"re-implementation", not a vendor — and `grep -ri cordic` confirmed nothing pre-existed), plus a
**cross-width accuracy harness** comparing the 16-bit results to Phase 1's 32-bit reference.

**Why CORDIC is the right complement.** CORDIC is shift-and-add only — *no multiply, no divide*. So
under `+mos-a16` it lowers to almost-entirely `rep`/`sep`-bracketed native 16-bit ALU code with
**zero arithmetic libcalls**. Where Phase 1's driver *asserts the s32 libcalls fire*, Phase 2's
driver *asserts they (and all `__*hi3`/`__*si3`/`__*di3` mul/div/shift helpers) are absent* — the
exact inverse, and a clean second coverage point for the same opt-in feature.

## What was built

- **`tools/gen-cordic-tables.py`** → generates **`examples/65816/cordic16_tables.h`** (tracked,
  regenerable; `--check` verifies sync). Derives the per-iteration `atan(2^-i)` table and the
  inverse-gain seed `K = round(ONE/An)` from first principles — no magic numbers. `N=15`,
  `ONE=16384`, `K=9949`, `HALFPI=25736`, convergence radius `1.743226 rad > π/2`.
- **`examples/65816/cordic16.h`** — the re-implementation (header-only static-inline):
  `cordic16_sincos/sin/cos` (rotation mode), `cordic16_atan/atan2` (vectoring mode). Pure `int16_t`.
- **`examples/65816/k_trig16.c`** — the kernel, mirroring `k_trig32.c`: a 32-sample sweep folded
  (rotate-left-1 ⊕) into `corpus_result`, a `#ifdef HOST` oracle that computes the golden and an
  libm accuracy report, and the target path that stores `corpus_result` and spins.
- **`dev/k_trig16.sh`** — the 5-stage driver (`dev/run.sh k_trig16`).
- **`tools/trig-accuracy.c`** — host-only cross-width harness: Q2.14 CORDIC vs Q16.16 libfixmath vs
  libm on the shared functions.

## Design decisions (the format drives all of them)

Q2.14 is `int16` with 14 fractional bits → representable range **[−2, +2)**. Three consequences,
each handled deliberately so the result is an honest, in-format, bit-exact payload:

1. **π does not fit, so angles stay in-format.** `sin/cos` inputs are kept in `[−π/2, π/2]` (π/2 =
   1.5708 < 2 and < the CORDIC convergence radius 1.7433, so rotation mode converges with no
   quadrant reduction). `atan` input spans `(−2, 2)`; `atan2` is restricted to the **right
   half-plane** (`x > 0`, `|x|,|y| ≤ 1`) so its result stays in `(−π/2, π/2)`. (The master plan
   already anticipated this — it flags "sweep restricted to |x| ≤ 1.0 for Q2.14 range" for Phase 3.)
2. **No int16 overflow → host == target bit-exact.** Rotation mode seeds `x0 = 1/An` so the vector
   magnitude only grows `9949 → 16384` (≤ ONE) and every transient stays `< 23170`. Vectoring mode
   **pre-halves its inputs** (`atan2` is scale-invariant under `(y,x)→(y/2,x/2)`) so the
   gain-amplified magnitude `An·|v| ≤ ~30160` never leaves int16. Because no intermediate exceeds
   the int16 range, host (32-bit `int`) and target (16-bit `int`) compute identically — the
   differential bar. (The 65816 has 16-bit `int`; this is the usual host/target promotion trap, and
   keeping every value in-range is what defuses it.)
3. **Unrolled constant shifts → no variable-shift libcall.** The `N=15` iteration is fully unrolled
   so every `>> i` is a compile-time constant: no `__ashrhi3`, and identical codegen both legs.

Input generation is **pure addition of `volatile` steps** (no `t*step` multiply), so the *whole*
kernel — not just the CORDIC core — is arithmetic-libcall-free, which is what makes the stage-1
"no libcall" assertion meaningful.

## Verification

Run from the worktree (`dev/run.sh k_trig16` drives all stages in the container; cross-width is
stage 6). Raw evidence below each step.

1. **`dev/run.sh k_trig16` — 4-way differential + libcall/native-16-bit + accuracy, both emulators.**

```
==> 1) +mos-a16 -verify-machineinstrs clean + native 16-bit + NO arithmetic libcall
  PASS: no arithmetic libcall (CORDIC is pure shift-and-add native 16-bit)
  PASS: native 16-bit active (114 rep / 132 sep brackets)
==> 2) host oracle reproduces the golden (0x9446C734) + CORDIC accuracy within precision
  PASS: host oracle corpus_result=0x9446C734 == golden 0x9446C734
  PASS: every function within CORDIC precision
      sin 3.15e-04 / cos 2.46e-04 / atan 3.47e-04 / atan2 6.98e-04   ACCURACY: PASS
==> 4) MAME: host == default == +mos-a16 (corpus_result == 0x9446C734)
  default:  SMOKE: PASS addr=0x7E0200 len=4 got=0x9446C734 (ran 300 ticks)
  +mos-a16: SMOKE: PASS addr=0x7E0200 len=4 got=0x9446C734 (ran 300 ticks)
==> 5) bsnes-jg: +mos-a16 corpus_result == 0x9446C734 (independent confirmation)
  SMOKE: PASS off=0x200 len=4 got=0x9446C734 (ran 420 frames, bsnes-jg)
RESULT: PASS — Q2.14 CORDIC trig ... folds to 0x9446C734, host == default == +mos-a16 (both emulators)
```
**PASS** — bit-exact across host == default(8-bit) == `+mos-a16` on MAME + bsnes-jg.

2. **Cross-width accuracy (stage 6 of the same run): Q2.14 CORDIC vs Q16.16 libfixmath vs libm.**

```
  fn          err16      err32      cross      eps16
  sin      4.55e-04   2.83e-05   4.43e-04   1.00e-02
  cos      4.55e-04   7.75e-03   7.63e-03   1.20e-02
  atan     3.63e-04   1.02e-02   1.01e-02   1.50e-02
  atan2    4.24e-03   1.02e-02   1.22e-02   2.00e-02
CROSS-WIDTH: PASS
```
**PASS** — the two formats agree to libfixmath's algorithmic floor (as the plan predicted, the
cross-width error is bounded by the coarser 32-bit side). Notable: on **`atan` the 16-bit CORDIC
(`err16` 3.6e‑4) is *finer* than 32-bit libfixmath (`err32` 1.0e‑2)** — the CORDIC beats the
vendored reference on the inverse functions.

3. **Generator is reproducible:** `python3 tools/gen-cordic-tables.py --check` → in sync.

## Files

**Create:** `tools/gen-cordic-tables.py`, `examples/65816/cordic16_tables.h` (generated),
`examples/65816/cordic16.h`, `examples/65816/k_trig16.c`, `dev/k_trig16.sh`, `tools/trig-accuracy.c`,
this plan. **Modify:** `TODO.md`, the master trig plan's phase table (Phase 2 → DONE),
`docs/plans/plan-index.md`. **No compiler change** (`vendor/llvm-mos` untouched) — pure
SDK/example-level, runs on the existing toolchain.

## Deferred (Phase 3, unchanged from the master plan)

Derived `tan/asin/acos` (16-bit) and hyperbolic `sinh/cosh/tanh` via CORDIC hyperbolic mode (sweep
`|x| ≤ 1.0` for Q2.14 range). Tracked by the master plan's phase table, not a backlog item.
