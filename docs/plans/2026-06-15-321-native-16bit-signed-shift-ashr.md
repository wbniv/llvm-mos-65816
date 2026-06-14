# #321 native s16 — native 16-bit signed right shift (arithmetic `>>`, ASHR)

**Date:** 2026-06-15 · **Status:** **DONE** (verified, patch round-trips)

## Evidence (raw output)

`dev/run.sh a16ashift` — `lda; (cmp #$8000; ror)×3; sta` in one rep/sep bracket:
```
       a: c2 20        	rep	#$20
       e: c9 00 80     	cmp	#$8000
      11: 6a           	ror
      12: c9 00 80     	cmp	#$8000
      15: 6a           	ror
      16: c9 00 80     	cmp	#$8000
      19: 6a           	ror
      1c: e2 20        	sep	#$20
  PASS: 3 cmp #$8000 · 3 ror a · no 8-bit lsr · no shift libcall
SMOKE: PASS addr=0x7E0202 len=2 got=0xFE01 (ran 60 ticks)
  SMOKE: PASS off=0x202 len=2 got=0xFE01 (ran 180 frames, bsnes-jg)
RESULT: PASS — native 16-bit signed >> (cmp #$8000; ror) sign-extends to 0xFE01
```
Non-breaking: corpus 7/7, all 17 a16* tests green. `dev/regen-patch.sh` → 0002
round-trips (2050 lines, 16 files).

## Original plan

**Date:** 2026-06-15 · **Status:** planning

## Context

Completes the native 16-bit constant-shift family. The previous increment landed
native `<<` (G_SHL) and unsigned `>>` (G_LSHR) — see
[constant-shifts plan](2026-06-15-321-native-16bit-constant-shifts.md). **Signed**
`>>` on `short` (G_ASHR) was explicitly deferred there and still narrows to the
8-bit byte-decomposition path (an `ICMP_SLT`-driven sign fill plus per-bit
`lsr/ror`), even under `+mos-a16`.

The 65816 has no native arithmetic-shift-right, but in 16-bit-accumulator mode the
per-bit idiom is two ops: `cmp #$8000` sets carry **C = (A ≥ 0x8000) = the sign
bit**, then `ror a` rotates that carry back into bit 15 while shifting right — so
the sign replicates. Repeating `cmp #$8000; ror a` k times is a correct k-bit
arithmetic right shift, all in one rep/sep bracket.

**Scope (v1):** native 16-bit **constant** arithmetic right shift (`G_ASHR`),
amount in **[1,7]**, type s16, gated on `hasAccum16()`. Reuses the
`selectShift16Native` dispatch and the Imag16 round-trip from the prior increment;
adds a carry-threaded `RORAcc16` form and a `CMPImm16 #$8000` sign probe per bit.

**Out of scope (follow-ups, unchanged from the shift plan):** variable shifts,
amount ≥ 8, the 1-byte `inc a`/`dec a` form, memory-RMW, shift-into-store fusion.

## Why low-risk

`cmp`/`ror` are both `MLow=1`, so the whole `lda; (cmp;ror)×k; sta` run is one
contiguous M16 region — MOSInsertREPSEP brackets it with one rep/sep, exactly like
the asl/lsr case. `CMPImm16` already exists (it's what `selectSbc16` uses for the
unsigned compare) and defs `Cc`; the value never leaves `Ac16` except via the
load/store (no Ac16↔8-bit COPY). The carry-out of each `ror` is dead (the next
iteration's `cmp` recomputes C), so no cross-iteration carry plumbing is needed.

## Design — three edits (vendor/llvm-mos/llvm/lib/Target/MOS/)

### 1. `MOSInstrLogical.td` — add `RORAcc16` beside `ASLAcc16`/`LSRAcc16` (~786)
A carry-threaded accumulator rotate (unlike ASL/LSR it has a real carry-in):
```
def RORAcc16 : MOSLogicalInstr, PseudoInstExpansion<(ROR_Accumulator)> {
  let Predicates = [HasAccum16];
  let MLow = 1;
  let Constraints = "$dst = $src";
  dag OutOperandList = (outs Ac16:$dst, Cc:$carryout);
  dag InOperandList  = (ins Ac16:$src, Cc:$carryin);
}
```
`ROR_Accumulator` (0x6A) is the zero-operand real instr; the pseudo drops the named
operands at lowering. `$carryout` is modeled (ror shifts bit 0 into C) but used dead.

### 2. `MOSLegalizerInfo.cpp` — extend the native shift gate in `legalizeShiftRotate`
Add `G_ASHR` to the existing `(G_SHL || G_LSHR)` native-passthrough condition (the
block added after the `Amt==0` base case):
```
(MI.getOpcode() == MOS::G_SHL || MI.getOpcode() == MOS::G_LSHR ||
 MI.getOpcode() == MOS::G_ASHR) && Amt >= 1 && Amt <= 7
```

### 3. `MOSInstructionSelector.cpp` — dispatch + `selectShift16Native` ASHR arm
- Add `case MOS::G_ASHR:` to the s16-shift dispatch (beside G_SHL/G_LSHR), routing
  to `selectShift16Native`.
- In `selectShift16Native`, branch on opcode:
  - G_SHL → k× `ASLAcc16` (existing).
  - G_LSHR → k× `LSRAcc16` (existing).
  - G_ASHR → k× { `CMPImm16` (def fresh Cc, use Cur, imm `0x8000`); `RORAcc16`
    (def Next Ac16, def dead Cc, use Cur, use the cmp's Cc) }, threading
    `Cur = Next`. The `cmp` reads the current accumulator and only sets flags; the
    `ror` consumes that carry and the accumulator.

The amount `G_CONSTANT` is dead after selection (erased by `isTriviallyDead`).

## Test — `examples/65816/a16ashift.c` + `dev/a16ashift.sh`

C (mirror a16shift; a NEGATIVE value proves arithmetic vs logical):
```c
volatile short sv = -4096;            // 0xF000
volatile unsigned short corpus_result;
int main(void) {
  short x = sv;                       // multi-use local -> Imag16
  short r = x >> 3;                   // arithmetic: 0xF000 >> 3 = 0xFE00 (-512)
  corpus_result = (unsigned short)r + 1;  // 0xFE01 (distinct value)
  for (;;) {}
}
```
Result **0xFE01** (a logical `>>3` would give 0x1E00→0x1E01, so 0xFE01 proves the
sign extended). `+1` keeps the value distinct from any existing test.

`dev/a16ashift.sh` (clone a16shift.sh), WANT=0xFE01:
- disasm gate: ≥1 `rep`/`sep`; exactly **3** `ror` accumulator (`6a`) and **3**
  `cmp #$8000` (`c9 00 80`); **0** `lsr`/`asl` accumulator (`4a`/`0a`); **0**
  shift libcall (`jsr`/`jsl`).
- MAME + bsnes-jg assert corpus_result == 0xFE01.
- wire `a16ashift` into `dev/run.sh`.

## Verification
1. Build clean (`dev/run.sh toolchain`).
2. `dev/run.sh a16ashift` → disasm shows `lda; (cmp #$8000; ror)×3; sta` in one
   rep/sep, no asl/lsr, no libcall; corpus_result == 0xFE01 on MAME + bsnes-jg.
3. Non-breaking: corpus 7/7 + all 16 a16* + a16ashift green.
4. `dev/regen-patch.sh` → 0002 round-trips.

## Land
Regen patch 0002; update ROADMAP step 5 + TODO (Done; strike signed `>>` from the
shift follow-ups); fill this plan's evidence; commit on `main` with Co-Authored-By;
push.

## Critical files
- `vendor/.../MOSInstrLogical.td` — `RORAcc16` (~788).
- `vendor/.../MOSLegalizerInfo.cpp` — add G_ASHR to the native shift gate.
- `vendor/.../MOSInstructionSelector.cpp` — dispatch G_ASHR + ASHR arm in `selectShift16Native`.
- `examples/65816/a16ashift.c`, `dev/a16ashift.sh` (new); `dev/run.sh` (wire-in).
- `patches/llvm-mos/0002-321-accum16.patch`; `docs/ROADMAP.md`; `TODO.md`; this plan.
