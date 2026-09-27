# [MOS] Register a target streamer for null output

`llc -filetype=null` still runs the MOS assembly printer. Its initialization expects a `MOSTargetStreamer` to emit target directives, but the null output path had no MOS target-streamer registration and supplied LLVM's generic null streamer instead.

Register a MOS null target streamer that accepts the directives used during initialization and discards output. Override finalization because the base MOS streamer uses ELF-specific behavior. Add a regression that runs diagnostic null emission and ordinary object emission.

The preserved regression input crashes on the recorded baseline and passes with the patched downstream build. The focused MOS lit test passes in the `llvm-mos-65816-dev` container. The historical upstream candidate was not rebuilt with this patch, so the validation establishes the matching-input result for the preserved baseline and the patched downstream build only.

Implementation and validation assistance: OpenAI Codex agent via API (version unknown), exact model name/ID and version unknown, reasoning effort unknown from accessible session metadata.
