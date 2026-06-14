# #321 native s16 — native 16-bit absolute load/store (`g = gg`)

**Date:** 2026-06-15 · **Status:** **DONE** (verified, patch round-trips)

## Evidence (raw output)

`dev/run.sh a16abs` — `g = gg` is native 16-bit `lda abs`/`sta abs` (the platform's
long form af/8f), and the copy + the `+1` add merge into a single rep bracket:
```
       0: c2 20        	rep	#$20
       2: af 00 00 00  	lda	$0      ; lda gg
       a: 8f 00 00 00  	sta	$0      ; sta g
       f: af 00 00 00  	lda	$0      ; lda g
      16: 8f 00 00 00  	sta	$0      ; sta corpus_result
  PASS: lda abs · sta abs · no ldx/ldy/stx/sty byte shuffle
SMOKE: PASS got=0x5A3D (MAME) · got=0x5A3D (bsnes-jg)
```
`-verify-machineinstrs` clean. **Two fixes during bring-up:** (1) a store of a
*constant* (`g16 = 0`) was wrongly taken native — it materialized the constant into
Imag16 instead of using the STZ-fusion peephole; gated out so constant stores stay
on the byte/STZ path. (2) The native store of computed values is a real improvement
(2 ops vs the 4-op X/Y byte shuffle) that merged trailing `corpus_result = X` stores
into the preceding bracket, eliminating the closing `sep` (main never returns) —
this changed the rep/sep shape of 11 existing tests; all were **emulator-verified
still correct** (a throwaway emulator-only pass confirmed every `corpus_result`)
before the now-stale exact-count disasm gates were relaxed to match the improved
codegen. Non-breaking: corpus 7/7, all 21 a16* tests green, patch `0002`
round-trips (2623 lines).

## Original plan

**Date:** 2026-06-15 · **Status:** planning

## Context

Memory-access follow-up to the indirect `(zp)` slice. A plain 16-bit **absolute**
load/store of a global still does a 4-op 8-bit X/Y byte shuffle with **no** rep/sep:
```
g = gg;  ->  ldx gg; ldy gg+1; stx g; sty g+1
```
Native (this increment): one 16-bit absolute load + store under one rep/sep:
```
g = gg;  ->  rep #$20; lda gg; sta g; sep #$20
```
This is extremely common (any 16-bit global assignment, `volatile` mirror writes,
struct-field copies). The `LDAbs16`/`STAbs16` `MLow=1` forms already exist (used by
the load-fold's `selectAlu16Abs`); only a plain-copy path is missing.

The other memory follow-up — indexed `abs,x` — is **dropped**: llvm-mos is now fully
pointer-based (even array-sum loops emit native `lda (zp)` via the indirect slice),
so the `abs,x` byte-pair form is no longer generated.

## Design — route s16 absolute load/store native (mirror the indirect slice)

### 1. New generic pseudos — `MOSInstrGISel.td`
`G_LOAD16_ABS` (outs s16 dst; ins abs addr; mayLoad) and `G_STORE16_ABS` (ins s16
val, abs addr; mayStore), `Predicates = [HasAccum16]`, mirroring the 8-bit
`G_LOAD_ABS`/`G_STORE_ABS`.

### 2. Legalizer — `legalizeLoadStore16` (extend the existing s16 routing)
Currently `legalizeLoadStore16` narrows the absolute case and only routes the
indirect case native. Restructure: for `hasAccum16() && pointer-width == 16`,
- if `matchAbsoluteAddressing(MRI, Ptr)` succeeds → emit `G_LOAD16_ABS`/
  `G_STORE16_ABS` with that operand (GA/Imm/FI), one memref;
- else (runtime pointer) → the existing `G_LOAD16_INDIR`/`G_STORE16_INDIR`;
- else narrow (zp-pointer / far / non-a16).
`LDA_Absolute` is 6502-base (no 65C02 needed); `hasAccum16 ⇒ w65816` covers it.

### 3. Selector — `selectMem16Abs` (`MOSInstructionSelector.cpp`)
Mirror `selectMem16Indir` / `selectAlu16Abs`:
- `G_LOAD16_ABS` → `LDAbs16 .addDef(A16).add(absOp).addMemOperand(ld)` +
  `STAImag16 .addDef(dst).addUse(A16)`.
- `G_STORE16_ABS` → `LDAImag16 .addDef(A16).addUse(val)` +
  `STAbs16 .addUse(A16).add(absOp).addMemOperand(st)`.
The user memref rides the real absolute op (`LDAbs16`/`STAbs16`); the Imag16
transfer carries none. All `MLow=1` → one rep/sep; no Ac16↔8-bit COPY. Dispatch
`G_LOAD16_ABS`/`G_STORE16_ABS` to `selectMem16Abs` beside the `_INDIR` cases.

## Test — `examples/65816/a16abs.c` + `dev/a16abs.sh`
```c
volatile unsigned short gg = 0x5A3C;
volatile unsigned short g;
volatile unsigned short corpus_result;
int main(void) {
  g = gg;                  // native 16-bit absolute load + store
  corpus_result = g + 1;   // 0x5A3D  (proves the full 16 bits copied)
  for (;;) {}
}
```
Result **0x5A3D**. Disasm gate: `lda abs` (AD) + `sta abs` (8D) under rep/sep, and
**no** `ldx/ldy/stx/sty` byte shuffle of `gg`→`g`; MAME + bsnes-jg assert 0x5A3D.
Wire `a16abs` into `dev/run.sh`.

## Verification
1. Build clean; `-verify-machineinstrs` clean on a16abs.
2. `dev/run.sh a16abs` → one rep/sep with `lda gg`/`sta g` (16-bit abs), no byte
   shuffle; corpus_result == 0x5A3D on MAME + bsnes-jg.
3. Non-breaking: corpus 7/7 + all 20 a16* + a16abs green.
4. `dev/regen-patch.sh` → 0002 round-trips.

## Land
Regen patch 0002; ROADMAP + TODO (Done; drop indexed-abs,x from follow-ups — no
longer generated); fill evidence; commit on `main` with Co-Authored-By; push.

## Critical files
- `vendor/.../MOSInstrGISel.td` — `G_LOAD16_ABS`/`G_STORE16_ABS`.
- `vendor/.../MOSLegalizerInfo.cpp` — absolute branch in `legalizeLoadStore16`.
- `vendor/.../MOSInstructionSelector.cpp` — `selectMem16Abs` + dispatch.
- `examples/65816/a16abs.c`, `dev/a16abs.sh` (new); `dev/run.sh` (wire-in).
- `patches/llvm-mos/0002-321-accum16.patch`; `docs/ROADMAP.md`; `TODO.md`; this plan.
