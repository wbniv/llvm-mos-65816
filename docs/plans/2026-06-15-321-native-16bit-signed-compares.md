# #321 native s16 — native 16-bit signed ordering compares (`< <= > >=` on `short`)

**Date:** 2026-06-15 · **Status:** **DONE** (Option A, verified, patch round-trips)

## Evidence (raw output)

`dev/run.sh a16scmp` — signed compare = `eor #$8000` ×2 + native 16-bit `cmp` + `bcs` under rep/sep:
```
      91: c2 20        	rep	#$20
      95: 49 00 80     	eor	#$8000
      9c: 49 00 80     	eor	#$8000
      a3: c5 00        	cmp	$0
      a5: e2 20        	sep	#$20
      a7: b0 17        	bcs	$c0
  PASS: 7 rep · 8 eor #$8000 · 4 16-bit cmp · no 8-bit cpx/cpy chain
SMOKE: PASS addr=0x7E020A len=2 got=0x0111 (ran 60 ticks)
  SMOKE: PASS off=0x20A len=2 got=0x0111 (ran 180 frames, bsnes-jg)
RESULT: PASS — native 16-bit signed compares compute 0x0111; both emulators agree
```
`-verify-machineinstrs` clean. Implemented exactly as Option A: a one-block hook in
`legalizeICmp` rewrites s16 `SLT` to `ULT` on `(a^0x8000, b^0x8000)`; the XORs use
the native EOR and the compare re-legalizes through the native UGE carry path — no
selector or pseudo changes. Non-breaking: corpus 7/7, all 19 a16* tests green, patch
`0002` round-trips.

## Original plan (Option A chosen)


## Context

The compare family so far: unsigned ordering (carry path, `selectSbc16`), then
equality (Z path, fused `CmpBrImag16`/`CmpBrImm16`). The remaining gap is **signed**
ordering — `a < b` etc. on `short`. Today an s16 signed compare narrows to the 8-bit
N^V byte chain (`legalizeICmp` SLT case, MOSLegalizerInfo.cpp:1421+: a per-byte
`G_SBC`, then "XOR the accumulator with 0x80 iff V, reexamine N").

## Design decision — two options

### Option A (recommended): sign-flip to the unsigned path
Signed order equals unsigned order after flipping the sign bit:
`a <ₛ b  ⟺  (a ^ 0x8000) <ᵤ (b ^ 0x8000)`. The XOR is the already-native 16-bit
`EOR` (selectAlu16Native), and the unsigned compare is the already-native UGE
carry path (`selectSbc16`, `rep; lda; cmp; sep; bcc/bcs`). So under `hasAccum16`,
in `legalizeICmp`'s **SLT** case (the canonical signed primitive — `sgt/sle/sge`
all reduce to it via `negateInverseComparison` / operand swap):
1. `LHS' = G_XOR(LHS, 0x8000)`, `RHS' = G_XOR(RHS, 0x8000)` (native 16-bit EOR).
2. Re-emit as the unsigned comparison on `LHS'`/`RHS'`: `slt(a,b)` = `ult(a',b')`
   = `!uge(a',b')` — build the existing 16-bit UGE `G_SBC` and let the branch sense
   (or a boolean negate) absorb the `!`.

**Why preferred:** reuses two already-verified native paths (EOR + UGE carry), no
new flag handling (no V, no N^V idiom), no new pseudo. The cost is two extra
`eor #$8000` per compare — cheap, and constant RHS folds (`(b^0x8000)` is a
compile-time constant when b is).

### Option B: native N^V
Emit a 16-bit `SBC` (not `cmp` — `cmp` doesn't set V) producing N and V, then the
65816 `bvc .skip; eor #$8000; .skip: bmi/bpl` sign-fix idiom. More flag surface (V
flag modeling, a conditional sign-flip block), a new SBC-based compare-branch, and
the trickiest correctness of the compare family. Rejected for v1.

## Scope (v1, Option A)
Native 16-bit signed `< <= > >=` (canonical SLT) under `+mos-a16`, both the
branch-fused and the boolean-result forms (the sign-flip produces an ordinary UGE
result, which already supports both). RHS-constant sign-flip folds at compile time.

## Implementation sketch
- `MOSLegalizerInfo.cpp` `legalizeICmp`: in the SLT handling, when
  `STI.hasAccum16() && Type == s16`, build `LHS'/RHS'` via `Builder.buildXor(S16,
  X, buildConstant(S16, 0x8000))` and rewrite the comparison to the unsigned form
  on the flipped operands (set the instruction's predicate to ULT/UGE and operands,
  then fall into the existing `NativeS16` UGE machinery). Verify the canonical
  reductions (`negateInverseComparison`, swap) still hold so all four signed
  predicates funnel through this one transform.
- No selector changes expected (the flipped compare is an ordinary native UGE
  `G_SBC` → `selectSbc16`; the XORs → `selectAlu16Native`).

## Test — `examples/65816/a16scmp.c` + `dev/a16scmp.sh`
Signed compares with a NEGATIVE operand so a wrong (unsigned) interpretation
misfires, e.g. `(-2) < 1` true, `(-2) > 1` false, plus a both-negative pair.
Pick a fresh corpus value. Disasm gate: each compare shows `eor #$8000` (×2 or one
folded) + native `cmp` under rep/sep, no 8-bit `cpx/cpy` and no 8-bit N^V `eor #$80`
byte fixup; MAME + bsnes-jg assert. Wire into `dev/run.sh`.

## Verification
1. Build clean; `-verify-machineinstrs` clean.
2. `dev/run.sh a16scmp` → native sign-flip + 16-bit cmp, correct signed result both
   emulators (esp. the negative-operand cases).
3. Non-breaking: corpus 7/7 + all 18 a16* + a16scmp green.
4. `dev/regen-patch.sh` → 0002 round-trips.
If a sign/branch-sense error appears and isn't resolved within the 3-attempt
debugging limit, revert and record the failure mode — signed compares must not ship
unverified.

## Critical files
- `vendor/.../MOSLegalizerInfo.cpp` — SLT sign-flip transform in `legalizeICmp`.
- `examples/65816/a16scmp.c`, `dev/a16scmp.sh` (new); `dev/run.sh` (wire-in).
- `patches/llvm-mos/0002-321-accum16.patch`; `docs/ROADMAP.md`; `TODO.md`; this plan.

## Remaining roadmap after this (for reference)
- Compare→select / equality producing a stored bool (flag → byte materialization).
- Variable shifts, shift amount ≥ 8 / `xba`, 1-byte `inc a`/`dec a`, memory-RMW `inc abs`.
- Indexed/array access (large surface; overlaps the X-flag xy16 mode dimension).
- A16-threading (value stays live in A across ops — biggest win, but reintroduces
  the coalescer-crash risk; **explicitly deferred behind a broad corpus**).
- Hardware-stack ABI / 16-bit calling convention (**upstream-gated** — needs
  maintainer ABI blessing; can't land unilaterally).
