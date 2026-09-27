# MOS null output streamer crash

**Upstream extraction validated:** the [standalone packet](../pr-preparations/2026-09-27/0068-validation.md) passes on upstream `26d7c2c1eebf` with only the null-streamer change: 21 baseline null-output crashes become successes, all 24 ordinary outputs stay byte-identical, and 133 MOS tests pass with one unsupported. Independent review and publication remain pending. The earlier downstream evidence below is retained as dated validation.

Extraction and validation: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `high` reasoning effort; verified session `01a0e315-89ed-7e70-b7dc-fcc2940366d9`.

The diagnostic-only failure retained by [0064 validation](../pr-preparations/2026-09-26/0064-validation.md) is isolated and fixed by [patch 0068](../../patches/llvm-mos/0068-mos-null-output-streamer.patch). The canonical record is [mos-null-output-streamer-crash](../defects/mos-null-output-streamer-crash.json).

`llc -mtriple=mos -mcpu=mos6502 -debug-pass=Structure -filetype=null arith.Os.ll` created LLVM's generic null `MCStreamer`. MOS had registered target streamers for assembly and ELF output, but not for null output. `MOSAsmPrinter::emitStartOfAsmFile` unconditionally obtains the target streamer, casts it to `MOSTargetStreamer`, and emits zero-page directives. The absent target streamer made that cast dereference null during `AsmPrinter::doInitialization`. Ordinary object emission used the registered ELF streamer and passed.

Patch 0068 registers a `MOSNullTargetStreamer`. Its directive and finalization methods discard output; its `finish` override discards finalization work. On the inspected upstream revision the generic finalizer uses virtual section queries and symbol-reference methods; ELF-specific behavior resides in the ELF subclass. The regression runs the diagnostic null-output path and normal object emission.

The preserved baseline `llc` (SHA256 `f215e4d24f07a5e6720de665f5fdbda4b6b537aac021c55bbe14678f53af8331`) crashes on the retained `arith.Os.ll` with exit 139. The rebuilt `build/llvm-mos/bin/llc` (SHA256 `a82d0ac480d5a217aedeec05a87e10b079011952c04908c0ff4375d31271deeb`) completes that same input with exit 0. The new lit regression passes, and the same IR emits an object successfully. Commands, source and preprocessed C, exact IR, tool hashes, container identity, and logs are retained under `../defects/evidence/2026-09-27-mos-null-output/`.

The original September 27 candidate is the downstream build in the `llvm-mos-65816-dev` container, not a clean rebuild of the historical 0064 upstream candidate. This record therefore establishes the failure mechanism and matching-input result for the preserved baseline and patched downstream build; it does not itself establish the separate upstream artifact validated in the follow-up linked above.

Attribution: OpenAI Codex agent via API (version unknown), exact model name/ID and version unknown, reasoning effort unknown from accessible session metadata.
