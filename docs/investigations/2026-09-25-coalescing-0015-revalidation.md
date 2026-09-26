# Revalidate the 0015 coalescing guard

The retained 0015 C witness is repaired by the existing **0028 identity-copy
liveness fix**. A new coalescing guard is not needed for that witness. The old
explanation that a copy hint makes allocation ignore a call's clobber mask is
not supported by the recovered failure. [Structured record](../defects/mos-coalescing-rc-undef.json).

Investigation, experiments, and documentation: OpenAI Codex CLI 0.157.0
(`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort, verified from
[session metadata](../defects/evidence/2026-09-25-coalescing-0015/session-identity.json).
Exact agent/tool version, model/version, and reasoning effort for the historical
June work are unknown in the recovered records; earlier recorded credits and
claims remain in the archived originals.

## What reproduces

The original patch's MIR test checks that a COPY survives coalescing. Extracting
that test from the checked-in patch and running it on saved unpatched upstream
`742d554bf08042b8df93d791c335260fadd16643` shows that both coalescing and subsequent
allocation verify successfully. Without 0015, the allocator keeps the live value
in preserved `$rc20` across the call. The test demonstrates the guard's behavior,
not the claimed allocator defect. Its patch artifact remains intact; that test
was absent from the current vendor test directory.

The original [rcundef.c](../defects/evidence/2026-09-25-coalescing-0015/original/rcundef.c.gz)
is archived without changing its bytes, with preprocessed inputs and IR.
[Archive identity and replay instructions](../defects/evidence/2026-09-25-coalescing-0015/source-archive.json)
preserve the original source comments and the paths used in recorded commands. A diagnostic build disables only
0015; another replaces only VirtRegMap.cpp.o with its pre-0028 version. The
installed compiler is unchanged. Reverse-applying the current 0028 patch exactly
recreates that older source, establishing the isolated source difference.

| 0015 guard | 0028 root fix | a16/xy16, O1/Os witness |
|---|---|---|
| Enabled | Enabled | Pass |
| Disabled | Enabled | Pass |
| Enabled | Disabled | Pass |
| Disabled | Disabled | Fail: undefined `$rc3` |

These are **reconstructed current-fork baselines**, not the lost June binaries.
The failure matches the historical `newton_step` diagnostic:
`renamable $x = COPY killed renamable $rc3`. Both reconstructed failing and passing
binaries are retained under `build/defect-baselines/2026-09-25-coalescing-0015/bin/`.
[Tool identities](../defects/evidence/2026-09-25-coalescing-0015/contrast-identities.json)
and [matching-input runs](../defects/evidence/2026-09-25-coalescing-0015/closure-runs.json)
record the comparison.

## Causal explanation

Capture the compiler-generated MIR before `greedy`, then run the same MIR through
`greedy,virtregrewriter` with and without 0028, with 0015 disabled in both builds.
The [complete output difference](../defects/evidence/2026-09-25-coalescing-0015/rewriter-difference.diff)
contains exactly three inserted `KILL` pseudos and no changed register assignments.
One preserves `$rs1`'s lane definition immediately before the failing `$rc3` read.

A full virtual COPY defines its destination even when a source lane is undef.
When allocation gives both operands the same physical pair, deleting the identity
COPY also discards that lane definition. Patch 0028 retains the required definition
as a KILL. The coalescing veto changes which copies and allocations occur, avoiding
this trigger, while 0028 repairs the rewriter contract itself. The recovered
failure therefore does not justify a separate regmask-interference fix in 0015.

This is a verifier/liveness finding. No new runtime miscompile is claimed, and
the comparison adds only pseudos that emit no instructions. Historical demo
results remain supporting context, not new execution evidence: see the published
[Newton Fractal](https://biohack.net/snes/newton/) application.

## Stock-upstream reproducer and limits

The existing eight-instruction
[MIR model](../defects/evidence/2026-09-25-coalescing-0015/stock-identity-copy-model.mir)
is valid before allocation and reproduces on the saved **unpatched upstream**
compiler with either `mos6502` or `mosw65816`, without native-width features:

```sh
dev/upstream-reference.sh llc -mtriple=mos -mcpu=mos6502 \
  -run-pass=greedy,virtregrewriter -verify-machineinstrs \
  docs/defects/evidence/2026-09-25-coalescing-0015/stock-identity-copy-model.mir \
  -o /dev/null
```

The model is explicitly constructed, already carried with 0028; it is not a new
stock C producer or an unchanged automated reduction of this C witness.
[Individual runs](../defects/evidence/2026-09-25-coalescing-0015/stock-model-results.json)
retain input-validation and failing/passing pass results.

Stock Clang/llc were checked for the retained C source on `mos6502` and
`mosw65816` at O0/O1/O2/O3/Os/Oz. All twelve cases pass through the rewriter.
Full compilation has one failure, plain 6502 O0, at the separately established
[0030 copy-expansion defect](../pr-preparations/2026-09-22/0030-validation.md).
The other eleven pass. Thus **stock C reachability is still unproven**.

On the integrated fork, all eighteen default/a16/xy16 configurations pass with
0015 enabled and with it disabled. The four relevant O1/Os native configurations
fail when both repairs are absent; O0 remains a passing control.
[Native matrix](../defects/evidence/2026-09-25-coalescing-0015/native-c-results.json),
[without-0028 matrix](../defects/evidence/2026-09-25-coalescing-0015/without-0028-results.json),
and [stock matrix](../defects/evidence/2026-09-25-coalescing-0015/stock-c-corrected-results.json)
retain the evidence. The initial stock runner passed unsupported `-Os`/`-Oz`
options to llc; its argument errors are preserved separately. The corrected run
uses backend O2 with the frontend's size attributes retained in IR.

## Disposition and follow-up

Keep 0015's historical guard, original patch, and reproducer evidence. Its draft
should no longer present a separately proven allocator bug as ready for posting.
Route this recovered witness to 0028's generic fix and existing upstream model.
Guard removal would be separate work; passing present-day inputs alone is not
the basis for retiring it. No new compiler implementation was needed here.

Automated reduction exposed a separate
[llvm-reduce parallel-MIR crash](../defects/llvm-reduce-parallel-mir-crash.json):
`-j 2` segfaults on both the full captured MIR and the eight-instruction model.
The binary, exact input, command, comparator, and logs are retained; source/build
provenance and root cause remain qualified. Serial reduction made progress and
was interrupted after several minutes, preserving a valid partial reduction
that still fails without 0028 and passes with it. That partial input still uses
fork instructions and is not presented as stock-upstream MIR. Repairing the
reducer is outside this 0015 revalidation.

Follow-up: [parallel MIR reduction fix](2026-09-25-llvm-reduce-parallel-mir-fix.md)
replays the preserved crashing binary and input, identifies the missing
`MachineModuleInfo` in parallel workers, and records same-input red/green
evidence. The 0015 baseline and its original disposition above are unchanged.

The [opcode roundtrip plan](../plans/2026-09-25-65816-all-opcode-roundtrip.md)
remains written and unimplemented, as requested. Current summaries, earlier
0015/0028 investigations, and the generated status/flowchart views are updated
through the document dependency workflow; historical evidence is preserved.
