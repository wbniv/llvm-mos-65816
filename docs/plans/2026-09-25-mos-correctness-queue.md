# Float vectors and the four failing MOS tests

Implement the correctness work authorized on September 25: float-vector
legalization and diagnosis of `legalizer.mir`, `scavenger-p-undef-6502.ll`,
`shift-rotate.ll`, and `addressing-modes-65816.s`. Optimization work and upstream
publication are outside this task.

Attribution: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`,
`xhigh` reasoning effort, verified from session metadata
`01a0d7d4-5da2-7fe0-a88c-0137eaa043a7`.

## Evidence and implementation

1. Preserve the existing failing binaries, source snapshot, original tests,
   commands, diagnostics, and relevant IR/MIR before modifying compiler code.
2. Record each compiler defect in `docs/defects/` and link its evidence here.
   Distinguish compiler defects from test-driver or expected-output problems.
3. Scalarize supported float/double vector operations into scalar libcalls.
   Exercise retained C vector-extension inputs and direct backend regressions.
4. Repair the invalid truncation and investigate assembler relaxation against
   the existing near/far addressing contract. Diagnose shift output by execution
   before updating any checks. Use the registered pass name for the scavenger
   test while retaining its flag-liveness assertions.
5. Carry changes in reproducible patch artifacts; validate the same inputs on
   preserved baseline and candidate tools. Run the full MOS suites and relevant
   runtime/round-trip checks, then update the task records with actual results.

## Baseline

Preserved tools and source reconstruction artifacts:
`build/defect-baselines/2026-09-25-mos-correctness/`.
Durable inputs, diagnostics, and identities:
`docs/defects/evidence/2026-09-25-mos-correctness/`.

The checkout contains pre-existing unrelated edits. They are retained.
Historical reports are not closed merely because a current input passes.

Resolved records: [float vectors](../defects/mos-float-vector-legalization.json),
[same-width truncation](../defects/mos-zp-index-same-width-trunc.json), and
[bank relaxation](../defects/mos-bank-relax-section-offset.json).

The captured suite has 168 tests: 162 pass, two unsupported, four fail.
The pin lacks Daniel Thornburgh's upstream vector work (`77a0dd93c5e9` plus
the vector load/store rule in `4b98e4726b3a`). Those prerequisites must be
backported for the local compiler; earlier triage used newer upstream code.
The original C inputs now first fail on vector stores. Their immutable inputs,
preprocessed translation units, IR, and translated MIR are retained separately
from the reconstructed direct float-vector regression.

## Expanded scope: status-register scavenging

The user explicitly requested repairing the newly exposed `-O0` a16/xy16
status-register spill failure as well. Its separate
[record](../defects/mos-vector-o0-status-scavenge.json) retains the vector-enabled
failing binary, original C/preprocessed/IR inputs, and pre-PEI MIR. The baseline
for that issue is independent of the original vector-legalization baseline.

## Resolution

The four compiler records linked above are fixed with matching-input red/green
evidence. Patch `0049` backports Daniel Thornburgh's generic vector work;
`0050` adds scalarization before float/double libcall selection. `0051` reuses
an already-byte-sized zero-page index instead of creating `G_TRUNC s8 to s8`.
`0052` allows bank relaxation when a section-relative offset plus addend exceeds
65535. The latter supersedes the September 24 parser diagnosis: MCAssembler
already knows the offset, but the downstream near-section suppression discarded
it. No parse-time symbol-width redesign is required for this defect.

The other two lit failures are test maintenance, carried in `0053`:

- `scavenger-p-undef-6502.ll` used an unregistered pass spelling at this LLVM 23
  pin. `prologepilog` executes its existing flag-liveness checks.
- The shift checks expected a different legal assembly sequence. Before changing
  them, a runner compiled the original `shift-rotate.ll` with the preserved
  baseline compiler and checked 196,608 arithmetic-shift results on mos-sim.
  All passed; those results support updating the checks, not claiming a shift
  compiler fix. The related `legalizer.mir` shift expectation is updated too.

Patch `0054` fixes the separately reproduced scavenger abort. The backward
search validated `canSaveScavengerRegister` when selecting a survivor, then
extended the save point to earlier virtual-register instructions without
rechecking it. This crossed a push/pull boundary while both index registers were
live. Each extension now requires the target to accept the larger range;
otherwise the search retains its last valid range. This repairs the backend
contract without changing how the frontend generates the input. Other targets'
default always-true hook preserves their search behavior.

The original `scal-to-vec3-O0.ll` and pre-PEI MIR remain intact. A separately
**constructed** 54-line MIR test, `scavenger-status-save-range.mir`, pins the same
mechanism: carry and both index registers live, a temporary carry inside an
accumulator push/pull, and a preceding virtual-register use. It fails with the
same status-save diagnostic on the preserved vector-enabled compiler in both
a16 and xy16, and passes with `0054`. The exact focused MIR is also compiled
from PEI onward and executed on bsnes-jg: bytes **6, 6, 7, 1** verify carry,
accumulator, and both index registers after scavenging.

## Validation and limits

Evidence root: [retained artifacts](../defects/evidence/2026-09-25-mos-correctness/).
The original `baseline/`, the intermediate `vector-prerequisite/`, and the
`scavenger-baseline/` inputs and failure logs remain unchanged.

| Check | Result | Retained evidence |
|---|---|---|
| Final CodeGen/MOS + MC/MOS lit | **171 pass, 2 unsupported, 0 fail** (173 discovered) | `scavenger-candidate/lit.log` |
| Four vector C inputs × O0/O2/Os IR × 6502/a16/xy16 | **36/36 pass** with machine verifier | `scavenger-candidate/vector-c-matrix.{json,log}` |
| Original two C inputs, O0 a16/xy16, installed clang | **4/4 pass**, non-LTO | `scavenger-candidate/installed-smoke.log` |
| Focused MIR, preserved baseline versus candidate | Expected abort versus pass in a16/xy16; PHP/PLP order checked | `scavenger-candidate/focused-*` |
| Focused MIR runtime, default/a16/xy16 | **3/3 pass**, bsnes-jg, sentinel 0x600d | `scavenger-candidate/runtime.log`, `runtime-runs.json` |
| Float/double vector runtime | 96 lane comparisons at each O0/O2/Os on mos-sim; six split float/double SNES cases pass | `candidate/vector-runtime.log`, `vector-snes-split-runtime.log` |
| C/object/disassembly round trips | default 97 identical + 23 unsupported; a16 120 identical; xy16 120 identical; **0 divergent** | `candidate/roundtrip-*.log` |
| Baseline arithmetic-shift runtime | **196,608 checks pass** | `baseline/shift-runtime.log` |
| Clean patch-stack reconstruction | All applications pass; compiler sources and new tests match | `candidate/patch-stack.log`, `scavenger-candidate/patch-stack.log` |

`Os` rows use size-optimized frontend IR and `llc -O2`, which is the backend
optimization setting; the command manifests distinguish them. Runtime and
round-trip checks under `candidate/` used the vector-enabled compiler before
`0054`; the focused scavenger runtime and final suite use the final compiler.
The first combined float/double SNES runtime test exceeded the near ROM budget;
splitting the two types produced the six passing ROMs. No result is inferred
from that failed link. The main build is Release with assertions disabled;
`-verify-machineinstrs` is enabled in the compiler regressions. No assertions-on
rebuild or full 4,170-case torture rerun is claimed.

Clean reconstruction has one unrelated, pre-existing comment-only mismatch in
`spill-hoist-scratch-vreg.ll` (`0033`); no compiler source mismatch. `0054` applies
to pristine pinned `RegisterScavenging.cpp`, which no earlier patch changes.
`dev/toolchain.sh` applies `0049`–`0054`; the MOS-source patches `0049`–`0052` are
also excluded from `0002` regeneration. The 6502 scavenger test is imported from
`0011` before its test-driver correction. The installed clang/lld and auxiliary
MC/objdump tools are refreshed. CMake adjusts clang's installed RPATH, so its
installed binary hash differs from the build-tree hash; both are recorded in
`scavenger-candidate/identity.json`.

Preserved binary locations remain under
`build/defect-baselines/2026-09-25-mos-correctness/`, including
`llc-vector-enabled` for the scavenger baseline. The source pin, initial dirty
source archive, intermediate identities, patch hashes, commands, runtime hashes,
and final identities make the stages distinguishable. New patches remain local;
upstream submission preparation is separate work. No historical unreproduced
report is closed by these results.

Repository validation passes: comment-history checks, defect-evidence checks
against both worktree and a temporary staged index, and the staged SNES display
gate. The real index is untouched. Whitespace validation covers changed code,
patches, and documentation; captured evidence retains LLVM's generated whitespace
to preserve exact input hashes. See `scavenger-candidate/repository-checks.log`.
