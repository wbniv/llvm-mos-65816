# [MOS] Preserve 16-bit immediate width in printed machine instructions

An Immediate16 machine opcode can contain a plain small constant. The assembly printer currently emits that constant without its width, so an assembler that does not track M/X state selects the two-byte immediate form. With a 16-bit register mode at runtime, the processor consumes the next opcode as operand data and instruction boundaries no longer agree.

Print ambiguous Immediate16 operands through `mos16(...)`. Keep unambiguous constants from 256 through 65535 bare and preserve existing explicit modifiers. Do not change 8-bit operands or the HuC6280 block-length operand, which has no narrower form in its operand slot.

The regression starts from stock MOS machine opcodes, without downstream native-width IR lowering. It covers ADC, EOR, CMP, LDA, LDX, and LDY immediate forms and an 8-bit ADC control. Besides checking the printed text, it compares direct object emission with reassembly byte for byte. Stock MC already honors `mos16` for immediate operands; neither the separate address-parser fix (0039) nor the long-address printer (0044) is a prerequisite.

This extracts the existing 0045 repair, originally exercised through the downstream native-width compiler. It is not a newly discovered compiler defect. The historical repair is recorded in the September 24 far-addressing audit, section 6.3, and commit `77524e40`. The local preparation packet retains the independent review and exact-current baseline/candidate identities. Unposted.

Original implementation: commit `77524e40`, credited there to Claude Opus 5 (1M context); actual tool/version, exact model ID/version, and reasoning effort are unknown from the recovered record. That credit is retained, not reassigned. Extraction and submission preparation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0db16-f6a0-7e32-ada6-0c8098813933`. Independent stock-MIR extraction review: OpenAI Codex CLI 0.157.1, model `gpt-6-astra`, `xhigh` reasoning effort; session `01a0db97-39fe-7452-bbab-73d26f1d19a9`.

Validation: an isolated Release build with assertions enabled on llvm-mos main `7bd67c0ae4e8bb65a3f980912bf201df22131e34` passes 7 focused regression RUN commands and the full MOS CodeGen/MC suites: 132 passed, one existing unsupported test, no failures. No other candidate patch is applied. The same regression fails on the preserved baseline and passes with this change. Exact input, patch, binary hashes, and logs are retained in the local packet.
