# MOS null output streamer crash

The diagnostic-only failure retained by [0064 validation](../pr-preparations/2026-09-26/0064-validation.md) is isolated and fixed by [patch 0068](../../patches/llvm-mos/0068-mos-null-output-streamer.patch). The canonical record is [mos-null-output-streamer-crash](../defects/mos-null-output-streamer-crash.json).

`llc -mtriple=mos -mcpu=mos6502 -debug-pass=Structure -filetype=null arith.Os.ll` created LLVM's generic null `MCStreamer`. MOS had registered target streamers for assembly and ELF output, but not for null output. `MOSAsmPrinter::emitStartOfAsmFile` unconditionally obtains the target streamer, casts it to `MOSTargetStreamer`, and emits zero-page directives. The absent target streamer made that cast dereference null during `AsmPrinter::doInitialization`. Ordinary object emission used the registered ELF streamer and passed.

Patch 0068 registers a `MOSNullTargetStreamer`. Its directive and finalization methods discard output; its `finish` override avoids the ELF-specific finalizer in `MOSTargetStreamer`. The regression runs the diagnostic null-output path and normal object emission.

The preserved baseline `llc` (SHA256 `f215e4d24f07a5e6720de665f5fdbda4b6b537aac021c55bbe14678f53af8331`) crashes on the retained `arith.Os.ll` with exit 139. The rebuilt `build/llvm-mos/bin/llc` (SHA256 `a82d0ac480d5a217aedeec05a87e10b079011952c04908c0ff4375d31271deeb`) completes that same input with exit 0. The new lit regression passes, and the same IR emits an object successfully. Commands, source and preprocessed C, exact IR, tool hashes, container identity, and logs are retained under `../defects/evidence/2026-09-27-mos-null-output/`.

The candidate is the current downstream build in the `llvm-mos-65816-dev` container, not a clean rebuild of the historical 0064 upstream candidate. This record therefore establishes the failure mechanism and matching-input result for the preserved baseline and patched downstream build; it does not claim a separately rebuilt upstream PR artifact.

Attribution: OpenAI Codex agent via API (version unknown), exact model name/ID and version unknown, reasoning effort unknown from accessible session metadata.
