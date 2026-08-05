# Review: llvm-mos PR #575 — hand-tuned single-precision softfloat for MOS 6502

<!-- DRAFT REVIEW (internal; posting is user-triggered — NOT POSTED).
     Target: https://github.com/llvm-mos/llvm-mos/pull/575 (third-party PR, 2,646 lines,
     4 hand-written 6502 FP routines). Produced 2026-08-05 by the review agent (independent
     bit-exact Python models per routine, fuzzed vs numpy float32 as IEEE-754 ground truth;
     divergences hand-traced back to the exact assembly).
     PRE-FLIGHT BEFORE POSTING: re-check every line reference against GitHub's diff view —
     the references below come from a local diff dump and may be offset.
     Strategic note: a rigorous review of a third-party PR is the strongest available
     engagement move for our 11-PR queue (demonstrates the review capacity we're requesting;
     reciprocity tends to follow). -->

**Method.** For each of the four new routines: hand-traced the 6502 assembly
instruction-by-instruction, transcribed it into an independent bit-exact Python model, and
fuzzed against `numpy` float32 arithmetic — random pairs plus targeted edge classes
(subnormals, overflow/underflow boundaries, signed zero, NaN/Inf). Every divergence was
traced by hand back to the exact assembly to confirm root cause.

## Verdict: two real, high-confidence bugs in `addsf3.c` — one severe

### Bug 1 (severe): results exactly 2× too large for a common subtraction pattern

Trigger: `a - b` (opposite signs) where the correctly-rounded difference is a subnormal
float32 (< ~1.175e-38) — i.e., subtracting nearly-equal small floats: small-measurement
differences, numerical derivatives, tiny residuals. In a targeted 200,000-sample fuzz of
same-exponent opposite-sign subtractions, **31% of cases whose true result is a nonzero
subnormal came back exactly double the correct value.**

Root cause: the normalize bit-loop (`addsf3.c`, `.L__addsf3_norm_bit_loop`) tests
`A_EXP == 0` *before* deciding whether to shift, using the pre-decrement value:

```
bit A_M3
bmi norm_done      ; bit7 set -> stop
lda A_EXP
beq norm_done      ; exp==0 -> stop
[shift mantissa left 1, dec A_EXP]
jmp norm_bit_loop
```

When `A_EXP` is 1 (always the case just before crossing into subnormal territory) the stop
condition is false, so the loop performs one more shift-and-decrement, landing on `exp=0`
with the mantissa doubled. IEEE-754 subnormals (`exp` field = 0) share the *same* reference
scale as the smallest normal (`exp` field = 1) — they do not get an extra halving. The loop
must stop one iteration earlier: when the working exponent is about to reach 0, relabel the
mantissa as-is, no further shift. Confirmed by exact derivation from the IEEE-754 subnormal
value formula, cross-checked against numpy; it exactly explains every mismatch of this shape.

Note the file's `NORMALIZE OVERSHOOT CORRECTION` block explicitly handles the *opposite*
boundary (bit 7 set exactly as exp hits 0 → undo one shift) — this asymmetric twin (one
shift too many when bit 7 never gets set) was missed.

### Bug 2 (real, less frequent): alignment sticky bit merged with the wrong sign on subtract

When the smaller operand `b` loses low bits during exponent alignment (`B_STK` set), the
code merges it into the result sticky identically for add and subtract:

```
lda B_STK
beq skip
lda #1
sta A_STK
skip:
```

For addition this is correct (dropped `b` bits → true sum slightly larger → bias round-up).
For subtraction it is backwards: subtracting a truncated (smaller) `b` makes the computed
difference slightly *larger* than true, so a nonzero alignment sticky should bias rounding
*down*. In a 300k-pair random fuzz this produced ~63 mismatches, each exactly +1 ULP, all
consistent with an incorrect round-up at a should-be round-to-even tie or round-down — the
classic sticky-bit sign flip in hand-written FPU subtract logic.

Both bugs are inherited unmodified by `__subsf3` (a pure tail-call into `__addsf3`).

## Why the PR's test claims didn't catch this

The PR reports 25/25 `addsf3_test.c` vectors bit-exact and a 22-vector hand-written
`__subsf3` smoke test. Fixed vector sets miss bugs that require a specific magnitude
relationship between random operands. Neither bug needs adversarial construction — the
severe one falls to plain `random.getrandbits` fuzzing at a 31% in-class hit rate.

**Concretely: the claimed 22-vector `__subsf3` smoke test is not in the diff.** The PR
touches exactly 5 files (`CMakeLists.txt` + the 4 new `.c` files) — no test file. The claim
is unverifiable by any reviewer or CI, and `subsf3.c` (actually broken, per the above) would
ship with zero in-tree regression protection.

## `mulsf3.c` — no bugs found

500k random pairs + ~371k targeted cases (both-subnormal, mixed subnormal/normal,
near-overflow, near-underflow with rounding stress): **0 mismatches**. Exponent arithmetic,
subnormal renormalization, 24×24→48 shift-add multiply, bit-47 normalize, and
round-to-nearest-ties-to-even all check out.

## `divsf3.c` — no correctness bugs; two fragility notes

300k random pairs + exhaustive boundary scan: no bugs. Two non-bug findings for the author:

- The post-loop "R≥D cleanup" is dead code — the loop invariant `R<D` holds at every
  iteration regardless of branch; the ~15–20 byte block never fires, and the commit
  message's stated rationale (exact-division boundary handling) does not hold given the
  actual invariant.
- The underflow shift-count computation uses only the low byte of a 16-bit signed exponent.
  Safe today only because `__divsf3`'s achievable exponent range keeps the high byte at
  `0x00`/`0xFF` — an invariant documented nowhere near the code; a trap for future edits.

## Other PR-level observations

- `__attribute__((naked, ...))` has no precedent anywhere in `compiler-rt/lib/builtins`
  (whole-tree grep). Not wrong per se, but worth explicit confirmation that it survives LTO
  across every MOS build configuration, not just the tested path.
- There is no MOS lit infrastructure in `compiler-rt/test/builtins`, so none of the PR's
  correctness claims run under upstream CI — they rest entirely on the author's out-of-tree
  `mos-sim` runs, which no reviewer can reproduce from the PR alone.

## Bottom line

A well-organized, well-documented PR with genuine performance wins (the `__divsf3` 10×
speedup reasoning is sound) — but it should not merge as-is. The `addsf3.c`/`subsf3.c`
subnormal bug is wrong roughly a third of the time for an ordinary subtraction pattern.
Recommend: flag the two `addsf3.c` bugs as blocking, and ask for the missing `subsf3` test
to land in-tree — ideally as a fuzz-based regression test, since fixed vectors demonstrably
missed both bugs.
