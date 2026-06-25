# Trig Phase 3 — derived (tan/asin/acos) + hyperbolic (sinh/cosh/tanh), Q2.14 + Q16.16

**Status:** DONE + VERIFIED 2026-06-26 (worktree `wt/321-trig-phase3`). 4-way differential PASS on
both emulators, `corpus_result == 0x759567C4`; cross-width accuracy PASS (incl. the 32-bit
hyperbolic derived from the now-compiled `fix16_exp`). Completes the trig set across both widths;
extends Phase 2 ([2026-06-26-trig-phase2-q214-cordic.md](2026-06-26-trig-phase2-q214-cordic.md)) and
the master plan ([2026-06-25-…-differential-test-1.md](2026-06-25-trig-functions-as-a-c-compiler-differential-test-1.md)).

## Context

The master plan's Phase 3 (optional): **derived 16-bit `tan/asin/acos`** and **hyperbolic
`sinh/cosh/tanh`** (32-bit via the already-vendored `fix16_exp`; 16-bit via CORDIC hyperbolic mode,
sweep `|x| ≤ 1` for the Q2.14 range). It completes the trig surface and adds two coverage points the
earlier phases didn't reach:

- **A 16-bit s32-libcall payload.** Phase 2's direct CORDIC was pure shift-add (zero arithmetic
  libcalls). The derived functions need a Q2.14 **divide** (`tan = sin/cos`) and **sqrt**
  (`asin/acos` via `atan2(·, √(1−x²))`), so they emit `__mulsi3`/`__divsi3` — the 16-bit-context
  analogue of Phase 1's 32-bit libcall payload, exercised here on `int16` operands.
- **CORDIC hyperbolic mode.** `sinh/cosh/tanh` use the hyperbolic rotation set (angles `atanh(2^-i)`,
  with the mandatory **repeated** `i=4,13` schedule) — a code path neither Phase 1 nor Phase 2 reach.
- **Activates `fix16_exp`.** libfixmath ships no hyperbolic functions; the 32-bit reference is
  derived from `fix16_exp` (`sinh=(eˣ−e⁻ˣ)/2`, …). `fix16_exp.c` was vendored but uncompiled until now.

## What was built

- **`tools/gen-cordic-tables.py`** extended → `examples/65816/cordic16_tables.h` gains the hyperbolic
  `atanh(2^-i)` table over the repeated schedule `[1,2,3,4,4,5..13,13,14]` (NH=16), the inverse-gain
  post-scale `CORDIC16_HGAIN=19784` (`1/An_h`, `An_h=0.82816`), convergence radius `1.118 > 1`.
- **`examples/65816/cordic16.h`** extended with: `cordic16_q214_div` / `cordic16_q214_sqrt`
  (bit-by-bit, libcall-free) helpers; derived `cordic16_tan/asin/acos`; hyperbolic
  `cordic16_sinhcosh/sinh/cosh/tanh` (unrolled hyperbolic sweep).
- **`examples/65816/k_trig16x.c`** — the kernel (mirrors `k_trig16.c`): a 32-sample additive
  volatile-stepped sweep folded over the six functions, host oracle + libm accuracy, target path.
- **`dev/k_trig16x.sh`** — the 5-stage driver (`dev/run.sh k_trig16x`).
- **`tools/trig-accuracy3.c`** — host-only cross-width harness; derives the 32-bit hyperbolic from
  `fix16_exp`.

## Design (the Q2.14 range drives it, as in Phase 2)

- **Domains kept in-format** (range `[−2, 2)`): `tan` `|x| ≤ 1.04` (so `|tan| < 2`, `cos > 0`);
  `asin` `|x| ≤ 0.95`; `acos` `x ∈ (0, 1]` (right half-plane, output `[0, π/2)`); `sinh/cosh/tanh`
  `|x| ≤ 0.97` (so `cosh < 2`). Sweep is pure additive (no multiply in input gen).
- **Hyperbolic overflow guard.** `cosh` grows fast, so the sweep seeds `x0 = ONE` (not `1/An_h`) and
  gain-corrects the result by `*HGAIN` at the end — this keeps the raw `x` (`= An_h·cosh·ONE ≤ 20933`)
  inside `int16` for `|z| ≤ 1`, where seeding `1/An_h` would overflow. `tanh = y/x` needs no
  correction (the `An_h` gain cancels).
- **Bit-exact host == target.** Derived functions use `int32` intermediates whose value semantics are
  identical on host (32-bit `int`) and target (16-bit `int`, `int32`=`long` via libcalls); the
  integer sqrt is pure shift/compare. No intermediate leaves its declared width.
- **Constant shifts.** Both the circular (Phase 2) and hyperbolic sweeps are fully unrolled — the
  hyperbolic shift schedule (incl. the `i=4,13` repeats) is hardcoded as `(position, shift)` pairs.

## Verification

1. **`dev/run.sh k_trig16x` — differential + s32/native-16-bit + accuracy, both emulators.**

```
==> 1) +mos-a16 -verify-machineinstrs clean + native 16-bit + s32 paths + NO 64-bit leak
  PASS: no 64-bit libcall
  PASS: 32-bit libcall paths exercised (2 distinct __*si3 — derived/hyperbolic payload)
  PASS: native 16-bit active (346 rep / 372 sep brackets)
==> 2) host oracle reproduces the golden (0x759567C4) + CORDIC accuracy within precision
  PASS: host oracle corpus_result=0x759567C4 == golden 0x759567C4
      tan 8.3e-4 / asin 3.9e-4 / acos 3.4e-4 / sinh 4.0e-4 / cosh 4.5e-4 / tanh 2.4e-4   ACCURACY: PASS
==> 4) MAME: host == default == +mos-a16 (corpus_result == 0x759567C4)
  default:  SMOKE: PASS addr=0x7E0200 len=4 got=0x759567C4 (ran 420 ticks)
  +mos-a16: SMOKE: PASS addr=0x7E0200 len=4 got=0x759567C4 (ran 420 ticks)
==> 5) bsnes-jg: +mos-a16 corpus_result == 0x759567C4 (independent confirmation)
  SMOKE: PASS off=0x200 len=4 got=0x759567C4 (ran 540 frames, bsnes-jg)
RESULT: PASS
```
**PASS** — bit-exact host == default(8-bit) == `+mos-a16` on MAME + bsnes-jg.

2. **Cross-width (stage 6): Q2.14 CORDIC vs Q16.16 libfixmath vs libm.**

```
  fn          err16      err32      cross      eps16
  tan      7.67e-04   7.21e-05   8.39e-04   2.00e-02
  asin     4.20e-04   1.02e-02   1.02e-02   2.00e-02
  acos     3.98e-04   1.02e-02   1.00e-02   2.00e-02
  sinh     4.56e-04   3.88e-05   4.73e-04   2.00e-03
  cosh     4.53e-04   2.33e-05   4.58e-04   2.00e-03
  tanh     5.04e-04   3.29e-05   5.04e-04   2.00e-03
CROSS-WIDTH: PASS
```
**PASS** — the hyperbolic cross-width is tight (`fix16_exp` is accurate, err32 ~3e‑5); on `asin/acos`
the 16-bit CORDIC again *beats* the 32-bit libfixmath (err16 4e‑4 vs err32 1.0e‑2), so the cross is
bounded by libfixmath's coarse polynomial.

3. **Generator reproducible:** `python3 tools/gen-cordic-tables.py --check` → in sync.

## Files

**Create:** `examples/65816/k_trig16x.c`, `dev/k_trig16x.sh`, `tools/trig-accuracy3.c`, this plan.
**Modify:** `tools/gen-cordic-tables.py` + `examples/65816/cordic16_tables.h` (hyperbolic tables),
`examples/65816/cordic16.h` (derived + hyperbolic functions), `TODO.md`, the master plan's phase
table (Phase 3 → DONE), `docs/investigations/plan-index.md`. **No compiler change** (SDK/example-level).

## Scope note

The 32-bit hyperbolic (`fix16_exp`-derived) is exercised in the host **cross-width** harness rather
than as its own separate ROM differential — `fix16_exp` is thereby compiled and validated against
libm, satisfying the master plan's "32-bit via the already-vendored fix16_exp" intent, without a
second ROM build that would duplicate Phase 1's Q16.16 differential mechanics. The trig set is now
complete; no further trig phases are planned.
