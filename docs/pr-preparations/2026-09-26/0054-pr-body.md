# Recheck target save feasibility when extending a scavenger spill range

The backward scavenger search checks `canSaveScavengerRegister` when choosing a survivor. It can subsequently extend the save point over earlier virtual-register instructions without checking whether the larger range is still legal for the target. On MOS, this can cross one side of a push/pull pair while both index registers are live, leaving no valid way to preserve the status register.

Require the target hook to accept each proposed extension. If the extension is not saveable, keep the most recent valid range. Targets using the always-true default hook retain their search behavior.

The MIR regression keeps both index registers and carry live around a temporary carry value inside a balanced accumulator push/pull pair. It checks that status preservation remains inside the balanced range and verifies the resulting machine instructions. The upstream test runs on stock `mosw65816` without `+mos-a16` or `+mos-xy16` and uses the existing `scavenger-test` harness, whose contract accepts block-local scratch virtual registers. The first scratch value ends before X/Y become live, isolating status-save range extension from an unrelated GPR spill. Independent checks also pass on mos6502 and mos65c02.

This PR targets **llvm-mos**, not llvm/llvm-project: despite the generic source path, current LLVM does not contain the `canSaveScavengerRegister` hook. It does not require a new native-width compiler feature or SNES platform submission.

This repairs save-range feasibility, not the separate existing live-N/Z assertion in MOS's nested GPR/status preservation (local repair 0011). A balanced nested-save control still reaches that assertion on both current upstream and this candidate. The regression isolates the range contract rather than claiming that all scavenger failures are repaired by this change.

The original downstream regression and runtime evidence is retained. The focused runtime checked output bytes `6, 6, 7, 1` on bsnes-jg; the local posting package records the separate stock-upstream validation and exact artifact identity without relabeling that earlier evidence. The new MIR is an isolated backend contract test, not a fresh execution of that old ROM.

Implementation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; original recorded session `01a0d7d4-5da2-7fe0-a88c-0137eaa043a7`. Submission preparation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0db16-f6a0-7e32-ada6-0c8098813933`.

Validation: an isolated Release build with assertions enabled on llvm-mos main `7bd67c0ae4e8bb65a3f980912bf201df22131e34` passes 1 focused regression RUN commands and the full MOS CodeGen/MC suites: 132 passed, one existing unsupported test, no failures. No other candidate patch is applied. The same regression fails on the preserved baseline and passes with this change. Exact input, patch, binary hashes, and logs are retained in the local packet.
