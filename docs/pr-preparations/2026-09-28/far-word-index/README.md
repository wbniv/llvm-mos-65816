# Native far-word indexing: PR preparation

**Status: local working draft, September 28, 2026.** The user requested an evolving PR explanation that ties design and development choices to evidence for a demanding compiler audience, with diagrams where useful. Patch 0070 is integrated and installed downstream; this packet prepares its presentation within the native/far compiler series.

- [PR body](pr-body.md): proposed behavior, proof diagram, measured tradeoffs, and limitations.
- [Author review and evidence guide](review.md): choice-to-evidence mapping, exact source contracts, destination audit, reproduction, and remaining work.
- [Destination snapshot](destination.json): exact upstream revision, feature issue state, inspected artifacts, and scope of the audit.
- [Current downstream patch](../../../../patches/llvm-mos/0070-mos-far-word-index-policy.patch) and [0069 prerequisite](../../../../patches/llvm-mos/0069-mos-far-loop-range.patch).
- [Completed local investigation](../../../investigations/2026-09-28-far-word-policy.md) and [retained evidence](../../../defects/evidence/2026-09-28-far-word-policy/).

## How this draft evolves

Update the body and review when an implementation choice or measured result changes. Keep a direct source for each quantitative claim and retain negative and unchanged results. Use “fewer master clocks” for runtime reductions, state the measured region, and distinguish focused controls from independent workloads. Preserve earlier measurements as dated evidence.

The body uses local evidence links while it is being developed. Before posting into llvm-mos, publish the evidence on the authorized branch and replace those links with immutable commit URLs that resolve outside this repository. Keep prose paragraphs and list-item paragraphs on one physical line. The Mermaid diagram is native GitHub Markdown; no separate image artifact is required.

## Next iteration

1. Obtain independent review of 0069's induction proof and 0070's admission, all-users bound, function-attribute policy, and memory contracts. This packet is author preparation; no independent review is claimed.
2. Pull the required far-pointer and native-width compiler/ABI changes for #320/#321 out of the larger fork into focused, ordered commits. Apply them to a pinned upstream revision, then add 0069 and 0070. Record the exact commits so reviewers receive a complete, reproducible patch stack.
3. Build that compiler and repeat the relevant correctness, code-size, and runtime comparisons. This checks that separating and rebasing the changes preserves their behavior and that no dependency was missed. **The existing downstream results remain valid; this additional validation covers the precise code proposed for upstream.** [Detailed steps](review.md#what-testing-the-proposed-upstream-patch-stack-means). Keep the O3 size tradeoff and the size-mode ablation in the report. Assess compilation overhead and independent application cases before claiming broader profitability.
4. Finalize public evidence links and posting text after those results. Merge order follows the compiler/ABI prerequisites. The SNES platform remains on its [separate submission track](../../../upstream-pending-work.md#snes--separate-platform-track).

The [remaining review questions](review.md#remaining-development-and-review-questions) cover independent correctness review, broader application performance, compilation overhead, whether to retain the hidden policy switch, and whether the proposed upstream patch stack preserves behavior and includes all dependencies.

Preparation and source/measurement audit: OpenAI Codex CLI 0.157.1 (session source `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.
