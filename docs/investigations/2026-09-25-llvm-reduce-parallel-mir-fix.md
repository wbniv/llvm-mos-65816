# Parallel MIR reduction preserves machine functions

The [parallel MIR reducer defect](../defects/llvm-reduce-parallel-mir-crash.json)
is fixed locally by [patch 0060](../../patches/llvm-mos/0060-llvm-reduce-parallel-mir.patch).
The retained eight-instruction MOS input and its interestingness test reproduce
SIGSEGV (`exit_code=-11`) on the archived reducer with `-x=mir -j 2`. The
same input completes reduction on the candidate, and the output still passes
the interestingness test.

## Cause and change

The parallel path wrote every work item as LLVM bitcode. Reloading that
bitcode reconstructed the IR module but left `ReducerWorkItem::MMI` null. A
worker running the MIR instruction pass dereferenced `MMI` while looking up
machine functions. Serial reduction clones the MIR work item and retains its
`MachineModuleInfo`.

The parallel MIR workers now clone their machine functions into separate work
items and return the selected work item with its `MMI`. Their shared IR module
is read-only during MIR reduction. Parallel IR workers still reload bitcode in
separate LLVM contexts. The [new MIR lit input](../defects/evidence/2026-09-25-llvm-reduce-parallel-mir/parallel-instr-reduce.mir)
exercises `-j 2` and checks the surviving instruction.

## Validation

- [Baseline replay](../defects/evidence/2026-09-25-llvm-reduce-parallel-mir/baseline-replay.log)
  exits `-11`; the [candidate run](../defects/evidence/2026-09-25-llvm-reduce-parallel-mir/candidate.log)
  exits `0` on the identical retained input and command options. The
  [reduced output](../defects/evidence/2026-09-25-llvm-reduce-parallel-mir/candidate-output.mir)
  passes `interesting-rewriter.py`.
- The [focused test runs](../defects/evidence/2026-09-25-llvm-reduce-parallel-mir/regression-runs.json)
  show the new MIR lit input crashing on the preserved baseline and passing
  with the candidate; FileCheck accepts the candidate output.
- The existing `parallel-workitem-kill.ll` IR reduction passes with `-j 4`,
  including its output check. The retained MOS input also completes with
  `-j 4` and remains interesting.

[Tool identities](../defects/evidence/2026-09-25-llvm-reduce-parallel-mir/identity.json)
and the [candidate build commands](../defects/evidence/2026-09-25-llvm-reduce-parallel-mir/build-commands.txt)
are retained. The original baseline binary and logs are unchanged. The exact
September 20 source/build state of that binary remains unknown; the same
preserved binary was replayed here. Published upstream applicability has not
been assessed.

Fix and investigation: OpenAI Codex API (version unknown), GPT-6 (exact model
ID/version unknown), reasoning effort unknown. The earlier investigator's
recorded credit remains in the defect record.
