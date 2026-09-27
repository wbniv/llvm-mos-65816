# Prepare locally fixed work for posting — 2026-09-26

**September 27 near-store follow-up:** [0065](2026-09-27-broader-near-store-profitability.md) completes T3 locally. Its opening gates remain #321 extraction, destination reconciliation and independent review; local validation is not posting readiness. Update: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e0ee-df60-7d80-8629-5ad167a8c407`.

**Current 0064 status (2026-09-27):** PR #609 was withdrawn at the user's request; its branch and validated packet are retained for later revision. The native-width near-decoder repairs remain local to `0002`. [Current investigation](../investigations/2026-09-27-near-y-decoder.md). Update: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e061-3427-74a1-90ad-c0ee84b01b85`.

Will requested moving all locally fixed work to ready-to-post status, explicitly
without posting anything. This pass may prepare local patches, branches, drafts,
tests, and review records. It must not push branches, create PRs or issues, post
comments, deploy dashboards, or change existing remote submissions.

Preparation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh`
reasoning effort; verified session `01a0db16-f6a0-7e32-ada6-0c8098813933`.
Preserve earlier contributor credits and immutable defect baselines.

## Scope and acceptance

The starting point is the [current queue](../upstream-pending-work.md) and
[dashboard curation](../upstream-dashboard-curation.json). Defect and submission
entries describing the same change are one preparation unit, not new defects or
independent fixes. Already posted #604 and SDK #450 are not posting candidates.

A ready package identifies its destination and pinned base, exact submission
patch, prerequisites, regression and relevant runtime evidence, review outcome,
copy-ready body, and a local branch or reproducible application command. Qualify
the validation configuration and any remaining merge prerequisites. An apply
check alone does not establish compiler correctness. Existing evidence must
identify the patch revision it actually tested.

Do not promote a package with an unresolved correctness, review, extraction, or
posting-prerequisite gate. Distinguish readiness to open from merge ordering. In
particular, preserve the recorded #320/#321 presentation gate for 0028 and the
compiler/ABI prerequisites for far/native-width work; do not submit SNES code or
platform configuration.

## Preparation units

| Unit | Work to complete |
|---|---|
| 0039, 0043, 0044, 0046, 0047 | Refresh isolated exact-artifact checks; prepare 0044's draft; audit current upstream applicability |
| 0050, 0051 | Extract MOS-only submissions from the local correctness batch; omit already-upstream 0049 backports |
| 0054 | Prepare the generic scavenger range change with an honest target-hook trigger and regression dependency |
| 0056, 0057, 0058, 0059 | Prepare generic/AArch64 submissions, order shared error-recovery prerequisites, and complete review |
| 0060 | Check current upstream applicability and parallel MIR ownership/thread-safety; prepare reducer submission |
| 0028 | Reconcile smaller and refactored implementations; validate the exact selected artifact; preserve the presentation gate |
| 0013, 0052 | Package far-memory and near-section relaxation corrections with their actual #320 prerequisites |
| 0045 | Extract a stock-opcode printer regression; no semantic #321, 0039, or 0044 prerequisite |
| 0055 | Package wide-extension correction with #321 prerequisites |
| 0061, 0062, 0063 | Prepare far/native optimizations as separately reviewable stacked changes with measured contracts |
| 0053 | Classify test maintenance accurately, not as a new standalone compiler defect |
| 0037, 0038, 0040, 0041 | Audit older ready labels; complete missing current-LLVM validation or independent review and exact submission extraction |

## Execution record

- The off-machine [baseline backup](../investigations/2026-09-26-r2-baseline-backup.md)
  completed before submission preparation. It changes no compiler status.
- Read upstream refs without publication: llvm-mos main
  `7bd67c0ae4e8bb65a3f980912bf201df22131e34`; llvm/llvm-project main
  `e59a0c697552ae7d1c3aeed5774e829cdc5e16b5`.
- Isolated preparation source/build paths are
  `build/post-ready-2026-09-26-isolated-src` and `build/post-ready-2026-09-26-build`.
  The live vendor tree, existing candidate builds, and preserved baselines are
  not scratch space for patch application or rebuilds.
- Will authorized parallel independent reviewers. The inline-assembly, MOS, and
  reducer/feature reviews are retained under `docs/pr-preparations/2026-09-26/`.
  Their exact attribution and validation scopes are recorded separately.
- Independent reviews found no implementation blocker in the standalone MOS
  fixes or 0056–0059. The original 0060 parallel candidate's context isolation
  remains unestablished. A serial fallback was prepared, then rejected when
  clean-current testing found the existing upstream CLI guard. Upstream
  `b1ba3d515a02` predates the local report; the final packet backports that guard
  to MOS, with valid-input crash/diagnostic and serial-MIR/parallel-IR controls.
  Both rejected preparation evidence and historical parallel evidence remain.
- 0051 is a downstream-only decomposition repair; pristine upstream already
  passes its input. 0052 repairs downstream far-section policy. Neither is a
  new standalone upstream bug. 0061 requires both #320 and #321; 0063's selected
  optimization is increment-only, with decrement retained as a fallback test.
- 0028 now has a generic X86 MIR red/green witness and six companion contracts.
  This improves extraction evidence without lifting the presentation hold.

Status: local preparation complete for seventeen opening-ready packets:
eleven MOS packets (0038–0040, 0043–0047, 0050, 0054, 0060) and six LLVM packets
(0037, 0041, 0056–0059). Exact-current isolated builds, focused checks, relevant
suites, and independent reviews pass. 0028 also passes but retains the explicit
#320/#321 presentation hold. Feature-dependent extraction remains gated as
listed in the packet; no ABI decisions or SNES submission are implied. Historical
0023 evidence is still missing. Nothing has been posted, pushed, or deployed.

## Later 0064 preparation

The earlier seventeen-packet result remains dated evidence. The additional
[0064 packet](../pr-preparations/2026-09-26/0064-pr-body.md) is ready for upstream
review on `7bd67c0ae4e8`, with author review and exact-current validation.
This brings the local packet index to eighteen; the original independent-review
records do not cover 0064. The new record retains downstream profitability
losses and makes no speed or compiler-overhead claim. At completion of that
local preparation, nothing had been published. Subsequent [PR #609](https://github.com/llvm-mos/llvm-mos/pull/609)
publication and the user’s direction to leave it open are recorded in the
[0064 plan](2026-09-26-mos-carry-scheduling.md#11-publication).
Preparation: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh`
reasoning effort; verified session `01a0dd01-d72e-76f2-bf27-a796e0f7d994`.
