# Native far-word indexing: PR preparation

**September 30 update:** superseded for filing by the [rebased packet](../../2026-09-30/far-word-rebase/README.md) on `06bc967d2668`. Its [independent review](../../2026-09-30/far-word-rebase/independent-review.md) upholds 0069/0070 but blocks the series on defects in the far prerequisite. Update: Claude Code 2.1.283, model Claude Opus 5.5 (`claude-opus-5-5`), `xhigh` reasoning effort; session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`.

**Status: local working draft, September 28, 2026.** The user requested an evolving PR explanation that ties design and development choices to evidence for a demanding compiler audience, with diagrams where useful. Patch 0070 is integrated and installed downstream; this packet prepares its presentation within the native/far compiler series.

- [Extracted upstream series](upstream-series.md): ordered compiler patches on the pinned destination, assertions-build evidence, dependency reconciliation, and separately identified backend replay.
- [PR body](pr-body.md): proposed behavior, proof diagram, measured tradeoffs, and limitations.
- [Author review and evidence guide](review.md): choice-to-evidence mapping, exact source contracts, destination audit, reproduction, and remaining work.
- [Independent AI correctness review](independent-review.md): three source reviews, the resolved P2 regression-assertion finding and its executed sensitivity evidence, the preserved adjudication, and follow-up coverage.
- [Destination snapshot](destination.json): exact upstream revision, feature issue state, inspected artifacts, and scope of the audit.
- [Current downstream patch](../../../../patches/llvm-mos/0070-mos-far-word-index-policy.patch) and [0069 prerequisite](../../../../patches/llvm-mos/0069-mos-far-loop-range.patch).
- [Completed local investigation](../../../investigations/2026-09-28-far-word-policy.md) and [retained evidence](../../../defects/evidence/2026-09-28-far-word-policy/).

## How this draft evolves

Update the body and review when an implementation choice or measured result changes. Keep a direct source for each quantitative claim and retain negative and unchanged results. Use “fewer master clocks” for runtime reductions, state the measured region, and distinguish focused controls from independent workloads. Preserve earlier measurements as dated evidence.

The body uses local evidence links while it is being developed. Before posting into llvm-mos, publish the evidence on the authorized branch and replace those links with immutable commit URLs that resolve outside this repository. Keep prose paragraphs and list-item paragraphs on one physical line. The Mermaid diagram is native GitHub Markdown; no separate image artifact is required.

## Current preparation and next review

The [extracted-series packet](upstream-series.md) now supplies concrete ordered commits on upstream `26d7c2c1eebf98ca194b92609ba4e7540bfc6ef6`, an assertions-enabled build, expanded boundary/operand/integration coverage, and a fresh workload replay. Its execution identified missing prerequisites and a new native index copy-cost case; each is reconciled with prior work and has retained evidence. See that packet for the exact completed matrix and remaining limits.

The original [independent downstream review](independent-review.md) and opcode-assertion correction remain valid for their recorded source. They do not certify the larger extracted series. Next, independently review that complete compiler/ABI candidate, settle the listed feature/ABI contracts, and publish immutable evidence links before filing. Compiler overhead and independent-application profitability remain unmeasured. SNES implementation/platform code remains on its [separate submission track](../../../upstream-pending-work.md#snes--separate-platform-track).

Preparation and source/measurement audit: OpenAI Codex CLI 0.157.1 (session source `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.

Independent-review coordination and summary update: OpenAI Codex CLI 0.157.1 (session source `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.
