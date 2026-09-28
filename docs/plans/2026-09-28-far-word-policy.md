# Native far-word speed/size policy

**Status: completed and installed locally, September 28, 2026.** [Measurements, implementation, and validation](../investigations/2026-09-28-far-word-policy.md).

Attribution: OpenAI Codex CLI 0.157.1 (session source: `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.

## Completed scope

1. Reconcile the existing defect, native-word experiment, installed 0069 proof, patch stack, source, and compiler identities. Rebase the word experiment using an isolated build.
2. Trace the A16 `-Os` growth: the word loop saves 27 bytes, while surrounding allocation and spill changes add 89. Mode-switch counts are unchanged.
3. Implement a speed policy that respects function size/no-opt attributes, retains boundary/call/escape restrictions, and limits mixed word/byte groups to Y8.
4. Compare A16/XY16 at `-Os`, `-Oz`, and `-O2`; retain bank-crossing, wrapping, pressure, instruction-shape, and dual-emulator checks. Add a focused `-O3` comparison because the default also applies there.
5. Integrate patch 0070, preserve 0002, install, verify exact output controls, and refresh the evidence and dependent summaries.

At `-O2`, complete Farblit `main` uses 7.12%/7.74% fewer master clocks and is 13/38 bytes smaller in A16/XY16. `-O3` A16 accepts 46 extra bytes for 7.29% fewer master clocks. `-Os`/`-Oz` retain baseline output. The size cost therefore does not veto use in a build that requests speed.

## Separate upstream work

The [working PR packet](../pr-preparations/2026-09-28/far-word-index/README.md) now maps choices to evidence, includes proof and dependency diagrams, and records a source inspection of upstream `26d7c2c1eebf`. The inspected upstream path lacks the required native/far machinery. [Independent downstream AI source review](../pr-preparations/2026-09-28/far-word-index/independent-review.md) is complete with no valid-input compiler correctness defect found. The P2 FileCheck opcode-boundary issue is resolved: all 156 wrong substitutions are rejected and four focused regression files pass. The [extracted candidate](../pr-preparations/2026-09-28/far-word-index/upstream-series.md) adds the focused coverage, concrete ordered patches, and an identified build/replay; independent review of the whole compiler/ABI series remains in [TODO](../../TODO.md). The [validation steps](../pr-preparations/2026-09-28/far-word-index/review.md#what-testing-the-proposed-upstream-patch-stack-means) explain how to separate the required changes, apply them to a pinned upstream base, and repeat the relevant comparisons; the existing downstream results remain valid. This remains local preparation; no upstream publication is claimed.

Independent-review coordination and summary update: OpenAI Codex CLI 0.157.1 (session source `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.

## Upstream preparation update — September 28

The [extracted candidate](../pr-preparations/2026-09-28/far-word-index/upstream-series.md) now records concrete ordered patches on exact upstream, an assertions build, expanded checks, prerequisite reconciliation, and a separate frozen-IR backend replay. The earlier completed downstream experiment remains dated evidence. Independent review of the complete compiler/ABI candidate and its listed scope limits remains necessary.

Preparation update: OpenAI Codex CLI 0.157.1 (session source `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.
