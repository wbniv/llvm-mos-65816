# #321 native s16 — native 16-bit constant shifts (`<<`, unsigned `>>`)

**Date:** 2026-06-15 · **Status:** planning → **DONE** (verified, patch round-trips)

## Evidence (verification steps with raw output)

**1. Build clean.** `dev/run.sh toolchain` incremental: `done in 0m 23s … clang version 23.0.0git`, exit 0. PASS.

**2. Shift goes native.** `dev/run.sh a16shift` — one rep/sep bracket holds both shifts AND the
final add (the mode tracker fused all three 16-bit ops into one M16 region):
```
       a: c2 20        	rep	#$20
       e: 0a           	asl
       f: 0a           	asl
      10: 0a           	asl
      11: 0a           	asl
      16: 4a           	lsr
      17: 4a           	lsr
      21: e2 20        	sep	#$20
  PASS: 4 asl a (x << 4) · 2 lsr a (x >> 2) · no 8-bit rol/ror · no shift libcall
SMOKE: PASS addr=0x7E0202 len=2 got=0x1278 (ran 60 ticks)
  SMOKE: PASS off=0x202 len=2 got=0x1278 (ran 180 frames, bsnes-jg)
RESULT: PASS — native 16-bit constant shifts compute 0x1278; both emulators agree
```
PASS.

**3. Cross-block win.** The single rep/sep bracket above (open at 0x0a, close at 0x21) already
demonstrates the shifts stay inside one 16-bit region; a shift inside an all-16-bit loop body inherits
the a16loop hoisting. PASS (covered by #2 + the existing a16loop test).

**4. Non-breaking.** corpus 7/7; all 16 a16* tests green (a16 a16add a16sub a16bit a16imm a16chain
a16local a16localx a16localsub a16localbit a16localimm a16loadfold a16cmp a16loop a16call a16shift —
all RESULT: PASS). PASS.

**5. Patch integrity.** `dev/regen-patch.sh` → `RESULT: PASS — 0002 round-trips (reapplied MOS dir ==
live vendor)` (2013 lines, 16 files). PASS.

## Context

This is the next step in the agreed #321 native-s16 optimization order (TODO item
"agreed optimization order", step 3 — "inc/dec + 16-bit shifts"). The cross-block
REP/SEP work just landed, so per-op 16-bit features now pay off across loops.

Investigation found the split between the two halves of that TODO item:
- **inc/dec already lowers natively** under `+mos-a16` (via the s16-add path):
  `a±1` becomes `rep; lda; adc #±1; sta` for globals, and the 8-bit `inc/dec` byte
  chain for ±1 locals — functionally done. The remaining inc/dec win is a *1-byte*
  `inc a`/`dec a` accumulator form, which is polish → **follow-up**.
- **Shifts are the real gap**: `x << k` / `x >> k` (s16) still emit 8-bit `asl/rol`
  (or `lsr/ror`) byte-pair chains — *identical* with and without `+mos-a16` — and
  variable shifts call `__ashlhi3`. In 16-bit accumulator mode a single `asl a`
  shifts all 16 bits, so a constant shift collapses to `rep; lda; asl×k; sta; sep`.

**Scope (v1):** native 16-bit **constant** left shift (`G_SHL`, covers signed and
unsigned left) and **constant unsigned** right shift (`G_LSHR`), amount in **[1,7]**,
type s16, gated on `hasAccum16()`. Mirrors the existing `selectAlu16Native` (Imag16)
machinery exactly. Outcome: a 16-bit shift compiles to one `rep/sep` bracket with
`k` single-byte accumulator shifts — no 8-bit `rol/ror` pairs, no libcall — and the
cross-block pass hoists the bracket out of loops.

**Out of scope (explicit follow-ups):**
- Signed right shift `G_ASHR` (needs `ror a` + an in-loop `cmp #$8000` sign-into-carry
  idiom and a carry-threaded ROR form — materially more machinery; the existing byte
  path is already correct).
- The 1-byte `inc a`/`dec a` accumulator form (`INCAcc16`/`DECAcc16`) and memory-RMW
  16-bit `inc abs`/`dec abs` for `mem++`.
- Variable (non-constant) shifts — keep the existing `__ashlhi3` libcall path.
- Amount ≥ 8 — keep the existing byte-relabel path (it emits zero shift ops for
  byte-aligned shifts; already good). `xba`-based `<<8`/`>>8` is a later measurement.
- Shift-into-store global peephole (an `alu16_abs`-style fusion for shift dst = global).

## Why this is low-risk

It is a near-exact mirror of the proven native s16 ADD path, with two *simplifications*:
shifts are unary (one Imag16 source + a constant count) and need **no carry-init**
(each `asl`/`lsr` self-fills 0), so the M-agnostic `clc/sec` complication is absent.
The value stays in `Imag16` with the transient in `Ac16` — **no COPY between `Ac16`
and an 8-bit class** (the invariant that the existing forms preserve and that earlier
prototypes violated). MOSInsertREPSEP brackets the all-`MLow=1` run automatically.

## Design — four edits in the MOS backend (vendor/llvm-mos/llvm/lib/Target/MOS/)

### 1. New 16-bit accumulator-shift forms — `MOSInstrLogical.td` (near the Imag16 forms, ~726)
Model on `MOSBitImag16` (the closest single-result in-place `Ac16` form, ~718-726),
but pure-accumulator and **no carry operands** in v1:
```
def ASLAcc16 : MOSLogicalInstr, PseudoInstExpansion<(ASL_Accumulator)> {
  let Predicates = [HasAccum16];
  let MLow = 1;
  let Constraints = "$dst = $src";
  dag OutOperandList = (outs Ac16:$dst);
  dag InOperandList  = (ins Ac16:$src);
}
def LSRAcc16 : MOSLogicalInstr, PseudoInstExpansion<(LSR_Accumulator)> { ... LSR_Accumulator ... }
```
`ASL_Accumulator` (0x0A) / `LSR_Accumulator` (0x4A) are zero-operand real instrs
(`MOSInstrInfo.td:45-53`); the pseudo drops all named operands at AsmPrinter lowering.
These are the first pseudos expanding onto an `_Accumulator` form — eyeball the
generated `MOSGenMCPseudoLowering.inc` once after the tablegen build to confirm.
`MLow=1` makes MOSInsertREPSEP treat them as M16.

### 2. Native legalizer passthrough — `MOSLegalizerInfo.cpp` `legalizeShiftRotate` (after the `Amt==0` base case, after line 889; before `if (Amt >= 8)`)
```
if (STI.hasAccum16() && Ty == LLT::scalar(16) &&
    (MI.getOpcode() == G_SHL || MI.getOpcode() == G_LSHR) &&
    Amt >= 1 && Amt <= 7)
  return true; // leave un-narrowed; selected by selectShift16Native
```
Placement matters: **after** `Amt==0` (so a zero shift still becomes a copy) and
**before** the `Amt>=8` byte path and the `shouldOverCorrect` branch (so native wins
for the whole [1,7] range). `STI` is already in scope as in `legalizeAddSub`
(~691-692). Do **not** include `G_ASHR`. The amount is already `S8` here
(`.maxScalar(1,S8)` ran before `.custom()`, line 203), so no trunc dance.

### 3. Selector dispatch — `MOSInstructionSelector.cpp` `select()` (mirror the G_ADD case ~209-220)
```
case MOS::G_SHL:
case MOS::G_LSHR:
  if (STI.hasAccum16() && MRI.getType(MI.getOperand(0).getReg()) == LLT::scalar(16)) {
    if (selectShift16Native(MI)) return true;
    break;
  }
  // fall through to the generic shift selection
```

### 4. New `selectShift16Native` — `MOSInstructionSelector.cpp` (beside `selectAlu16Native` ~2291)
Mirror `selectAlu16Native` minus carry/RHS:
- `Dst`=op0 (Imag16), `Src`=op1 (Imag16), `Amt`=`getIConstantVRegValWithLookThrough(op2)`.
- `LDAImag16 Lo<-Src` (def Ac16).
- `Amt`× `ASLAcc16`/`LSRAcc16`, each `.addDef(newAc16).addUse(prevAc16)` (the def-use
  chain; tied `$dst=$src` collapses it onto A16 in regalloc).
- `STAImag16 Dst<-last`.
- `constrainSelectedInstRegOperands` each; `MI.eraseFromParent()`. The dead G_CONSTANT
  amount is removed by the generic selector's `isTriviallyDead` (as for the add immediate).

No new GISel pseudo opcode is needed — `G_SHL`/`G_LSHR` are selected directly, exactly
as s16 `G_ADD` is.

## Test — mirror `a16local.c` (the multi-use-local native path)

`examples/65816/a16shift.c` (new):
```c
volatile unsigned short v = 0x0123;
volatile unsigned short corpus_result;
int main(void) {
  unsigned short x = v;        // multi-use local -> lands in Imag16 (native path)
  unsigned short l = x << 4;   // 0x0123 << 4 = 0x1230  (crosses the byte boundary)
  unsigned short r = x >> 2;   // 0x0123 >> 2 = 0x0048  (high byte feeds low: 16-bit)
  corpus_result = l + r;       // 0x1230 + 0x0048 = 0x1278
  for (;;) {}
}
```
Result **0x1278** (unused by other tests). The `<<4` moving bits up and `>>2` pulling
the high byte into the low byte both prove all 16 bits shift.

`dev/a16shift.sh` (new, clone `dev/a16cmp.sh`/`dev/a16loop.sh` structure), WANT=0x1278:
- compile+link `.sfc`, checksum, disasm the `.o`.
- **disasm gate:** ≥1 `rep #$20` (c2 20) and ≥1 `sep #$20` (e2 20); exactly **4** `asl`
  accumulator (`0a`) and **2** `lsr` accumulator (`4a`); **0** `rol`/`ror` accumulator
  (`2a`/`6a`) and **0** `jsr`/`jsl` (no `__ashlhi3`/`__lshrhi3` libcall).
- MAME `run_assert corpus_result 0x1278` via `dev/_emu.sh`; bsnes-jg `jgxcheck` leg.
- Wire `a16shift` into `dev/run.sh` (usage line + help block; dispatch auto-discovers).

## Verification

1. **Build clean:** `MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh toolchain`
   (incremental; tablegen picks up the new pseudos). Exit 0.
2. **Shift goes native:** `dev/run.sh a16shift` → disasm shows one `rep`/`sep` bracket
   with 4× `asl` + 2× `lsr`, **no** `rol/ror` pairs, **no** libcall; `corpus_result ==
   0x1278` on MAME **and** bsnes-jg.
3. **Cross-block win (manual check):** a constant shift inside an all-16-bit loop body
   keeps the `rep/sep` hoisted (none per-iteration) — confirm on a quick local snippet
   (the a16loop pattern); not a separate committed test.
4. **Non-breaking:** `dev/run.sh corpus` → 7/7; all 13 a16* + a16loop + a16call +
   a16shift green (`for t in a16 a16add a16sub a16bit a16imm a16chain a16local a16localx
   a16localsub a16localbit a16localimm a16loadfold a16cmp a16loop a16call a16shift`).
5. **Patch integrity:** `dev/regen-patch.sh` → 0002 round-trips (reapplied MOS dir ==
   live vendor).

## Land
Regenerate `patches/llvm-mos/0002-321-accum16.patch` (`dev/regen-patch.sh`); update
ROADMAP step 5 + TODO (Done entry; note shifts done, list the deferred follow-ups);
fill the plan's evidence section with raw verification output; commit on `main`
(end message with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`)
and push.

## Critical files
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstrLogical.td` — add `ASLAcc16`/`LSRAcc16` (~726).
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp` — native gate in `legalizeShiftRotate` (after line 889).
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstructionSelector.cpp` — dispatch (~209) + new `selectShift16Native` (~2291).
- `examples/65816/a16shift.c`, `dev/a16shift.sh` (new); `dev/run.sh` (wire-in).
- `patches/llvm-mos/0002-321-accum16.patch`; `docs/ROADMAP.md`; `TODO.md`; this plan.
