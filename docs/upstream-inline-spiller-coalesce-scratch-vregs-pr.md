# [CodeGen][MOS] Don't coalesce a stack access that carries scratch virtual registers

Greedy register allocation can crash on MOS in `SplitEditor::enterIntvAfter`
with `Assertion 'MI && "enterIntvAfter called with invalid index"'` — or, in a
build without assertions, a null dereference.

`InlineSpiller::coalesceStackAccess()` erases a load or store it recognises as a
redundant access of the slot being spilled. That is safe upstream, where
`foldMemoryOperand` never introduces virtual registers. It is not safe on MOS:
the spill and reload hooks need scratch registers and express them as extra
virtual defs, which `getVDefInterval()` gives live intervals so the allocator can
place them like any other virtual register. Erasing the instruction orphans such
a register — its only def is gone, but the allocator has already assigned it, and
that assignment stays in the interference matrix as a segment over a `SlotIndex`
that no longer has an instruction. The next live-range split reads that index
back as "last interference" and looks up its instruction, which is now null.

The sequence, all inside one greedy run over `constant_shift`:

```text
  rewr %bb.7  9428B:2  %910:anyi8 = COPY %911:anyi8          split inserts a COPY
  assigning %910 to $rc10

  Inline spilling Anyi8:%911
    folded:  9428r  %910:anyi8, early-clobber %981:imag16 = LDStk %stack.25, 0
  queuing new interval: %981 [9428e,9428d:0)                 the hook's scratch pointer
  assigning %981 to $rs5: RC10LSB [9428e,9428d:0) RC11LSB [9428e,9428d:0)

  Inline spilling Anyi8:%910
  Coalescing stack access: %910:anyi8, dead early-clobber %981:imag16 = LDStk %stack.25, 0

  ... later ...
  %bb.7 [528B;9440B), reg-out 1, enter after 9428d, interference overlaps uses.
      enterIntvAfter 9428d        -> getInstructionFromIndex(9428d) == nullptr
```

Decline to coalesce an access that defines a virtual register other than the one
being spilled. The redundant load or store stays and the normal
`spillAroundUses` path rewrites it — correct, just not free, and only on this
shape. This is the coalescing counterpart to the hoisting guard added for the
same invariant in "Reject spill hoists that need scratch virtual registers":
both say that an instruction a target hook decorated with scratch virtual
registers may not simply be dropped once allocation has started.

`coalesceStackAccess` is the only one of the four instruction-removal sites in
`InlineSpiller.cpp` that did no bookkeeping for extra virtual defs.
`foldMemoryOperand` moves them onto the surviving `FoldMI`; `hoistAllSpills` is
already guarded by the hoisting change above; and
`LiveRangeEdit::eliminateDeadDef` walks every operand, calling
`LIS.removeVRegDefAt` for each virtual def and erasing the register once its
interval empties. Only the coalescing path erased the instruction and left the
interval standing.

Un-assigning and deleting the orphaned registers at the erase site was
considered and rejected: `InlineSpiller` holds `VirtRegMap` but not
`LiveRegMatrix`, so it cannot unassign a register the allocator has already
placed, and removing the interval alone would leave dangling segments in the
matrix's `LiveIntervalUnion`.

The regression test is reduced with `llvm-reduce` from
`gcc.c-torture/execute/ashrdi-1.c` (`constant_shift`), which is where the crash
was found. It needs the 48-case switch to become a jump table and `mos65c02` or
`mosw65816` pressure; `mos6502` escapes by luck, not by design, so the test runs
the two CPUs that reproduce.

<!-- validation numbers: see docs/pr-preparations/2026-09-24/0040-validation.md -->

Assisted-by: Claude Code CLI using Claude Fable 5.1 (`claude-fable-5-1`, `high`
reasoning effort) for diagnosis, reduction, implementation, tests, and
validation.
