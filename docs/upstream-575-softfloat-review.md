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
     reciprocity tends to follow).
     UPDATE 2026-08-05: both addsf3 bugs now have a VERIFIED FIX (see the final section) —
     million-case re-fuzz 0 mismatches, both original failure-seed replays now clean, real
     clang-23 compile at -O0..-O3/-Os (712 B, +37 B; still 77% below generic addsf3), both
     patched regions hand-verified in disassembly. HONEST CAVEAT: no mos-sim hardware-level
     execution run (sysroot layout friction in this checkout) — evidence is model+compile+
    disasm, stated as such. Posting options (user choice): one combined review+fix comment,
     or review comment + GitHub suggested-changes patch. -->

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


## Verified fix (2026-08-05, ours — offered to the author)

Both bugs fixed and verified: (1) the normalize loop special-cases `exp==1` — relabel to
`exp=0` with **no shift** (subnormals share the smallest normal's scale); (2) the subtract
path, on nonzero `B_STK`, ripple-decrements `[A_M3:A_M2:A_M1:A_M0]` by one unit and
force-sets sticky (true difference = computed − f, f∈(0,1) unit → represent as
(computed−1) + positive inexact remainder). The ripple can never underflow an all-zero
tuple: post-alignment `B_M3` bit 7 is provably 0 while `A_M3` bit 7 is 1 (proof in the
patch comment; 2M-case targeted search found zero counterexamples).

Verification: independent IEEE-754 re-derivation before coding; model re-fuzz 1M pairs → 0
mismatches; exact replay of the original failing seeds (8,267/26,594 subnormal and 63/300k
sticky) → 0; compiled with the fork's real `clang-23 -target mos` at every opt level —
clean, byte-identical 712 B `.text` (675→712, +37 B; the PR's size win stands); both
patched regions hand-verified in the disassembly (labels, branch targets, the
`dec` ripple chain, the `cmp #1/beq` check). NOT run: `mos-sim` execution (sysroot layout
friction) — flagged rather than claimed.

```diff
--- a/compiler-rt/lib/builtins/mos/addsf3.c
+++ b/compiler-rt/lib/builtins/mos/addsf3.c
@@ -598,12 +598,44 @@
         "lda " A_M1 "\n" "sbc " B_M1 "\n" "sta " A_M1 "\n"
         "lda " A_M2 "\n" "sbc " B_M2 "\n" "sta " A_M2 "\n"
         "lda " A_M3 "\n" "sbc " B_M3 "\n" "sta " A_M3 "\n"
-        // Merge b's sticky into a's sticky.
+        // FIX: a nonzero B_STK here means b's true value is slightly
+        // LARGER than the truncated value we just subtracted (its low
+        // bits were dropped during alignment), so the difference we
+        // just computed is slightly TOO LARGE -- by a strictly-positive
+        // amount less than one unit of A_M0's LSB.  This is the
+        // opposite correction from the same-sign ADD path above (where
+        // a nonzero B_STK correctly biases the round UP): here it must
+        // bias the round DOWN.  Implement that by borrowing one full
+        // unit out of the [A_M3:A_M2:A_M1:A_M0] tuple (ripple decrement)
+        // and then marking sticky unconditionally -- the leftover
+        // fractional amount (strictly between 0 and 1 unit) is never
+        // exactly representable, so any later round decision must treat
+        // this position as inexact. (The ripple decrement can never
+        // underflow an all-zero tuple: whenever B_STK can be nonzero, an
+        // alignment shift occurred, and a logical right-shift always
+        // zero-fills its vacated top bit, so B_M3's bit 7 is provably 0
+        // post-shift while A_M3's bit 7 is provably 1 here [exp != 0],
+        // so the tuple this subtract produces can never be exactly zero
+        // when B_STK is set.)
         "lda " B_STK "\n"
-        "beq 9f\n"
+        "beq .L__addsf3_sub_stk_done\n"
+        "dec " A_M0 "\n"
+        "lda " A_M0 "\n"
+        "cmp #$ff\n"
+        "bne .L__addsf3_sub_stk_set\n"
+        "dec " A_M1 "\n"
+        "lda " A_M1 "\n"
+        "cmp #$ff\n"
+        "bne .L__addsf3_sub_stk_set\n"
+        "dec " A_M2 "\n"
+        "lda " A_M2 "\n"
+        "cmp #$ff\n"
+        "bne .L__addsf3_sub_stk_set\n"
+        "dec " A_M3 "\n"
+        ".L__addsf3_sub_stk_set:\n"
         "lda #1\n"
         "sta " A_STK "\n"
-        "9:\n"
+        ".L__addsf3_sub_stk_done:\n"

         // Exact cancellation (whole tuple + sticky all zero) -> +0.
         // Per IEEE 754, "correctly-rounded x - x" returns +0 for any
@@ -679,6 +711,24 @@
         "bmi .L__addsf3_norm_done\n"
         "lda " A_EXP "\n"
         "beq .L__addsf3_norm_done\n"                  // subnormal -- stop
+        // FIX: exp==1 is the transition into subnormal representation,
+        // not one more normal-to-normal renormalization step.  Normal
+        // exponents E and E-1 (both >=1) share a "shift mantissa left 1,
+        // decrement exp" invariant that preserves value; that invariant
+        // does NOT extend to E=1 -> E=0, because IEEE 754 subnormals
+        // (biased exp field 0) reuse the SAME reference scale as the
+        // smallest normal (biased exp field 1) -- they just drop the
+        // implicit leading 1.  So at exp==1 with bit 7 still clear, the
+        // CURRENT (unshifted) mantissa is already the correct subnormal
+        // encoding: relabel exp to 0 and stop, without shifting.
+        // Shifting here as if crossing a normal exponent boundary
+        // silently doubles the result. (A same-shape check already
+        // exists a few lines below, in the OVERSHOOT CORRECTION block,
+        // for the opposite boundary condition -- bit 7 becoming set
+        // exactly as exp reaches 0 -- but that fix is one-directional
+        // and does not cover this case.)
+        "cmp #1\n"
+        "beq .L__addsf3_norm_to_subnormal\n"
         "lda " A_STK "\n"
         "lsr a\n"                            // C <- stk bit 0
         "rol " A_M0 "\n"                     // shift with sticky into new m0[0]
@@ -690,6 +740,11 @@
         "dec " A_EXP "\n"
         "jmp .L__addsf3_norm_bit_loop\n"

+        ".L__addsf3_norm_to_subnormal:\n"
+        "lda #0\n"
+        "sta " A_EXP "\n"
+        "jmp .L__addsf3_norm_done\n"
+
         ".L__addsf3_norm_done:\n"
         // ================================================================
         // NORMALIZE OVERSHOOT CORRECTION (subtract path only).
```
