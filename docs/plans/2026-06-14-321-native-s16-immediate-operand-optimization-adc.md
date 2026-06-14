# #321 native s16 — immediate-operand optimization (`adc #imm` instead of materializing the constant)

**Status: DONE (2026-06-14).** `selectAlu16Native` folds a constant operand into the `*Imm16` form;
`a16localimm.c` confirms `adc #$0345` (no materialization, opcode `69` not `65`) and `0x1545` on both
MAME and bsnes-jg. Step-0 finding: the constant arrives as `G_MERGE_VALUES(G_CONSTANT 0x45,
G_CONSTANT 0x03)`, so `getImm16Operand` reconstructs `lo|hi<<8`. Non-breaking: corpus 7/7, all 11 a16*
tests green; patch `0002` round-trips. Verification evidence is in the §Verification section below.

## Context

The 1d-retry increment (commits `88994fb`, `e9b2221`) made the basic 16-bit ALU (add/sub/and/or/xor)
native for locals/multi-use values: the s16 value lives in an `Imag16` zero-page pair and
`selectAlu16Native` (MOSInstructionSelector.cpp:2126) emits `lda zp; clc; <op> zp; sta zp` on the
transient `A16`.

When one operand is a **compile-time constant** (e.g. `t = a + 0x0345`, multi-use local so the 1b
combiner can't fold it), the current native path treats it like any other operand: the constant is
materialized into an `Imag16` pair (`ldx #69; stx __rc2; ldx #3; stx __rc3`) and the op reads it from
zero page (`adc __rc2`). That's **correct but wasteful** — ~4 extra instructions per immediate op.

The 65816 has dedicated 16-bit-immediate ALU forms, and the backend already defines pseudos for them
(`ADCImm16`/`ANDImm16`/`ORAImm16`/`EORImm16`, MOSInstrLogical.td:649-667, `MLow=1`, gated `HasAccum16`,
proven by the passing `a16imm` peephole test). This change teaches `selectAlu16Native` to **fold a
constant operand into the immediate form** — `clc; lda a; adc #$0345; sta dst` — dropping the
materialization. Outcome: smaller, faster native 16-bit code for the very common `var OP constant`
shape.

## Approach (recommended)

Single-function change in the selector, plus a regression test. No legalizer/tablegen changes (the
`*Imm16` ops already exist).

### Step 0 — confirm the constant's MIR form (empirical, first)

The existing materialized asm (`ldx #69 … ldx #3`) suggests the s16 constant may reach the selector as
a **`G_MERGE_VALUES` of two byte-constants** rather than a single `G_CONSTANT`. `getIConstantVRegVal-
WithLookThrough` looks through COPY/extends but **not** `G_MERGE_VALUES`, so the detector must handle
whichever form appears. Confirm by dumping post-legalizer MIR (re-add `examples/65816/a16localimm.c`
first, see Step 2):

```
mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -mllvm -stop-after=legalizer -S -o - a16localimm.c
```

Look at how the `0x0345` operand of the `G_ADD` is expressed.

### Step 1 — `selectAlu16Native` immediate fold (MOSInstructionSelector.cpp:2126)

Add a small local helper `getImm16Operand(Register, MRI) -> std::optional<int64_t>` that returns a
16-bit constant if the operand is one, handling **both** forms found in Step 0:
- direct constant: `getIConstantVRegValWithLookThrough(R, MRI)` → `Value.getZExtValue() & 0xFFFF`;
- byte-merge: if `getDefIgnoringCopies(R)` is `G_MERGE_VALUES` with two constant byte operands,
  reconstruct `lo | (hi << 8)` (reuse the same constant-lookup on each byte, mirroring the
  `LoConst && HiConst` path in `selectMergeValues`, MOSInstructionSelector.cpp).

Extend the opcode switch to also carry the **immediate opcode** and a **commutative** flag:

| generic | reg op (have) | imm op (add) | carry | commutative |
|---|---|---|---|---|
| G_ADD | ADCImag16 | ADCImm16 | clc (0) | yes |
| G_SUB | SBCImag16 | *(none)* | sec (1) | no |
| G_AND | ANDImag16 | ANDImm16 | none | yes |
| G_OR  | ORAImag16 | ORAImm16 | none | yes |
| G_XOR | EORImag16 | EORImm16 | none | yes |

Fold logic (only when an immediate opcode exists, i.e. **not** G_SUB):
- if `B` is a constant → `imm = B`, keep `A` as the loaded register;
- else if commutative and `A` is a constant → `std::swap(A, B)` so `A` (now the old `B`) is the loaded
  register and `imm` = old `A`;
- emit `LDAImag16 Lo, A`; the carry-init (for ADD); then the **imm** form
  (`ADCImm16`/`ANDImm16`/… `.addImm(imm)`) instead of the `*Imag16` reg form; then `STAImag16 Dst, Res`.

The now-unused `G_CONSTANT`/`G_MERGE` def is removed automatically by `isTriviallyDead` in
`InstructionSelect::selectInstr` (InstructionSelect.cpp:356) — **no manual erase**. Keep the existing
register-operand path unchanged as the fallthrough.

**SUB is intentionally untouched:** there is no `SBCImm16`, and `x - C` is canonicalized to `x + (-C)`
by the upstream middle-end before GISel, so a native `G_SUB` never carries a foldable constant
(only `x - y` register, or the rare `C - x` whose minuend can't be an immediate anyway). The existing
materialize path handles those correctly.

Update the `selectAlu16Native` header comment (currently says "Constant operands are already
materialized … so both operands are plain Imag16 vregs here") to describe the new immediate fold.

### Step 2 — regression test

Re-add `examples/65816/a16localimm.c` (a multi-use local so the combiner can't fold it):
```c
volatile unsigned short a16v = 0x1200;
volatile unsigned short g16, h16, corpus_result;
int main(void){
  unsigned short t = a16v + 0x0345;     // -> adc #$0345 ; 0x1545
  g16 = t; h16 = t; corpus_result = t;  // multi-use forces the native path
  for(;;){}
}
```
Add `dev/a16localimm.sh` (clone `dev/a16local.sh`): assert the disasm contains an **ADC-immediate**
(opcode `69`, i.e. `adc #$0345` — distinct from the pre-optimization `65` adc-zp) and **no constant
materialization**, then assert `corpus_result == 0x1545` on **both** MAME and bsnes-jg. The `69`-vs-`65`
distinction is the clean proof the immediate form was selected. Print the function byte size for the
visible size win. Wire `a16localimm` into `dev/run.sh` (top usage line + the help block, mirroring the
existing `a16local`/`a16localx` entries).

### Step 3 — regenerate the tracked patch + round-trip

Regenerate `patches/llvm-mos/0002-321-accum16.patch` via the isolated-worktree method (baseline =
pristine `vendor/llvm-mos` HEAD + `0001` committed, overlay current MOS dir, `git diff --cached`), then
verify round-trip: apply `0001` then `0002` to a fresh pristine worktree and `diff -rq` its
`llvm/lib/Target/MOS` against `vendor/llvm-mos/llvm/lib/Target/MOS` (must be identical).

### Step 4 — docs

- Plan `docs/plans/2026-06-14-321-increment-1d-retry-imag16-native-s16.md`: move the immediate
  optimization from "Remaining (future)" to a done sub-step with evidence.
- `docs/ROADMAP.md` step 5 note + `TODO.md` "deferred optimizations" item: mark the `adc #imm` fold done.

## Out of scope

- `SBCImm16` / native sub-immediate (no immediate SBC pseudo; sub-by-constant is canonicalized to add
  upstream, so it's already covered by the ADD fold — adding it would be dead code).
- Loops + cross-block REP/SEP mode-tracking; the 16-bit calling convention/ABI (separate frontier).

## Critical files

- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstructionSelector.cpp` — `selectAlu16Native` (:2126); the
  `*Imm16` opcodes are referenced from MOSInstrLogical.td:649-667. Template for the constant detection:
  `selectAddE` (:1774) and `selectMergeValues`' `LoConst && HiConst` path.
- `examples/65816/a16localimm.c` (new), `dev/a16localimm.sh` (new), `dev/run.sh` (usage).
- `patches/llvm-mos/0002-321-accum16.patch` (regenerated).
- Docs: the 1d-retry plan, `docs/ROADMAP.md`, `TODO.md`.

## Verification

1. **Build:** `dev/run.sh toolchain` clean (incremental; only the selector `.cpp` changed — no tablegen).
2. **The optimization fires:** `dev/run.sh a16localimm` → disasm shows `adc #$0345` (opcode `69`), no
   `__rc` materialization of the constant, `corpus_result == 0x1545` on MAME **and** bsnes-jg; function
   is smaller than the pre-optimization version.
3. **Non-breaking guard:** `dev/run.sh corpus` → 7/7; all native + peephole tests green:
   `a16 a16add a16sub a16bit a16imm a16chain a16local a16localx a16localsub a16localbit` (+ the new
   `a16localimm`). Bitwise-immediate path (`ANDImm16` etc.) shares the code; `a16localimm` covers ADD,
   and the existing `a16imm`/`a16bit` peephole tests still exercise the imm/bitwise opcodes.
4. **Patch integrity:** `0002` round-trips (applies on `0001`, reproduces vendor MOS dir exactly).
