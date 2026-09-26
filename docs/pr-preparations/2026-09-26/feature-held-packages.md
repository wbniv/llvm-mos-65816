# Reviewed feature-dependent work: preparation does not remove its gates

Updated 2026-09-26. These are existing local changes, not new bug reports.
Nothing in this packet authorizes posting or includes a SNES platform submission.
The standalone package index distinguishes opening readiness from merge order.
The gates here concern unresolved compiler/ABI extraction or an explicit user
publication hold, not merely waiting for another PR to merge.

| Existing change | Reviewed contract and evidence | Remaining opening gate |
|---|---|---|
| 0013 far-memory intrinsic routing | Same retained 4096-byte memset input fails without the routing and passes with it; fresh archived runtime replay confirmed. Far-pointer routing uses the far runtime symbols. | A coherent #320/#321 compiler/ABI and far-runtime package. The unconditional i16 length truncation is only justified in the recorded ≤65535 domain; no unrestricted wider-length memcpy/memmove claim. |
| 0028 undef-lane identity copies | Selected refactor; generic X86 MIR and six companion contracts pass exact-current LLVM validation (two RUNs, 102 filtered suite passes / one XFAIL). | The user's recorded #320/#321 presentation hold remains even though the generic source/test no longer requires MOS. |
| 0051 byte-index decomposition | Fixes a same-width G_TRUNC introduced in the downstream zero-page split. Stock upstream already uses buildZExtOrTrunc and passes the input. | Carry with the native-width lowering that introduces this path; do not report a stock-upstream bug. |
| 0052 far-section relaxation | Fixes downstream suppression of near-section relaxation when a symbol's addend crosses a bank. | Extract with #320's address-space/section policy; stock upstream does not contain the broken policy. |
| 0055 wide any-extension | Preserved masked narrow-count input discriminates optimized native baseline/candidate runs. O0/default and simple wide MIR controls pass both and do not prove the fix. | #321 native-width legalizer/ABI submission. |
| 0061 global long,X selection | Unsigned byte/proven word offsets, access width, and side effects reviewed; focus tests and existing emulator evidence retained. | Exact source requires #320 and #321, including Xc16/XLow/HasIndex16 infrastructure. Earlier #320-only queue dependency was incomplete. |
| 0062 native far word operations | Reviewed long, long,X, and indirect forms; byte ABI/volatile ordering retained in controls. | #320/#321 plus 0061; separate measurable compiler extraction. |
| 0063 near stores shared with increment | Reviewed ABI A:X byte-store sharing for literal +1. Canonicalized decrement uses G_ADD -1 and correctly falls back to native operations. | #321; advertise increment-only optimization. Generalized decrement profitability is not implemented by this patch. |

The independent [native-fix review](native-fix-review.md) and
[optimization review](native-optimization-review.md) record exact commands,
binary identities, original evidence, and the fresh test boundaries. Prior
measurements that compare against hand-written assembly remain dated opportunity
measurements, not measurements of savings from these exact extracted patches.

0049 is a backport of prerequisites already present on current upstream; 0053
is test-expectation maintenance. Neither is a new standalone compiler repair.
The historical far-pointer failure behind 0023 still lacks its original input
and failing compiler; no passing reconstruction closes that report.

The original far-memset and native-width repair credits stay in their canonical
records and investigations. Preparation and scope reconciliation: OpenAI Codex
CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified
session `01a0db16-f6a0-7e32-ada6-0c8098813933`. Independent reviews name their
own verified agent/tool/version/model/effort in the linked records.
