# Upstream PR preparation — 2026-09-20

**Published:** MVN/MVP block-move bank order — [compiler PR #604](https://github.com/llvm-mos/llvm-mos/pull/604).
Research also produced a separate **common-SDK longjmp zero-value fix**. The BRL optimization
proposal was evaluated and withdrawn because its claimed size/cycle benefit does
not apply to the 65816.

- [Validated patch](mvn-mvp.patch) and [validation evidence](validation.md): five targeted checks pass; MOS suites 130 pass, one unsupported.
- [Rendered PR mockup with patch diff](mvn-mvp-pr-preview.html).
- [MVN/MVP title](mvn-mvp-title.txt) and [description](mvn-mvp-body.md).
- [Regression source](65816-block-move-bank-order.s): unequal immediate banks,
  object disassembly, symbolic relocation offsets, and forward-defined constants.
- [BRL assessment](brl-assessment.md) and [byte-count input](brl-cost.s).

Upstream base: `742d554bf08042b8df93d791c335260fadd16643` (current `main`, fetched
2026-09-20). The isolated preparation checkout is `/tmp/llvm-mos-next-prs`, branch
`mos-65816-mvn-bank-order`, commit
`ae3108c3189076607b12fd5ff514a21678df8c8b`. Published on branch `wbniv:mos-65816-mvn-bank-order`; PR #604 is open for review.

The prepared MVN/MVP change fixes immediate bank order and symbolic-fixup offsets.
The downstream source and carried patch `0020` now include the same complete fix
and regression. See [downstream validation](mvn-downstream-validation.md).

## Separate simulator discussion and media provenance

The MVN/MVP PR contains only the encoding fix, supporting context, and regression
results. It contains no emulator proposal, maintainer questions, or execution-test
commitment. Its readiness is independent of simulator work.

A separate, unposted discussion is prepared: [title](65816-simulator-discussion-title.txt),
[body](65816-simulator-discussion-body.md), and
[rendered preview](65816-simulator-discussion-preview.html). It covers prior work,
runner choice, test location, CI provisioning, result/timeout conventions, and a
proposed asset-free bank-copy test. [Research](emulator-discussion-research.md).
No execution harness has been implemented or discussion published.

The description links the live SVX2 demo page, without a direct ROM-download link
or a media-rights paragraph. For any future test that includes video assets,
[NASA footage provenance and reuse verification](nasa-video-provenance.md) records
the Artemis and Apollo sources, U.S. public-domain status, NASA credit and
non-endorsement conditions, and that source audio is excluded. These media notes do
not add video assets to the compiler patch.

## Additional SDK candidate

[PR mockup with diff](sdk-longjmp-pr-preview.html), [title](sdk-longjmp-zero-title.txt),
[patch](sdk-longjmp-zero.patch), [draft description](sdk-longjmp-zero-body.md),
[simulator matrix](sdk-longjmp-matrix.txt), and
[reproducer](../../investigations/repro/upstream-issues-2026-09-20/longjmp-zero.c).
**Posted:** [SDK PR #450](https://github.com/llvm-mos/llvm-mos-sdk/pull/450) — open for review, head `0f8ad11589f5`.
The patch includes SDK CMake/CTest integration and
passes all 20 tests with a fresh current-SDK library/simulator build. Without the
fix, all four zero cases fail. [Integrated validation](sdk-longjmp-validation.md).
It has no SNES dependency; the downstream SNES override is not changed here.
