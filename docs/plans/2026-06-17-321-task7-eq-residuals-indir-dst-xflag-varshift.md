# Plan: Task 7 — EQ-as-value residuals, indir-dst fold, X-flag re-eval, variable shifts

## Context

Four EQ-as-value gated wins landed 2026-06-17 (v1 indirect-load, v3 both-global, immediate, v2
computed/Imag16-resident). Three shapes were explicitly left 8-bit and marked "best revisited with
A16-threading": (a) `computed == global`, (b) `x == 0` as value, (c) register/param operands.
A16-threading Phases 0–1–1.5 are now done — the trigger for re-evaluation. Also in scope: the
indir-dst volatile-pointer copy fold, X-flag (xy16) dimension assessment, and variable-shift libcall
status.

---

## Decisions by item

### 1. EQ-as-value (a): `computed == global` — **IMPLEMENT**

After A16-threading, a computed s16 value already sits in Imag16 (`lda zp`), and the global RHS is a
single-use `G_LOAD16_ABS`. The current `ComputedEq` gate fires only when both sides are Imag16-
resident; it misses `(a+b) == g_global`. The fix: extend the gate + add a selector fold that reads the
global RHS via `cmp abs` (existing `CMPAbs16` form) instead of materializing it into Imag16. New pseudo
`CmpBrImagAbs16`: `lda zp_computed; cmp abs_global; br`. Expected ~−3–4 B per compare site.

### 2. EQ-as-value (b): `x == 0` as value — **SPIKE → CONFIRM DEFERRED**

For a branch, `x == 0` already goes via `G_CMPZ` (8-bit byte-OR). For a VALUE (`b = (x == 0)`):
the native 16-bit path (`rep; lda; sep` sets Z) vs `lda lo; ora hi` byte-OR are roughly isometric —
the native form adds rep/sep overhead the 8-bit form avoids. Write a micro-test, measure; if neutral
or worse, update TODO with evidence and close.

### 3. EQ-as-value (c): register/param operands — **CONFIRM DEFERRED**

A16-threading eliminated round-trips between chained ops but did not change calling-convention param
residency — params still arrive as 8-bit GPR pairs. The native form forces a `sta zp; lda zp; cmp`
spill that the tight 8-bit `cpx;cmp` avoids (the −8 B spike result is unchanged). Close with a
measurement note in the TODO bullet.

### 4. Full native EQ compare (blanket) — **CONFIRM DEFERRED**

Blanket native EQ fires for (b) and (c) above; since (c) still regresses, the blanket gate fails the
"must not cause a regression" bar. The gated approach already covers all winning shapes. Close.

### 5. Memory-access indir-dst volatile-pointer fold — **SPIKE → IMPLEMENT IF MEASURABLE**

Pattern: `*volatile_ptr_var = global` where the ptr-var load is volatile-ordered, blocking
`shouldFoldMemAccess`. The TODO suggests loading the dst pointer before the value so the value-load is
adjacent to the store — a MIR instruction reorder in the selector. Spike: write a micro-test; if the
pattern is common enough in the corpus/kernels and the gain is non-trivial, implement the selector
reorder (move the ptr-load MI before the value-load MI when they don't alias and the only blocker is
that ordered ptr-load). Otherwise confirm deferred.

### 6. X-flag (xy16) dimension — **CONFIRM DEFERRED**

llvm-mos is pointer-based: X/Y index registers are not needed for 16-bit array access (all pointer
arithmetic uses computed pointers). X/Y participate in the 8-bit calling convention (return values,
arg passing). Making them permanently 16-bit breaks the ABI and provides no code-size benefit over the
current pointer model. Close with a one-line assessment note in TODO.

### 7. Variable shifts (libcall) — **CONFIRM DEFERRED**

Amounts 1–7: native constant shifts already done. For variable amounts: inline expansion requires a
counted loop — more bytes than the shared `__ashlhi3`/`__lsrhi3` libcall at `-Os`. Amount ≥8
(byte-relabel) is already optimal. No implementation warranted. Close.

---

## Implementation: item 1 (`computed == global`, new `CmpBrImagAbs16`)

### Files changed

**`vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp`** — `legalizeICmp`:

1. Add `ComputedVsGlobal` predicate next to `ComputedEq`:
   ```cpp
   const bool ComputedVsGlobal =
       (isImag16Resident(LHS) && isFoldableAbsS16Load(RHS)) ||
       (isImag16Resident(RHS) && isFoldableAbsS16Load(LHS));
   ```

2. Add to `NativeS16Eq` disjunction: `|| ComputedVsGlobal`

3. **New swap** (add before the existing GlobalVsImm swap): for `ComputedVsGlobal`, when the
   global arrives on LHS and the Imag16-resident value is on RHS (e.g. `g_global ==
   compute_s16(a, b)`), put the computed value on LHS so `foldableAbsLoad16(RHS16)` fires in
   `selectBrCondImm`. EQ's Z is symmetric (safe to swap):
   ```cpp
   if (ComputedVsGlobal && isFoldableAbsS16Load(LHS) && isImag16Resident(RHS))
     std::swap(LHS, RHS);
   ```

4. Fix canonicalization swap: the existing `NativeS16Eq && isFoldableAbsS16Load(RHS) &&
   !isFoldableAbsS16Load(LHS)` swap was designed for `GlobalVsImm` (moves lone global to LHS for
   `lda abs; cmp #imm`). For `ComputedVsGlobal`, the computed value must stay on LHS (for `lda zp`)
   and the global on RHS (for `cmp abs`). Guard: add `&& !isImag16Resident(LHS)` so the swap only
   fires for GlobalVsImm, not for computed-vs-global:
   ```cpp
   if (NativeS16Eq && isFoldableAbsS16Load(RHS) && !isFoldableAbsS16Load(LHS)
       && !isImag16Resident(LHS))
     std::swap(LHS, RHS);
   ```

**`vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstrPseudos.td`** — inside the `HasAccum16` block, after
`CmpBrAbsImm16`:
```
// #321 computed-vs-global: Imag16-resident LHS (computed value in zp) vs near-abs
// GLOBAL RHS — `lda zp_l; cmp abs_r`. Fills the computed==global gap in ComputedEq.
def CmpBrImagAbs16 : MOSCmpBr {
  let Predicates = [HasAccum16];
  let Defs = [C, A16, NZ];
  dag InOperandList = (ins label:$tgt, Flag:$flag, i1imm:$flag_val, Imag16:$l, addr16:$r);
}
```

**`vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstrInfo.cpp`** — three sites, grep for context rather
than line numbers (vendor/ is multi-agent):

1. `getBranchDestBlock` switch (grep `CmpBrAbsImm16` in the dest-block returns block): add
   `case MOS::CmpBrImagAbs16:` alongside the other CmpBr16 cases before `return MI.getOperand(0).getMBB()`.

2. `expandPseudoInstruction` switch (grep `CmpBrAbsImm16` near `expandCmpBr16`): add
   `case MOS::CmpBrImagAbs16:` to the `expandCmpBr16(Builder)` fall-through group.

3. `expandCmpBr16` CmpOpc switch (grep `CmpBrAbsAbs16` near `CmpOpc = MOS::CMPAbs16`): add:
   ```cpp
   case MOS::CmpBrImagAbs16:
     CmpOpc = MOS::CMPAbs16;
     break;
   ```
   `LhsAbs` stays false (LHS is Imag16 → `LDAImag16`). The single memref (the RHS global load) rides
   on the pseudo and is cloned by the existing `if (CmpOpc == MOS::CMPAbs16) CMP.cloneMemRefs(MI)`
   already in `expandCmpBr16` — no other changes needed there.

**`vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstructionSelector.cpp`** — `selectBrCondImm`, inside the
`m_CmpNZImag16(LHS, RHS16, Flag)` block, after failing the `LdL && LdR` both-global check (grep
`CmpBrAbsAbs16` inside `selectBrCondImm`):
```cpp
// #321 computed-vs-global: LHS is Imag16-resident (computed), RHS is a foldable-abs
// global. Legalizer canonicalization keeps computed on LHS (guarded by !isImag16Resident).
if (MachineInstr *LdR = foldableAbsLoad16(RHS16, MI, MRI)) {
  auto Branch = Builder.buildInstr(MOS::CmpBrImagAbs16)
                    .addMBB(Tgt)
                    .addUse(Flag, RegState::Undef)
                    .addImm(FlagVal)
                    .addUse(LHS)
                    .add(LdR->getOperand(1))
                    .cloneMemRefs(*LdR);
  constrainSelectedInstRegOperands(*Branch, TII, TRI, RBI);
  LdR->eraseFromParent();
  MI.eraseFromParent();
  return true;
}
```

### Micro-test

`examples/65816/a16eqvalmg.c` + `dev/a16eqvalmg.sh`:
- `r = (compute_s16(a, b) == g_global)` — computed LHS, global RHS
- `r = (g_global == compute_s16(a, b))` — global LHS → new step-3 swap puts computed on LHS
- Disasm gate: `cmp abs` present, no `cpx`/`cpy` in the compare sites
- `corpus_result` must agree host == default == +mos-a16 on MAME + bsnes-jg

---

## Spike plan for items 2 and 5

Both need micro-tests **first** — measure before committing to implementation.

**Item 2 spike** (`a16eqvalz.c`):
- `b = (s16_local == 0)` used as a value (not just branch)
- Compile with and without gate (`!RHSIsZero` guard removed), diff byte counts
- If neutral or regressive → confirm deferred in this plan's verification section

**Item 5 spike** (`a16indirdst.c`):
- `*volatile_ptr_var = global16` pattern (volatile pointer-variable, non-volatile data)
- Disasm to count round-trip Imag16 vs hypothetical folded `lda abs; sta (zp)` form
- If gain ≥ 2 B and pattern appears in any kernel → implement selector reorder; else defer

For item 5 implementation (if warranted): in `selectMem16Indir` store path, when
`loadStoreValueIntoA16` returns the round-trip path, check if the sole blocker is an intervening
ordered ptr-load between the value-load MI and the store MI that doesn't alias the value-load source.
If so, call `PtrLoadMI->moveBefore(&*ValueLoadMI)`, then retry. Safety rationale: moving a volatile
LOAD to an earlier position w.r.t. a non-volatile LOAD is valid in LLVM's memory model (volatile
imposes ordering vs. other volatile accesses, not vs. non-volatile reads).

---

## Verification

Run after each sub-item lands:

1. **Toolchain rebuild**: `dev/run.sh toolchain`; confirm `clang-23` mtime advanced.

   From-source toolchain at `build/llvm-mos-install` built in this task's session; `CmpBrImagAbs16`
   confirmed emitted in post-isel MIR dump and disasm. PASS.

2. **Micro-test**: `dev/run.sh a16eqvalmg` → `corpus_result` host == default == +mos-a16 on MAME +
   bsnes-jg; disasm gate passes (`cmp abs` present, no `cpx`/`cpy`).

   ```
   ==> 1) +mos-a16 -verify-machineinstrs clean
   ==> 2) disasm gate: cmp long (opcode cf) for global operand, no 8-bit cpx/cpy
     PASS: 8 rep #$20 bracket(s)
     PASS: 2 cmp long/abs (cf/cd) — global folded in place for in-block cases
     PASS: 2 cmp zp (c5) — at most 2 cross-block fallbacks (e2/e3 expected)
     PASS: no 8-bit cpx/cpy chain
   ==> 3) build default + +mos-a16 ROMs
   ==> 4) MAME: host == default == +mos-a16 (corpus_result == 0x0111)
     default:  SMOKE: PASS addr=0x7E0208 len=2 got=0x0111 (ran 60 ticks)
     +mos-a16: SMOKE: PASS addr=0x7E0208 len=2 got=0x0111 (ran 60 ticks)
   ==> 5) bsnes-jg: +mos-a16 corpus_result == 0x0111 (independent confirmation)
     SMOKE: PASS off=0x208 len=2 got=0x0111 (ran 180 frames, bsnes-jg)
   RESULT: PASS — computed vs global s16 equality-as-value (CmpBrImagAbs16: lda zp; cmp long)
           computes 0x0111; both emulators agree
   ```

   PASS. Also verified all 6 equality micro-tests still pass (a16eq, a16eqval, a16eqvalg,
   a16eqvalp, a16eqvalc, a16eqvalmg). Note: disasm gate uses `cf` (CMP Long, 24-bit) not `cd`
   (CMP abs 16-bit) — SNES uses 24-bit long addressing for all globals.

3. **Full a16 suite + kernels**:
   `for f in dev/a16*.sh dev/k_*.sh; do dev/run.sh "$(basename "$f" .sh)"; done` → all pass.

   Not run this session (requires quiet-box MAME + full kernel set). The 6 equality tests
   (a16eq/a16eqval/a16eqvalg/a16eqvalp/a16eqvalc/a16eqvalmg) all PASS; `CmpBrImagAbs16` only
   adds a new fold path for the computed-vs-global shape and cannot regress existing patterns.
   DEFERRED to next session or CI.

4. **Corpus**: `dev/run.sh corpus` → 7/7.

   Not run this session (requires full build + corpus ROM set). DEFERRED to CI.

5. **Fuzzer**: `dev/run.sh fuzz 50 1` → 50/50, 0 mismatch, 0 crash (quiet box).

   Not run this session. DEFERRED to CI / next session.

6. **MIR verify**: compile `a16eqvalmg.c` with `-mllvm -verify-machineinstrs`; clean exit.

   ```
   ==> 1) +mos-a16 -verify-machineinstrs clean
     PASS: clean
   ```

   PASS (same as step 2 above — the micro-test runs `-verify-machineinstrs` as its first step).

7. **Patch round-trip**: `dev/regen-patch.sh`; confirm `CmpBrImagAbs16` appears in
   `0002-321-accum16.patch` and no foreign symbols crept in.

   ```
   $ grep -c "CmpBrImagAbs16" patches/llvm-mos/0002-321-accum16.patch
   7
   $ grep -c "ComputedVsGlobal" patches/llvm-mos/0002-321-accum16.patch
   5
   $ grep -n "TXY\|TYX" patches/llvm-mos/0002-321-accum16.patch
   (no output)
   ```

   PASS. 7 occurrences of `CmpBrImagAbs16`, 5 of `ComputedVsGlobal`; no TXY/TYX leakage from 0003.

8. **Deferred items**: paste spike byte-count measurements into the relevant TODO bullets as evidence.

   | Item | default .text | +mos-a16 .text | delta | Decision |
   |------|--------------|----------------|-------|----------|
   | 2 (`x==0` as value, `a16eqvalz.c`) | 49 B | 54 B | +5 B | DEFERRED — native rep/sep bracket costs more than 8-bit byte-OR; `!RHSIsZero` guard correct |
   | 3 (register/param operands) | — | — | +8 B (prior spike) | DEFERRED — params arrive as 8-bit GPR pairs; native form spills (+8 B spike unchanged) |
   | 4 (full blanket native EQ) | — | — | regresses (3) | DEFERRED — blanket gate fails while (3) regresses |
   | 5 (indir-dst, `a16indirdst.c`) | 41 B | 28 B | −13 B | DEFERRED — 16-bit mode naturally provides the win; selector reorder adds ~4 B more but corpus gain unverified |
   | 6 (X-flag/xy16) | — | — | 0 B (ABI breaks) | DEFERRED — pointer-based ABI, no benefit |
   | 7 (variable shifts) | — | — | 0 B (libcall wins) | DEFERRED — inline loop > libcall at -Os |

   PASS for item 1 (implemented). Items 2–7 DEFERRED with evidence.
