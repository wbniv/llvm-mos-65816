# Independent review of extracted 0065

September 28, 2026. **Approve 0065 for upstream review with the explicit native-width prerequisites in this packet.** No blocking correctness finding remains in the reviewed optimization or its extraction. The September 26 approval of 0063 was not used as approval of 0065.

## Exact scope

Reviewed destination `26d7c2c1eebf98ca194b92609ba4e7540bfc6ef6` and the three frozen patches recorded in [series.json](evidence/series.json). Final candidate commit: `75926742e3e13e26a17ef6e7837efb869caec0dc`; tree: `508a36dbcb01dba15c0372430767fb2337e0fc04`. Patch hashes and every independent compiler/FileCheck command are retained in [the review evidence](evidence/independent-review.json).

The first patch supplies the compiler subset of #321 needed to expose and validate 0065; the second supplies 0063; the third carries 0065 and two additional independent regression files. This review does not approve the entire #321 feature, native LLDB integration, #320, or SNES platform submission. Stock destination source has no native profitability entry point until the prerequisites are applied.

## Contracts checked

- Atomic stores are rejected before splitting or arithmetic-coordinated replacement. The added tests retain one unordered word access alongside increment and decrement.
- Indirect decrement emits an observed replacement at the original store, keeps its memory operand, and narrows the arithmetic. Machine verification and literal `G_SUB` tests exercise the replacement worklist behavior.
- Volatile byte loads precede the low/high destination stores. Alias and returned-call-result controls retain their original values and memory order.
- Only zero-size call-frame teardown is skipped. Nonzero teardown, calls, inline assembly, cross-block values, multiple stores and native consumers keep the guarded fallback.
- Loaded destination pointers fail the Imag16 argument-copy predicate and retain native lowering. The [September 27 loaded-pointer experiment](../../../defects/evidence/2026-09-27-near-store-profitability/loaded-pointer/results.json), including its 17-byte native versus 22-byte split result, remains dated evidence from its original tools.
- Extraction preserves destination vector scalarization, wide-constant/INT64_MIN protection and default byte-mode sign fill. Far address spaces, packed pointers, far calling conventions, Imag32, far memory operations, the independent proof-recovery pass and SNES platform code are excluded.

## Independent execution

Both frozen backends report optimized LLVM 24 builds with assertions. Every compiler invocation enables machine verification.

| Backend | Five focused files × three modes | Result |
|---|---:|---|
| Before 0065 | 15 | 11 pass; four expected FileCheck failures |
| Candidate | 15 | All pass |

The four expected failures are the original 0065 IR test and the literal-subtraction MIR test in a16 and xy16. Compilation itself succeeds: the baseline retains native stores/arithmetic where the checks require the new profitable sequences. Atomic and nonzero-frame controls pass on both backends. The two earlier byte-store regression files also pass in all modes.

Eleven additional control functions compile to assembly, pre-legalizer MIR and legalized MIR in all three modes: **nine successful invocations**. Twenty-four checks of the two native MIR outputs confirm atomic word accesses, volatile byte-store metadata, call/asm/cross-block fallback, two-store fallback, loaded-pointer decrement fallback and an actual 24-byte outgoing call frame. The full control input is embedded in the evidence JSON.

Compiler SHA-256:

```text
48d63dfbff695fe0f6bf2684ddbd84722420b74c0780fe8c4b7397e015b5dbfe  pre0065 llc
f1597923f6cea0e42f6377e16bf5da70ae7318f89b0ab0b61d4a7a2b7d446d56  candidate llc
```

This reviewer did not rerun the full MOS suite, measurement corpus or emulators. Those coordinator executions and the [original local completion](../../../plans/2026-09-27-broader-near-store-profitability.md) retain their separate evidence and attribution.

## Findings resolved and remaining limitation

The extracted native register definitions initially retained obsolete DWARF numbers. The final artifact assigns A16/X16/Y16 to `0x01000000/1/2` and leaves internal high-byte pieces unmapped, matching the [official MOS DWARF specification](https://www.llvm-mos.org/wiki/DWARF_specification). The official page's indexed content was retrieved through web search; direct fetching returned HTTP 403. Native LLDB volatility and unwinding behavior were not validated here.

Imported historical comments were rewritten as current contracts. The measurement driver rejects empty inputs and empty parsed output. Reviewed runtime-driver calls now match the MAME and bsnes-jg helper APIs, including their different argument order and WRAM addressing.

One nonblocking formatting finding remains in the frozen prerequisites: a new blank line at the end of `MOSFeatures.td`. Patch application succeeds with a whitespace warning; `git diff --check` reports that same line. The frozen patch hashes were retained.

## Attribution

Independent source and extraction review, additional boundary tests, final compiler replays and this review: **OpenAI Codex CLI 0.158.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort**, agent `/root/review_0065`, verified session `01a0e79c-b9af-7ed3-acf5-19074d8d761a`. The reviewer's own session metadata and turn context establish these values. Earlier implementation, measurement and review credits remain in their original records.
