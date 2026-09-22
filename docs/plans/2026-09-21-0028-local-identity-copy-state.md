# Patch 0028: keep identity-copy preservation state local

Status: implemented and validated, 2026-09-21. The PR remains unposted.

## Publication hold and implementation choice — 2026-09-22

**User decision:** defer publishing 0028 until we are ready to open the #320/#321
series. This is a presentation/timing dependency; the constructed stock-MOS MIR
test itself does not depend on those compiler features.

Keep both implementations available. The earlier
[boolean-parameter patch](../pr-preparations/2026-09-21/0028-boolean-parameter.patch)
is preserved verbatim from the comparison baseline. The
[refactored patch](../pr-preparations/2026-09-21/0028-upstream.patch) remains the
current implementation and the version displayed in the simulation.

| Version | Change in `VirtRegMap.cpp` | Review tradeoff |
|---|---|---|
| Existing cleanup helper plus `bool HasUndefLanes` | +24 / -4 lines | Small, focused correctness fix; explicitly passes the pre-rewrite fact to post-rewrite cleanup |
| Per-instruction helper with local state | +160 / -139 lines | Keeps the transformation together; reviewers must also check extraction, moved code, and temporary-vector lifetimes |

These counts exclude tests. The earlier artifact has the original 20-line
regression; the refactored artifact also has the 103-line companion test. The
six companion cases already passed against the saved boolean-parameter compiler,
so there is no reason to sacrifice that coverage if we choose the smaller fix.
Prepare any eventual submission with the same tests and revalidate its exact
patch/base combination.

**Recommendation, not a final selection:** lead with the smaller correctness
patch when the publication hold is lifted. The boolean expresses a concrete
two-phase dependency and is reasonable here. Keep the refactor as an optional
follow-up or alternative for maintainers, with its validation available; offer
one clear primary patch rather than two competing PRs. If both changes are
requested, separate the fix and structural cleanup into reviewable commits.

The user has not selected which implementation to submit. No compiler change or
switch back to the smaller version is made by this documentation update.

## Completion record

- Added `rewriteInstruction(MachineInstr &MI)` and removed `handleIdentityCopy`.
  The undef-lane predicate is local to the instruction transformation.
- Rebuilt current upstream `742d554bf080`: the reproducer fails without the fix;
  the patched MOS CodeGen suite passes 85 tests, with one explicitly unsupported.
- Added six companion copy-contract cases, including bundle ordering and source
  subregister behavior. Their baseline/refactored MIR outputs match exactly.
- Rebuilt and installed the downstream compiler: the normal verifier gate passes
  34 configurations. A separate 24-input comparison produces identical
  post-rewrite MIR and assembly against the boolean-parameter version.
- Timing checks did not show a consistent slowdown; the optimized compiler
  inlines the helper. Exact measurements and limits are in the validation record.
- Generated separate current-upstream and pinned-vendor patch artifacts because
  their existing `readsUndefSubreg` call signatures differ. The refactor preserves
  each base's API. Both patches round-trip to the tested source.
- Refreshed the PR description and simulation. ARM/AArch64/AMDGPU and deferred
  allocation were not execution-tested; those targets are absent from these builds.

[Validation record](../pr-preparations/2026-09-21/0028-validation.md) ·
[upstream patch](../pr-preparations/2026-09-21/0028-upstream.patch) ·
[PR simulation](../pr-preparations/2026-09-21/0028-pr-preview.html).

## Recommendation

Introduce `VirtRegRewriter::rewriteInstruction(MachineInstr &MI)` to own the
complete rewrite of one instruction, including identity-copy cleanup. Move the
existing single-call-site `handleIdentityCopy` implementation into its tail and
remove that separate helper. Keep `CopyHasUndefLanes` local to the new helper.

This removes the proposed `bool HasUndefLanes` parameter without introducing
shared mutable state or encoding a cleanup decision in machine operands. The
information still exists, but its lifetime and owner match the operation that
needs it.

This is a structural alternative, not a different undef-lane algorithm. The
current boolean-parameter patch is straightforward and is not incorrect merely
because it has that parameter. The tradeoff is a larger source rearrangement in
exchange for a self-contained per-instruction operation.

## Why the information crosses two phases

The source virtual register, its subregister index, and its live subranges are
available before rewriting. The identity-copy decision uses the physical
registers after rewriting. Once `MO.setReg(PhysReg)` and `MO.setSubReg(0)` have
run, the original source identity cannot be recovered reliably from `MI`:
multiple virtual registers may have the same physical assignment.

The intended contract is:

1. Record whether the copied source lanes include a lane without a live subrange
   at the instruction, while virtual-register information is available.
2. Rewrite operands and preserve the existing implicit def/kill handling.
3. Expand copy bundles at the existing point.
4. If the resulting instruction is a physical identity copy, retain its
   destination definition as a zero-code `KILL` when required; otherwise remove
   the redundant copy using the existing index and bundle bookkeeping.

These phases belong to one instruction transformation. A local variable can
carry the fact between them without enlarging a helper's interface.

## Proposed structure

Illustrative structure only; retain the exact existing guards, debug output,
statistics, and bookkeeping when implementing it:

```cpp
void VirtRegRewriter::rewriteInstruction(MachineInstr &MI) {
  SmallVector<Register, 8> SuperDeads;
  SmallVector<Register, 8> SuperDefs;
  SmallVector<Register, 8> SuperKills;

  bool CopyHasUndefLanes = false;
  // Compute this from the virtual COPY source and live subranges.

  // Rewrite operands and append the required implicit defs and kills.
  expandCopyBundle(MI);

  if (!MI.isIdentityCopy())
    return;

  // Preserve the identity-copy statistics and deferred-allocation guard.
  // Record the physical destination in RewriteRegs.

  if (CopyHasUndefLanes || MI.getOperand(1).isUndef() ||
      MI.getNumOperands() > 2) {
    MI.setDesc(TII->get(TargetOpcode::KILL));
    return;
  }

  if (Indexes)
    Indexes->removeSingleMachineInstrFromMaps(MI);
  MI.eraseFromBundle();
}
```

`rewrite()` retains block traversal, the block-level debug dump,
`make_early_inc_range`, final physical-register live-range invalidation, and
`RewriteRegs.clear()`. Its inner loop calls `rewriteInstruction(MI)` and must
not access `MI` afterward, because the helper may erase it.

## Implementation steps

1. Work in an isolated compiler checkout at a recorded upstream revision. Save
   the current patch and its regression as the comparison baseline.
2. Extract the per-instruction operand rewrite, temporary vectors, implicit
   operand handling, debug output, and bundle expansion into
   `rewriteInstruction`. Fold the original identity-copy cleanup into its tail.
   First review this extraction independently of the undef-lane change.
3. Place patch 0028's lane detection at the beginning of that helper and extend
   the local preservation condition. Keep its current `LIS`, interval,
   subrange, and source-subregister guards. Do not broaden
   `readsUndefSubreg`, change slot-index semantics, or redesign lane detection
   in this refactor.
4. Preserve `NumIdCopies` placement, the virtual-destination early return for
   deferred allocation, `RewriteRegs` updates, `Indexes` removal, and
   `eraseFromBundle`. Keep bundle expansion before identity cleanup.
5. Remove the `handleIdentityCopy` declaration and definition. Avoid a new
   per-instruction class member, overload, or context object solely to transport
   this fact.
6. After validation, regenerate the carried
   [0028 patch](../../patches/llvm-mos/0028-llvm-virtregrewriter-undef-lane-identity-copy.patch),
   update the [PR description](../upstream-virtregrewriter-undef-lane-identity-copy-pr.md),
   and refresh the [browser preview](../pr-preparations/2026-09-21/0028-pr-preview.html).
   Keep publication separate from this implementation work.

## Alternatives considered

- **Compute the predicate inside the existing post-rewrite helper:** the source
  virtual-register identity and lane coordinates have already been overwritten.
  Passing a saved register/subregister context would replace the boolean with
  a more complicated interface.
- **Mark the full source operand `undef`:** a partly undefined source may still
  contain live, meaningful lanes. The flag says the operand does not read its
  previous value; applying it to the whole operand would discard valid uses.
- **Append an implicit definition to force the existing operand-count branch:**
  this introduces redundant MIR operands solely to steer cleanup. In particular,
  `addRegisterDefined` can suppress such an operand when the explicit destination
  already defines that register or its covering super-register. Directly adding
  duplicate defs needs a separate semantic justification and more validation.
- **Store the predicate on `VirtRegRewriter`:** this hides an instruction-local
  dependency in mutable pass state and requires reset discipline.
- **Move identity cleanup before rewriting:** predicting the final operands
  duplicates subregister mapping and changes its ordering relative to implicit
  operands and copy-bundle expansion.
- **Inline cleanup directly in `rewrite()`:** mechanically smaller and viable,
  but makes an already long traversal method larger. Use this only if the
  per-instruction extraction proves disproportionately disruptive in review.

## Validation and acceptance

The checks below define the acceptance criteria. Executed checks, results, and
coverage limits are recorded in the completion record above and its linked report.

- Preserve the stock-MOS regression: it must fail on the unpatched base and
  pass with the refactor plus fix. Check the retained
  `$rs1 = KILL $rs1` and subsequent low/high byte extracts under
  `-verify-machineinstrs`.
- Compare post-rewrite MIR from the boolean-parameter patch and the refactored
  patch on the reproducer and selected existing tests. The refactor should
  preserve their behavior and register flags.
- Cover defined-lane identity-copy removal, non-identity copies with partial
  undef sources, explicit-undef copies, and copies with implicit definitions.
  Reuse existing tests where they cover these contracts; add focused cases only
  for gaps.
- Exercise source subregisters, copy-bundle expansion, and deferred allocation
  through applicable existing target tests. The helper must not erase an
  instruction still needed for bundle scheduling or assume every virtual
  register has a physical assignment.
- Run the relevant MOS CodeGen suite and available generic rewriter/subregister
  tests on other targets, since `VirtRegMap.cpp` is shared code. Record unavailable
  targets or missing test tools rather than claiming full LLVM coverage.
- Re-run the recorded `rcundef2.c` and `newton_sim.c` verifier witnesses in the
  downstream native-width configurations.
- Inspect the cost of moving the inline-capacity temporary vectors into a
  per-instruction helper. Compare compile-time measurements on the same corpus
  if code generation or profiling suggests extra calls, initialization, or heap
  allocations in this hot path. Do not trade measurable compiler overhead for
  a cosmetic interface improvement.

Accept the refactor only with the same preservation/removal behavior, unchanged
bundle and analysis bookkeeping, and a reviewable diff. Update source and test
comments to describe the current invariant; keep rationale about this API change
in the plan and eventual commit/PR description.

## Source inspection

The inspected upstream checkout `/home/will/llvm-mos` was at
`c44aaa95aa724ea45a24357eb04483f03c9edb95`; the downstream implementation was read
from `vendor/llvm-mos/llvm/lib/CodeGen/VirtRegMap.cpp` and the carried patch.
Relevant contracts were checked in `VirtRegMap.cpp`,
`MachineInstr::isIdentityCopy`, `MachineInstr::addRegisterDefined`, and
`MachineOperand::readsReg`. The patch's existing recorded test base is
`742d554bf080`; refresh the upstream base before implementation.
