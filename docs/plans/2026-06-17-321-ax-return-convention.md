# #321 — lock the A (low) / X (high) return convention (the free, prior-art-aligned ABI piece)

**Date:** 2026-06-17
**Status:** **OPEN** (forward plan; not yet implemented).
**ROADMAP:** step 5 (M2) — the calling-convention decision's one trivial, no-controversy piece.
**Context:** [CC decision analysis](../investigations/65816-calling-convention-decision.md) (why this is the
piece to land first) · [prior-art note](../320-321-65816-c-abi-prior-art.md) (WDC816CC p.21 / ORCA `A_X`).

## Why this is the first CC piece to land

Of the four calling-convention sub-decisions, the return convention is the **only one that is both free and
uncontroversial**:

- **It is already what llvm-mos emits.** Verified 2026-06-17 (`+mos-a16`, `-Os`): an `i8` return lands in
  **A**; an `i16` return lands in **A (low byte) : X (high byte)**:
  ```asm
  ; unsigned short add16(unsigned short a, unsigned short b){ return a+b; }
  add16: … rep #32; lda __rc2; adc __rc4; sta __rc2; sep #32
         ldx __rc3      ; X = HIGH byte
         lda __rc2      ; A = LOW  byte
         rts
  ```
  This is **emergent** from `CC_MOS` byte-splitting (there is no separate `RetCC_MOS`) — *not* a deliberate,
  documented, or **regression-guarded** decision.
- **It is the documented prior art** — WDC816CC manual p.21 ("the high word of the result … is in the X
  register, while the low word is in the Accumulator") and ORCA/C's `A_X` return class.
- **It aligns with #321.** A 16-bit `+mos-a16` result already lives in `A16` (= A holds the 16-bit low word);
  a future 32-bit result's high word is "just X" once xy16 lands.

So "adopt" here means **convert an untested emergent behavior into a deliberate, tested ABI invariant** —
cost ≈ zero, and it de-risks every future `RetCC` / `A16` / xy16 change against silently breaking the
boundary. It is also the first concrete CC commitment we can point at upstream.

## Goal

Make **A (low) / X (high)** a deliberate, documented, **differential-regression-guarded** #321 return
convention — **without changing codegen**. A value-level micro-test (host == default == `+mos-a16` on both
emulators) + a disasm gate, so a later `RetCC`/A16/xy16 change can't silently break it.

## Non-goals (explicit — keep this small)

- **The `+mos-a16` return round-trip optimization** (`A16` → `__rc2:__rc3` pair → reload low byte). Keeping
  the value in `A16` and lifting the high byte via `XBA`→X is an **A16-threading-adjacent optimization** —
  separate plan; this one asserts the *convention*, not the *efficiency*.
- **The 16-bit-register return** (32-bit result = low word in `A16`, high word in 16-bit X) — needs **xy16**.
- **Arg passing & the frame fork** (the hard CC sub-decisions) — see the
  [CC decision analysis](../investigations/65816-calling-convention-decision.md).

## Work

1. **Regression micro-test.** `examples/65816/a16ret.c` + `dev/a16ret.sh`, following the `a16eqval*`
   template: a 16-bit-returning function (and an 8-bit one) whose results feed `corpus_result`; assert
   `corpus_result` agrees **host == default == +mos-a16** on **MAME + bsnes-jg**, plus a **disasm gate** that
   the `i16` return leaves the low byte in A and the high byte in X at the boundary (and `i8` in A). Wire
   into `dev/run.sh`. (The fuzzer already exercises 16-bit returns — every recursive `fN` returns
   `unsigned short` through this path — so it's also under the differential oracle there.)
2. **Document the decision.** Add a short "Return values — adopted" note to the
   [CC decision analysis](../investigations/65816-calling-convention-decision.md) (and/or the prior-art note)
   recording that A (low) / X (high) is the chosen #321 return convention, citing the verified codegen + WDC
   p.21 / ORCA `A_X`.
3. **No codegen change.** This plan is test + docs only; confirm the a16* suite stays byte-identical.

## Verification (the spec — run on a QUIET box, paste raw output under each step, mark PASS/FAIL)

1. **Value differential.** `dev/run.sh a16ret` → `corpus_result` host == default == `+mos-a16` on MAME +
   bsnes-jg.
2. **Disasm gate.** `a16ret` `+mos-a16` disasm: the `i16` return places low→A / high→X at the boundary; the
   `i8` return places the result in A.
3. **Non-breaking + no codegen change.** a16* suite + kernels green; `dev/run.sh corpus` → 7/7;
   `dev/run.sh fuzz 50 1` → 50/50 (returns exercised); the pre-existing a16* test disasms are **byte-identical**
   (this is doc+test only). No `vendor/` change → `0002` untouched.

## Out of scope

- The A16-aware return optimization and the xy16 32-bit-return evolution (both noted above as follow-ups).
- The argument-passing and frame-storage sub-decisions — tracked in the CC decision analysis; they need a
  product steer (first-pass demonstrator vs. match-the-commercial-ABI) and measurement after xy16.
