# #321 — lock the A (low) / X (high) return convention (the free, prior-art-aligned ABI piece)

**Date:** 2026-06-17
**Status:** **IMPLEMENTED** (2026-06-17) — test + docs only, no codegen change. `examples/65816/a16ret.c` +
`dev/a16ret.sh` (wired into `dev/run.sh`); decision recorded in the CC decision analysis (§"Return values —
adopted") + the prior-art note. Verification below.
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

```
==> 4) MAME: host == default == +mos-a16 (corpus_result == 0x2387)
  default:
SMOKE: PASS addr=0x7E0206 len=2 got=0x2387 (ran 60 ticks)
  +mos-a16:
SMOKE: PASS addr=0x7E0206 len=2 got=0x2387 (ran 60 ticks)
==> 5) bsnes-jg: +mos-a16 corpus_result == 0x2387 (independent confirmation)
  SMOKE: PASS off=0x206 len=2 got=0x2387 (ran 180 frames, bsnes-jg)

RESULT: PASS — A(low)/X(high) return convention is locked: i16->ldx<high>;lda<low>;rts, i8->A; corpus_result==0x2387 (both emulators)
```

**PASS** — host (0x2387, verified `cc /tmp/hostcheck.c`) == default@MAME == +mos-a16@MAME == +mos-a16@bsnes-jg.

2. **Disasm gate.** `a16ret` `+mos-a16` disasm: the `i16` return places low→A / high→X at the boundary; the
   `i8` return places the result in A.

```
==> 1) +mos-a16 -verify-machineinstrs clean
  PASS: +mos-a16 compiles clean (-verify-machineinstrs)
==> 2) return-convention disasm gate (+mos-a16, symbolic -S): i16 -> ldx<high>;lda<low>;rts, i8 -> A
  PASS: i16 return boundary 'ldx __rc3; lda __rc2; rts' — HIGH byte->X, LOW byte->A (byte-pinned: X reads __rc3 = __rc2+1)
  PASS: i8 return boundary delivers the result in A (no X load as a return register; value confirmed below)
```

**PASS** — `add16` ends `ldx __rc3; lda __rc2; rts` (high byte in X = __rc3, low byte in A = __rc2, byte-pinned
X = A+1); `add8` ends in A with no X load. `-verify-machineinstrs` clean.

3. **Non-breaking + no codegen change.** a16* suite + kernels green; `dev/run.sh corpus` → 7/7;
   `dev/run.sh fuzz 50 1` → 50/50 (returns exercised); the pre-existing a16* test disasms are **byte-identical**
   (this is doc+test only). No `vendor/` change → `0002` untouched.

No `vendor/` change → `0002` untouched (confirmed: `git status --short patches/llvm-mos/0002-321-accum16.patch`
empty; tracked diff is exactly `dev/run.sh` + the two docs + the two new files). Because the compiler binary is
unchanged by this work, every pre-existing a16* disasm is byte-identical by construction.

**a16* + kernel suite — 50/50 green.**

```
=== SUITE TOTAL: pass=49 fail=1 failed=[ a16eq] ===   # first pass
```

The lone `a16eq` failure was **environmental, not a regression**: a stale **root-owned** `build/a16eq.o`
(left by a prior run as root, 20:18) that the uid-1000 dev container can't overwrite —
`error: unable to open output file '/work/build/a16eq.o': 'Operation not permitted'`. Removed the stale
artifact (`rm -f build/a16eq.o`; no other root-owned build files remain) and re-ran:

```
RESULT: PASS — native 16-bit ==/!= (rep/lda/cmp/sep/beq) compute 0x0011; both emulators agree
```

→ **suite 50/50** (49 first-pass + `a16eq` green after clearing the stale `.o`); `a16ret` itself PASS.

**Corpus — 7/7.**

```
==> corpus: 7/7 passed
```

**Fuzzer — 49/50, with a PRE-EXISTING shared-codegen regression at seed 42 (NOT this change, NOT the
return convention).**

```
[FAIL] seed 42  mismatch: host=0xEC0D, default@MAME=0xB226, a16@MAME=0xB226, a16@bsnes=0xB226
==> fuzz: 49/50 PASS, 0 known-issue (xfail)  (1 mismatch, 0 new-crash, 0 error)
```

Diagnosis (deterministic; reproduced via `dev/run.sh fuzz 1 42`): the mismatch is **host vs target**, and
critically the *defect is in a path shared by the default 8-bit build* — `default@MAME == a16@MAME ==
a16@bsnes == 0xB226`, i.e. the `+mos-a16` codegen is identical to the non-a16 baseline here, so this is
**not** `+mos-a16`-specific and **not** the A/X return convention (the default build uses the *same* A/X
return convention and agrees with the a16 build). Decisive oracle cross-check — compiling seed 42 with the
container's **upstream unpatched** `mos-clang` (default 8-bit) on MAME:

```
=== UPSTREAM-default corpus_result ===
SMOKE: FAIL addr=0x7E0215 len=2 got=0xEC0D want=0xDEAD   # (0xDEAD = sentinel; got=0xEC0D is the value)
```

So two independent oracles — the fuzzer's exact-16-bit Python model **and** the unpatched upstream MOS
compiler on real MAME — both give **0xEC0D**; the **from-source *patched* toolchain is the outlier at
0xB226 in BOTH its default and a16 builds**. That isolates a real codegen regression in the **current shared
`vendor/` tree** (a path the default build also takes), introduced *after* the earlier-today `fuzz 50/50`
baselines — most likely a concurrent agent's uncommitted edits to shared MOS files (`MOSCombiner.cpp`,
`MOSInstrInfo.cpp`, `MOSInstrGISel.td`), rebuilt into `clang-23` at 19:45. It is **independent of this
test+docs-only plan** (zero `vendor/`/generator edits here; would reproduce on any current checkout). Filed
for separate triage in `TODO.md`; left untouched here per "only commit your work / leave other workers'
in-progress `vendor/` edits."

**Step 3 verdict:** non-breaking confirmed for this change — suite 50/50, corpus 7/7, no `vendor/`/`0002`
change. The fuzzer's seed-42 mismatch is a pre-existing shared-backend regression unrelated to the return
convention (proven by the upstream cross-check), tracked separately.

## Out of scope

- The A16-aware return optimization and the xy16 32-bit-return evolution (both noted above as follow-ups).
- The argument-passing and frame-storage sub-decisions — tracked in the CC decision analysis; they need a
  product steer (first-pass demonstrator vs. match-the-commercial-ABI) and measurement after xy16.
