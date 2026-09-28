# Local posting preparation — September 26, 2026

**Current publication status:** PR #609 was withdrawn at the user's request at `2026-09-27T01:38:15Z`. Earlier review and validation results remain dated evidence. [Withdrawal record](0064-submission.json). Update: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e061-3427-74a1-90ad-c0ee84b01b85`.

The original seventeen-packet preparation pass posted, pushed, and deployed
nothing. The later 0064 publication is recorded in its separate section below.
The original pass authorized local preparation and independent reviewers.
Compiler defect closure and submission readiness are separate statuses.

Eighteen packets have recorded validation: twelve for llvm-mos (including
one existing-upstream backport) and six for llvm/llvm-project. Seventeen remain
unpublished; 0064 was posted as [PR #609](https://github.com/llvm-mos/llvm-mos/pull/609). The added 0064
packet has author review; the earlier seventeen retain their recorded independent
reviews. 0028 also passes validation but remains
under the user's explicit presentation hold. Feature-held work is listed below.

**Additional September 27 packet:** [0068 null-output streamer](../2026-09-27/0068-validation.md) has a standalone extraction author-validated on upstream `26d7c2c1eebf`, with no feature-series prerequisite. Independent review and posting remain pending. The original eighteen-packet counts above describe the earlier preparation cohort.

## Exact bases and scope

- llvm-mos/llvm-mos main: `7bd67c0ae4e8bb65a3f980912bf201df22131e34`.
- llvm/llvm-project main: `e59a0c697552ae7d1c3aeed5774e829cdc5e16b5`.
- Linux Release builds with assertions enabled. The MOS tool build enables MOS
  plus X86/ARM/AArch64 targets; this packet's suite results cover MOS, not fresh
  full cross-target suites. The separate LLVM build enables X86/AArch64.
- Current-source snapshots are retained as `.cpp.txt` documentary files under
  `upstream-source/`. They are not additional compiler changes.

| Package | Destination / prerequisites | Current preparation state |
|---|---|---|
| 0037 | llvm/llvm-project, standalone | Ready: exact LLVM main red/green, four focused RUNs and 168 filtered suite passes / three existing XFAILs; independent review |
| 0038 | llvm-mos, standalone | Ready: independent review, five focused commands and 134 suite passes / one unsupported; separate SPC700 0003 limitation retained |
| 0040 | llvm-mos, standalone | Ready: reviewed pre-greedy MIR trigger, exact assertion red/green, two focused RUNs and 132 suite passes / one unsupported |
| 0041 | llvm/llvm-project, standalone | Ready: reviewed standalone extraction includes multi-register output widening; ten focused RUNs and 168 filtered suite passes / three existing XFAILs |
| 0039 | llvm-mos, no candidate prerequisites | Ready: isolated red/green, 134 suite passes / one unsupported; wrong-address emulator differential passes; independently reviewed |
| 0043 | llvm-mos, standalone | Ready: adapted exact diagnostics reviewed; 14 regression RUNs and isolated MOS suites pass |
| 0044 | llvm-mos, stacked on 0039 | Ready as dependent PR: exact packet red/green; 136 suite passes / one unsupported |
| 0045 | llvm-mos, standalone | Ready: stock-opcode red/green and object round trip; 132 suite passes / one unsupported; no 0039/0044/#321 dependency |
| 0046 | llvm-mos, standalone | Ready: reviewed table invariant, isolated build and 131 suite passes / one unsupported; no runtime-red claim |
| 0047 | llvm-mos, standalone | Ready: current MCAsmInfo reference API adapted and reviewed; nine regression RUNs; 133 suite passes / one unsupported |
| 0050 | llvm-mos, standalone | Ready: stock scalarization regression red/green and full MOS suites pass; 0049 already upstream |
| 0054 | llvm-mos, standalone | Ready: valid scavenger-test input, exact assertion-enabled red/green and MOS suites pass; independent checks cover three stock CPUs |
| 0056 | llvm/llvm-project, standalone | Ready: reviewed bounds repair retaining upstream API; four focused RUNs and 168 filtered suite passes / three existing XFAILs |
| 0057 | llvm/llvm-project, standalone | Ready: reviewed bounds/recovery repair; two focused RUNs and 168 filtered suite passes / three existing XFAILs |
| 0058 | llvm/llvm-project, stacked on 0057 | Ready as dependent PR: 19 focused RUNs and 169 filtered suite passes / three existing XFAILs; independently reviewed |
| 0059 | llvm/llvm-project, stacked on 0057 | Ready as dependent PR: 24 focused RUNs and 169 filtered suite passes / three existing XFAILs; independently reviewed |
| 0060 | llvm-mos, upstream guard backport | Ready: valid-input crash/diagnostic comparison, nine focused RUNs and 180 reducer-suite passes / 27 unsupported; not a new LLVM bug |
| 0064 | llvm-mos, standalone | Posted as [PR #609](https://github.com/llvm-mos/llvm-mos/pull/609): author-reviewed extraction, ten focused RUNs, 132 suite passes / one unsupported, 512 stock-6502 oracle vectors; targeted kernel 133 → 59 B; 117 neutral C-to-object pairs with rebuilt upstream Clang across 6502, 65C02 and stock 65816. No independent-review claim |
| 0028 | llvm/llvm-project source + X86 MIR | Selected refactor validated on exact LLVM main: two focused RUNs and 102 filtered suite passes / one existing XFAIL; #320/#321 publication hold retained |

Each numbered `*-pr-body.md` is a local draft. A corresponding `*-llvm-mos.patch`
or `*-llvm-project.patch` is the exact candidate, including its regression.
The [MOS validation summary](mos-validation.md) links each completed package to
its exact patch hash and immutable receipt. The [LLVM validation summary](llvm-validation.md)
records seven completed isolated builds. Six LLVM packets are ready; 0028 is
validated but held. The obsolete `0060-llvm-project.patch` is retained only as a
rejected preparation attempt; use `0060-llvm-mos.patch` for its backport.

The separate `0044-validation.md` record uses an older base and different build;
it is not evidence for this packet's readiness. This packet's 0044 result is the
assertions-enabled exact-base receipt linked from `mos-validation.md`.

## Applying a package without publishing

When preparing a PR body, follow the [PR Markdown requirements](../../../AGENTS.md#upstream-submissions-and-published-demos): use one physical line per prose paragraph and per list-item paragraph, leaving paragraph breaks and structural newlines intact. Check the final body before posting so GitHub can wrap prose naturally. Apply formatting updates to current unposted drafts; preserve posted descriptions and their retained copies unless the user requests those changes explicitly.

Use an owned scratch checkout of the destination repository, detached at the
exact base above. Do not apply the packet to the live fork or a captured baseline.
For 0044, apply 0039 first; for 0058 or 0059, apply 0057 first. Other standalone
packages apply individually. For example, with `PACKET` set to this directory:

```sh
git apply --check "$PACKET/0039-llvm-mos.patch"
git apply "$PACKET/0039-llvm-mos.patch"
git apply --check "$PACKET/0044-llvm-mos.patch"
git apply "$PACKET/0044-llvm-mos.patch"
```

No push or PR-creation command is part of this workflow. `validate.py` records
isolated builds, binary hashes, same-input regression commands/logs, and MOS
suite results. Its fixed `/work` paths describe the network-disabled build
container mounts, not an arbitrary checkout to overwrite. It refuses a dirty
scratch checkout, captures each baseline before applying the candidate, and
reverses only patches it applied. New runs need a new `--run-tag` so earlier
evidence remains immutable. The exact invocation and image identity accompany
the validation receipts where captured. The first eight completed MOS run image digests were not captured; binary
hashes and configurations are retained. Later 0038/0040, LLVM, and reducer runs
also record the exact container image.

Durable raw evidence is under `validation/runs/`. Its subdirectories preserve
the original build-directory names. A recorded `build/<name>/...` log or input
can be read at `validation/runs/<name>/...`; original receipts and logs are not
rewritten to change their historical command paths. Compiler binaries remain
in the original ignored build snapshots, identified by SHA256. Early 0043 test
diagnostic and 0047 API failures, plus the invalid PEI-entry 0054 experiment,
remain separate from the later `-r2`/`-r3` successful validation runs.
The valid nested-spill 0054 probe additionally overlaps the already-known 0011
live-N/Z assertion. A balanced control proves that issue exists independently
of 0054; it is not a new defect report or an invalid-input dismissal.

Integration note (September 27): the ancillary 0038 source copy
`validation/runs/post-ready-review-mos/0038/source/llvm/test/CodeGen/MOS/late-opt-65816.mir`
has a comment normalized to the current-contract rule. It is not an input in
the retained replay receipts; its executable test content is unchanged. Recorded
inputs, hashes, and logs are preserved. Integration and document review:
OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort.

## Work that cannot yet be labeled ready to open

**September 27 follow-up:** the [near-Y and bank-wrap simulated PR](../2026-09-27/near-y-pr-simulation.md) records the published downstream repair and full gallery proof. Its #321 extraction and independent-review gates remain in the [feature-held ledger](feature-held-packages.md).

**September 27 near-index follow-up:** [overflow-proof recovery](../../investigations/2026-09-27-near-index-overflow-proofs.md) is implemented locally in `0002`; its own evidence covers the optimization, and #321 extraction and independent review remain pending.

**September 27 near-store follow-up:** [0065 and the T3 completion record](../../plans/2026-09-27-broader-near-store-profitability.md) add measured local optimizations. Those opening preparation gates were completed in the [September 28 extracted packet](../2026-09-28/0065/README.md), with its own independent 0065 review. The PR is unposted and the native feature posting hold remains; the original 0063 review retains its earlier scope.

The [feature-held ledger](feature-held-packages.md) covers 0013, 0051, 0052,
0055, and 0061–0063, plus 0028's explicit presentation hold. Their implementations
are reviewed, but unresolved #320/#321 compiler/ABI extraction is not merely a
merge-order dependency. Neither a blanket status change nor a new standalone
bug report is justified. 0049 is an existing-upstream backport; 0053 is test
maintenance. Historical 0023/#320 evidence is still missing and remains open.

Older reviewed submissions retain their existing dated validation rather than
receiving an unearned fresh certification here. The identified extraction,
review, and exact-current validation gaps for 0037/0038/0040/0041 are now closed.
Already-posted #604 and SDK #450 are excluded from this preparation pass.

## Independent review records

- [MOS correctness and assembler review](mos-review.md), including 0039 runtime.
- [Inline-assembly bounds/type/vector review](inline-asm-review.md).
- [Reducer ownership and feature boundaries](reducer-feature-review.md).
- [Far memory, immediate printer, native extension](native-fix-review.md).
- [Native-memory optimization contracts](native-optimization-review.md).
- [0028 selection and generic X86 regression](0028-review.md).
- [0037 current-LLVM extraction](0037-review.md).
- [0038 return/frame-address contracts](0038-review.md).
- [0040 coalescing and 0041 multi-register extraction](0040-0041-review.md).
- [0060 existing-upstream guard backport](0060-backport-review.md).

The review agents are independent passes of the same model, not human or
different-model reviewers. Their exact session identities and attribution are
in those records. Earlier implementation credits and captured defect baselines
remain unchanged.

Coordination, extraction, and current-base validation: OpenAI Codex CLI 0.157.0
(`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session
`01a0db16-f6a0-7e32-ada6-0c8098813933`.

## 0064 addition

[Computed-carry PR text](0064-pr-body.md), [source and profitability review](0064-review.md),
and [validation](0064-validation.md) were added by OpenAI Codex CLI 0.157.1
(`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session
`01a0dd01-d72e-76f2-bf27-a796e0f7d994`. Local branch
`mos-computed-carry-scheduling` contains `155e209c4cee`. The extraction has no
candidate prerequisites and imports no native-width or platform changes.
The earlier independent-review records do not cover this addition. At completion
of local preparation, nothing had been pushed or posted; the later publication
is recorded below. Cycle and compile-time claims remain unmeasured.

## Computed-carry scheduling (0064) publication

This publication contains the standalone 0064 preparation:

- [PR body](0064-pr-body.md).
- [Standalone upstream patch](0064-llvm-mos.patch).
- [Destination and profitability review](0064-review.md).
- [Validation and retained evidence](0064-validation.md).

Compiler commit `155e209c4cee` is based on llvm-mos main `7bd67c0ae4e8` and
is [pushed to the fork branch](https://github.com/wbniv/llvm-mos/tree/mos-computed-carry-scheduling). [PR #609](https://github.com/llvm-mos/llvm-mos/pull/609) was closed at the user's request on September 27; its branch is retained. The destination was rechecked at `26d7c2c1eebf`; the recorded tests remain on `7bd67c0ae4e8`.
The exact patch passes ten focused commands, 132 MOS tests (one unsupported),
and 512 Python-oracle runtime vectors per build. The targeted MIR kernel
shrinks 133 → 59 bytes. The [September 27 upstream Clang run](0064-validation.md#full-upstream-clang-validation--september-27)
has 117 unchanged C-to-object pairs across three verified CPU selections.
The original fixed-IR census remains retained as 39 distinct 6502 configurations
repeated in 117 invocations; its IR CPU attributes overrode the backend CPU flag.
Downstream size losses remain documented. Author review is complete; no
independent review, cycle-speed or compiler-overhead claim is made.

This repository’s `carry-scheduling-preparation` branch publishes the downstream
0064 patch, plan, evidence and dependency updates. It starts from `b3938bda`
and preserves other work in the shared checkout. The other local posting
packets remain outside this commit.

Preparation and publication: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0dd01-d72e-76f2-bf27-a796e0f7d994`.
