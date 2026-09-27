# Simulated upstream PR — Preserve near addresses and full Y indices on 65816

**Internal preparation; held for the native-width compiler series.** Implementation is published downstream in [e370e031](https://github.com/wbniv/llvm-mos-65816/commit/e370e03153109aee2bef7b48b5917d870dec3744). This packet has author review; independent review and exact-destination extraction remain pending. PR #609 concerns computed-carry scheduling and was withdrawn at Will's request.

## Proposed PR body

The [SNES LZSS gallery](https://biohack.net/snes/lzss-gallery/) exposes two near-memory contracts in the 65816 backend. A split 16-bit Y load and indirect access allows an intervening X8 reload to clear Y's high byte. Separately, folding a negative near-pointer offset into unsigned indexed addressing can carry the access into the next bank.

Keep byte and word near accesses fused with their Imag16 Y-index load through allocation and width insertion. The pseudo defines all of Y16, retains memory operands, and expands to adjacent LDY and memory-access instructions. Word forms require both M=16 and X=16.

Fold a near pointer addition into native indexed addressing only when its unsigned sum cannot wrap: use NoUWrap, NoUSWrap with a nonnegative offset, or known-bits bounds. Otherwise materialize the 16-bit address first. Far pointer addressing retains its required bank-carry behavior.

The unchanged 62-work XY16 LTO benchmark fails on the preserved committed baseline and the fusion-only build, then returns `0x5CF0` with both repairs. A reduced decoder isolates Y lifetime with and without LTO. A second witness places different bytes in banks $7E and $7F and executes a signed -4 near offset: the fusion-only baseline returns `0xA5C3`, while the repaired build returns `0x5CF0`.

Validation passes all twelve decoder/bank-wrap configurations across default, A16 and XY16 modes, with and without LTO. The MOS CodeGen/MC suite has 178 passes, two unsupported and zero failures. The indirect-word and X-index runtime controls pass on MAME and bsnes-jg. The complete `0002` patch reconstructs the tested MOS source and focused tests. These results describe the downstream feature stack; an exact-upstream candidate remains to be extracted and validated.

## Review evidence

| Contract | Canonical record | Preserved evidence |
| --- | --- | --- |
| Full Y index survives allocation and width insertion | [Near-Y record](../../defects/mos-xy16-near-indirect-y-clobber.json) | [Baseline, fusion-only and final runs](../../defects/evidence/2026-09-27-near-y/) |
| Near arithmetic remains within DBR | [Bank-wrap record](../../defects/mos-near-index-bank-wrap.json) | [Matching-input bank witness](../../defects/evidence/2026-09-27-near-wrap/) |

The [causal investigation](../../investigations/2026-09-27-near-y-decoder.md) records source reconciliation, binary hashes, commands, the gallery stage diagnostic, and the optimization cost of losing an unsigned-wrap proof. Existing passing behavior on another build does not replace these preserved comparisons.

**Optimization follow-up (September 27):** [near-index proof recovery](../../investigations/2026-09-27-near-index-overflow-proofs.md) is implemented locally in `0002`. It preserves sound proofs after LSR and retains the bank-wrap guard. The proposed body and 178-test count above remain the earlier correctness-repair packet; the follow-up report carries its own census and validation. This addition still requires extraction and review with the native-width series. Update: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `high` reasoning effort; session `01a0e315-89ed-7e70-b7dc-fcc2940366d9`.

## Acceptance before submission

- [x] Reconcile prior patches, live source and tested binaries; preserve both causal baselines.
- [x] Publish the downstream implementation, regression fixtures and matching-input results.
- [ ] Reconcile the exact upstream destination's guards, callers, tests and history.
- [ ] Extract with the #321 native-width compiler and ABI prerequisites; retain the separate SNES platform submission gates.
- [ ] Validate the extracted patch and obtain independent review before an upstream opening decision.

Implementation, investigation, author review and packet preparation: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e061-3427-74a1-90ad-c0ee84b01b85`. Earlier evidence retains its original attribution.
