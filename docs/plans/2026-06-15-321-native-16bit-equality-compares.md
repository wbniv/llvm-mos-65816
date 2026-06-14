# #321 native s16 — native 16-bit equality compares (`==` / `!=`)

**Date:** 2026-06-15 · **Status:** **DONE** (verified, patch round-trips)

## Evidence (raw output)

`dev/run.sh a16eq` — each ==/!= is a fused 16-bit compare-branch (rep/lda/cmp/sep/beq|bne):
```
      40: c2 20        	rep	#$20
      44: c5 00        	cmp	$0
      46: e2 20        	sep	#$20
      48: f0 15        	beq	$5f
  PASS: 5 rep #$20 bracket(s) · 3 16-bit cmp · no 8-bit cpx/cpy chain
SMOKE: PASS addr=0x7E0206 len=2 got=0x0011 (ran 60 ticks)
  SMOKE: PASS off=0x206 len=2 got=0x0011 (ran 180 frames, bsnes-jg)
RESULT: PASS — native 16-bit ==/!= compute 0x0011; both emulators agree
```
`-verify-machineinstrs` clean on a16eq + a16cmp. Non-breaking: corpus 7/7, all 18
a16* tests green. `dev/regen-patch.sh` → 0002 round-trips (2292 lines, 19 files).
All five planned traps handled (MLow-through-expansion via MLow=1 logical pseudos in
expandCmpBr16; untyped matcher fixed with s8/s16 type guards; value-use guard limits
native EQ to branch uses; A16/NZ declared in the pseudo Defs so post-RA A16 use is
safe; NE handled by the existing canonicalization + flag_val sense).

## Original plan

**Date:** 2026-06-15 · **Status:** planning

## Context

Next in the agreed compare order after unsigned ordering (`< <= > >=`). Today an
s16 `a == b` / `a != b` narrows to a two-block 8-bit chain (`cmp` high byte; `bne`;
`cpx` low byte; `bne`). Native would be one `rep; lda a; cmp b; sep; beq/bne`.

**Why this is NOT a clean mirror of the unsigned-ordering slice.** UGE was easy
because the carry flag (C) is an *allocatable* i1: `selectSbc16` emits `MLow=1`
logical pseudos producing C, and a normal `bcc/bcs` reads it — no terminator
fusion. Equality produces the **Z** flag, which is *not* an allocatable i1: a hard
invariant in `selectSbc` asserts `"All N and Z uses must be selected to terminator
instructions"` (MOSInstructionSelector.cpp:1226). So equality must be **fused into
the branch**.

**The correctness traps (must each be handled):**
1. **MLow-through-expansion.** The existing `CmpBr*` pseudos expand at
   `expandPostRAPseudo` (`expandCmpBr`, MOSInstrInfo.cpp:1309) to a *real* 8-bit
   `CMP` + `BR`. That runs *before* the REP/SEP pass (addPreEmitPass), and a real
   `CMP` carries no `MLow` → REP/SEP wouldn't bracket it → the compare runs 8-bit →
   silent miscompile. Fix: the 16-bit `expandCmpBr` arm must emit the **`MLow=1`
   logical** `CMPImag16`/`CMPImm16` (preceded by `LDAImag16` to load A16), so the
   REP/SEP pass still sees `MLow` and brackets `lda; cmp` with `rep`/`sep`. `sep`
   doesn't touch Z, so the following `BR` reads Z correctly.
2. **Untyped matcher.** `CmpNZ_match::match` (MOSInstructionSelector.cpp:840)
   matches *any* `G_SBC` regardless of operand width — so a 16-bit `G_SBC` would be
   wrongly caught by the 8-bit `m_CmpNZImag8` case. Fix: add s16-typed matchers and
   handle them **first** in `selectBrCondImm`.
3. **Value (non-branch) uses.** A 16-bit-EQ `G_SBC` whose Z feeds a non-branch
   (e.g. a stored bool) would hit the `selectSbc` assert. Fix: take the native-EQ
   path in the legalizer **only when every use of the result is `G_BRCOND_IMM`**
   (mirrors the existing zero-compare `G_CMPZ` guard at MOSLegalizerInfo.cpp:1326);
   otherwise narrow to the 8-bit chain.
4. **`!=` sense.** `ICMP_NE` is canonicalized to `ICMP_EQ` with the branch sense
   flipped (`negateInverseComparison`, top of `legalizeICmp`), so only EQ is
   handled; the `flag_val` carries the sense.

**Scope (v1):** native 16-bit `==`/`!=` where the result feeds a branch, both
operands s16 (RHS an Imag16 pair or a 16-bit immediate), gated on `hasAccum16()`.
Compare-against-zero (`x == 0`) already has its own `G_CMPZ`→`CmpBrZeroMultiByte`
path and is left as-is. Equality producing a stored bool (non-branch) stays 8-bit
(a follow-up). Signed ordering (`slt/sle/sgt/sge`, the N^V path) is a separate
follow-up.

## Design — five coordinated edits

### 1. `MOSInstrPseudos.td` — two 16-bit compare-branch pseudos (~362)
```
let mayLoad = true in {
  def CmpBrImag16 : MOSCmpBr {   // RHS in an Imag16 zp pair
    let Predicates = [HasAccum16];
    dag InOperandList = (ins label:$tgt, Flag:$flag, i1imm:$flag_val, Imag16:$l, Imag16:$r);
  }
}
def CmpBrImm16 : MOSCmpBr {       // RHS a 16-bit immediate (loop bounds etc.)
  let Predicates = [HasAccum16];
  dag InOperandList = (ins label:$tgt, Flag:$flag, i1imm:$flag_val, Imag16:$l, i16imm:$r);
}
```
`$l` is the Imag16 LHS (loaded into A16 at expansion, unlike the 8-bit forms whose
LHS is already in a GPR).

### 2. `MOSLegalizerInfo.cpp` `legalizeICmp` — native-EQ branch path
Extend `NativeS16` (line 1321) to also accept `ICMP_EQ` **only when every use of
`Dst` is `G_BRCOND_IMM`** (so the result is branch-fused, never a stored bool). In
the `ICMP_EQ` case (line 1401), when that native-EQ condition holds, build the
`G_SBC` with `CmpTy = s16` (extract Z = `getReg(4)`, copy to `Dst`) instead of the
8-bit byte split.

### 3. `MOSInstructionSelector.cpp` — s16-typed CmpNZ matchers
Add `CmpNZImag16_match` / `CmpNZImm16_match` deriving from `CmpNZ_match` but
additionally requiring `MRI.getType(CondMI->getOperand(0).getReg()) == s16`. (Also
add the same s16 guard to the existing 8-bit `CmpNZ_match` so a 16-bit `G_SBC`
never matches an 8-bit case — belt and suspenders.)

### 4. `MOSInstructionSelector.cpp` `selectBrCondImm` — s16 cases first (~1049)
Before the 8-bit `m_CmpNZ*` cases, match `m_CmpNZImm16` / `m_CmpNZImag16` and emit
`CmpBrImm16` / `CmpBrImag16` (`.addMBB(Tgt).addUse(Flag,Undef).addImm(FlagVal)
.addUse(LHS).add(RHS-or-imm)`).

### 5. `MOSInstrInfo.cpp` `expandCmpBr` — 16-bit arms
For `CmpBrImag16`/`CmpBrImm16`: emit `LDAImag16 A16 <- $l`; then `CMPImag16`/
`CMPImm16` (`addDef(C,Dead)`, `addUse(A16)`, `add($r)`, `addDef(Flag=Z,Implicit)`);
then `BR $tgt, Z(Kill), $flag_val`. Both `LDAImag16`/`CMPImag16` are `MLow=1`, so
REP/SEP brackets them; `sep` lands before `BR`, preserving Z. Add the two opcodes to
the `expandCmpBr` dispatch (MOSInstrInfo.cpp:1028) and `getInstSizeInBytes` if it
enumerates CmpBr sizes.

## Test — `examples/65816/a16eq.c` + `dev/a16eq.sh`

```c
volatile unsigned short a = 0x1234, b = 0x1234, c = 0x00FF;
volatile unsigned short corpus_result;
int main(void) {
  unsigned short r = 0;
  if (a == b) r |= 0x0001;   // equal (both 0x1234) -> true
  if (a != c) r |= 0x0010;   // 0x1234 != 0x00FF   -> true
  if (a == c) r |= 0x0100;   // false (low bytes 0x34 vs 0xFF differ; high differs too)
  corpus_result = r;          // 0x0011
  for (;;) {}
}
```
`a`/`c` are chosen so a broken low-byte-only or high-byte-only compare would
misfire. Result **0x0011**.

`dev/a16eq.sh` (clone a16cmp.sh), WANT=0x0011: disasm gate asserts ≥1 `rep`/`sep`,
≥2 16-bit `cmp` (`c5`/`cf`/`c9`...), and **0** 8-bit `cpx`/`cpy` (`e4 ec c4 cc`);
MAME + bsnes-jg assert 0x0011; wire into `dev/run.sh`.

## Verification
1. Build clean (`dev/run.sh toolchain`); `-verify-machineinstrs` clean.
2. `dev/run.sh a16eq` → each `==`/`!=` is one `rep; lda; cmp; sep; beq/bne`, no
   8-bit cpx/cpy chain; corpus_result == 0x0011 on MAME + bsnes-jg.
3. Non-breaking: corpus 7/7 + all 17 a16* + a16eq green.
4. `dev/regen-patch.sh` → 0002 round-trips.

If any step reveals a flag-liveness or MLow-bracketing miscompile that isn't
resolved within the 3-attempt debugging limit, **revert this increment** and record
the failure mode here — equality must not ship unverified.

## Land
Regen patch 0002; update ROADMAP step 5 + TODO (Done; strike equality from the
compare follow-ups); fill evidence; commit on `main` with Co-Authored-By; push.

## Critical files
- `vendor/.../MOSInstrPseudos.td` — `CmpBrImag16`/`CmpBrImm16` (~362).
- `vendor/.../MOSLegalizerInfo.cpp` — native-EQ branch path in `legalizeICmp` (~1321, ~1401).
- `vendor/.../MOSInstructionSelector.cpp` — s16 CmpNZ matchers + `selectBrCondImm` cases.
- `vendor/.../MOSInstrInfo.cpp` — `expandCmpBr` 16-bit arms (~1028, ~1315).
- `examples/65816/a16eq.c`, `dev/a16eq.sh` (new); `dev/run.sh` (wire-in).
- `patches/llvm-mos/0002-321-accum16.patch`; `docs/ROADMAP.md`; `TODO.md`; this plan.
