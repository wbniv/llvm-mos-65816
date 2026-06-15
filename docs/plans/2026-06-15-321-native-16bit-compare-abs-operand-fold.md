# #321 native s16 — fold near-abs global operands into the 16-bit compare (CMPAbs16)

Compare follow-up **(d)** from the M2 comparison list: an s16 unsigned-ordering
compare against a global (`a < gv`, `a >= gv`) currently materializes BOTH operands
into Imag16 zp pairs before comparing — `lda abs; sta tmp` ×2, then `lda tmp; cmp tmp`.
Read the globals directly via the absolute forms instead: `lda abs` (LHS) + `cmp abs`
(RHS), mirroring how `selectAlu16AbsLd` reads near-abs global operands directly.

## Background

`selectSbc16` (MOSInstructionSelector.cpp) lowers the un-narrowed s16 `G_SBC` that the
legalizer leaves for an unsigned-ordering compare (the C-flag / UGE path; signed
compares reach it after an `eor #$8000` on each operand). Today it emits:

```
LDAImag16 lhs            ; lhs already lowered to lda abs; sta tmp by selectMem16Abs
CMPImm16 #imm  | CMPImag16 rhs   ; rhs likewise lda abs; sta tmp, then cmp tmp
```

By selection time the operands feeding `G_SBC` are already `G_LOAD16_ABS @global`
pseudos (the legalizer's `legalizeLoadStore16` turns an s16 load of an absolute
address into `G_LOAD16_ABS`, operand 1 = the abs operand, one memref). Each such
load is single-use (a fresh load per compare block) and selects independently to
`lda abs; sta tmp(Imag16)` — a wasteful round-trip when the very next op only needs
it in A16 / as a compare operand.

`CMPAbs16` (`cmp abs`, MLow=1, `(outs Cc:$carry)` / `(ins Ac16:$l, addr16:$r)`) and
`LDAbs16` (`lda abs`, MLow=1, `(outs Ac16:$dst)` / `(ins addr16:$src)`) already exist
and are the exact forms `selectAlu16AbsLd` uses. This increment just routes the
compare operands into them.

Baseline disasm of `a16cmp.c` (per compare): `rep; lda abs; sta zp; lda abs; sta zp;
lda zp; cmp zp; sep; bcc/bcs` — six pre-branch ops. Target: `rep; lda abs; cmp abs;
sep; bcc/bcs` — two.

## Volatile safety

`shouldFoldMemAccess` refuses volatile loads, but it is the wrong gate here (and the
`a16loadfold` / `selectAlu16AbsLd` path already folds *volatile* near-abs globals into
`adc abs`). Folding a **single-use** `G_LOAD16_ABS` into `lda abs` / `cmp abs` is a
1-to-1 rewrite: exactly one read of the global still happens, in the same program
order. So the gate is: def is `G_LOAD16_ABS`, `hasOneNonDBGUse`, same basic block as
the compare (no cross-block fold, matching the existing same-BB rule).

## Implementation

`MOSInstructionSelector.cpp`:

1. Add a static helper `foldableAbsLoad16(R, User, MRI)` → returns the defining
   `G_LOAD16_ABS` MI iff `R`'s def is a single-use `G_LOAD16_ABS` in `User`'s block,
   else null.
2. In `selectSbc16`:
   - **LHS**: if `foldableAbsLoad16(L)`, emit `LDAbs16` (lda abs into A16) with the
     load's operand 1 + cloned memref; else `LDAImag16` (unchanged).
   - **RHS**: constant → `CMPImm16` (unchanged); else if `foldableAbsLoad16(R)`, emit
     `CMPAbs16` (cmp abs) with the load's operand 1 + cloned memref; else `CMPImag16`.
   - Erase any folded loads after constraining (they are single-use; the `G_SBC` was
     their only consumer — selection is bottom-up so the loads are not yet selected).
3. Update the `selectSbc16` doc comment (drop "RHS load-folding … is a follow-up").

Signed compares (`a16scmp`) feed `G_SBC` operands that are `G_XOR` results, not bare
`G_LOAD16_ABS`, so they never fold — they keep the `eor; lda zp; cmp zp` path. The
branch-fused equality `CmpBr*16` path is untouched (a possible `CmpBrAbs16` is a
separate follow-up).

## Test

`examples/65816/a16abscmp.c` + `dev/a16abscmp.sh` (cloned from `a16cmp.sh`): all-global
unsigned-ordering compares so every compare operand is a near-abs load; distinctive
`corpus_result` value. Disasm gate asserts `cmp abs` is present (opcode `cd`) and the
RHS is no longer materialized into an Imag16 pair before the compare (no `sta zp`
between the `lda abs` and the `cmp`). MAME + bsnes-jg both assert the value;
`-verify-machineinstrs` clean.

## Verification steps

1. `dev/run.sh a16abscmp` — new test green on both emulators; disasm shows `cmp abs`,
   no per-compare Imag16 round-trip.
2. `dev/run.sh a16cmp a16scmp a16eq` — the existing compare suite still green
   (ordering / signed / equality unaffected).
3. Full a16 suite (all 23 tests) + `dev/run.sh corpus` (7/7, proves the `+mos-a16`
   gate leaves default codegen untouched).
4. `-mllvm -verify-machineinstrs` clean on `a16abscmp` and `a16cmp`.
5. `dev/regen-patch.sh` round-trips (the tracked patch regenerates and re-applies
   cleanly).

## Verification evidence (2026-06-15)

1. `dev/run.sh a16abscmp`:

   ```
   PASS: 3 rep #$20 bracket(s) — 16-bit compares
   PASS: 5 cmp abs/long (RHS global read directly, one per compare)
   PASS: no cmp zp — RHS never materialized into an Imag16 pair
   PASS: no 8-bit cpx/cpy compare-chain (fully native 16-bit)
   SMOKE: PASS addr=0x7E020A len=2 got=0x4303 (ran 60 ticks)         # MAME
   SMOKE: PASS off=0x20A len=2 got=0x4303 (ran 180 frames, bsnes-jg) # bsnes-jg
   RESULT: PASS
   ```
   Disasm (per compare): `rep #$20; lda $0 (af); cmp $0 (cf); bcs …` — `lda abs; cmp abs`,
   no `sta`/`cmp zp` between. PASS.

2. `dev/run.sh a16cmp a16scmp a16eq` — all PASS (ordering / signed / equality unaffected).

3. Full a16 suite (23 tests) + `dev/run.sh corpus`:

   ```
   PASS a16 a16add a16sub a16bit a16imm a16chain a16local a16localx a16localsub
   a16localbit a16localimm a16loadfold a16cmp a16loop a16call a16shift a16ashift
   a16eq a16scmp a16abscmp a16ptr a16abs a16copy corpus     (FAIL: <none>)
   ```
   PASS.

4. `-mllvm -verify-machineinstrs` on a16cmp, a16abscmp, a16scmp, a16eq → all `rc=0`. PASS.

5. `dev/regen-patch.sh`: `RESULT: PASS — 0002 round-trips (reapplied MOS dir == live vendor)`.
   PASS.
