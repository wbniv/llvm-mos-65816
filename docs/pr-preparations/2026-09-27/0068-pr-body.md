# [MOS] Supply a target streamer for null output

MOS registers target streamers for assembly and object emission, but not for null output. `llc -mtriple=mos -filetype=null` still runs `MOSAsmPrinter::emitStartOfAsmFile`, which unconditionally emits zero-page directives through the missing target streamer. The assembler's `.zeropage` directive also needs this interface during null emission.

Register a `MOSNullTargetStreamer` whose directives and finalization are no-ops. Add CodeGen and MC regressions for successful null emission and normal object emission.

Validated on llvm-mos `26d7c2c1eebf`: 21 null-output cases fail with SIGSEGV on the unpatched baseline and succeed with this change across 6502, 65C02, and stock 65816. All 24 ordinary object/assembly comparisons are byte-identical. The MOS CodeGen and MC suites pass 133 tests with one existing unsupported test. The extraction has no native-width, far-pointer, or SNES platform prerequisite.

Original diagnosis and downstream repair: OpenAI Codex agent via API; tool version, exact model name/ID and version, and reasoning effort unknown from that work's accessible session metadata.

Current-upstream reconciliation, extraction, validation and author review: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `high` reasoning effort; verified session `01a0e315-89ed-7e70-b7dc-fcc2940366d9`.
