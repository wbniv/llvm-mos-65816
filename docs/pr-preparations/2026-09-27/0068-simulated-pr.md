# Simulated upstream PR — Register a MOS target streamer for null output

**Local submission preview; not submitted.** This draft describes [patch 0068](../../../patches/llvm-mos/0068-mos-null-output-streamer.patch). The [canonical defect record](../../defects/mos-null-output-streamer-crash.json) and [investigation](../../investigations/2026-09-27-mos-null-output-streamer.md) retain the matching-input evidence and validation limits.

## Proposed PR body

`llc -filetype=null` still runs the MOS assembly printer. Its initialization expects a `MOSTargetStreamer` to emit target directives, but the null output path had no MOS target-streamer registration and supplied LLVM's generic null streamer instead.

Register a MOS null target streamer that accepts the directives used during initialization and discards output. Override finalization because the base MOS streamer uses ELF-specific behavior. Add a regression that runs diagnostic null emission and ordinary object emission.

The preserved regression input crashes on the recorded baseline and passes with the patched downstream build. The focused MOS lit test passes in the `llvm-mos-65816-dev` container. The historical upstream candidate was not rebuilt with this patch, so the validation establishes the matching-input result for the preserved baseline and the patched downstream build only.

Implementation and validation assistance: OpenAI Codex agent via API (version unknown), exact model name/ID and version unknown, reasoning effort unknown from accessible session metadata.

## Validation record

| Check | Result |
| --- | --- |
| Preserved baseline, diagnostic null emission | Crashes with exit 139 during `AsmPrinter::doInitialization` |
| Patched downstream build, same IR and command | Passes with exit 0 |
| Patched downstream build, ordinary object emission | Passes |
| Focused `filetype-null.ll` lit regression | Passes in the project container |

Evidence, exact commands, compiler hashes, and qualification are in the [defect evidence bundle](../../defects/evidence/2026-09-27-mos-null-output/) and [investigation](../../investigations/2026-09-27-mos-null-output-streamer.md). The candidate is not a clean rebuild of the historical upstream extraction, and no upstream submission or independent review is claimed.

## Simulated review

The reproduced failure has a direct registration mismatch: MOS assembly-printer initialization unconditionally uses its target streamer, while null emission creates a generic streamer unless the target registers one. The new streamer supplies the required MOS interface but emits no output; its no-op finalizer avoids invoking ELF-specific finalization. The regression covers both the failing diagnostic-only path and ordinary object output.

The matching-input red/green result and focused regression support the repair for the recorded downstream source and build. Before presenting this as an upstream-ready change, extract it against the exact destination revision and rerun the preserved reproducer and regression there. That review and extraction have not been performed.

Implementation, simulated review, and packet preparation: OpenAI Codex agent via API (version unknown), exact model name/ID and version unknown, reasoning effort unknown from accessible session metadata.
