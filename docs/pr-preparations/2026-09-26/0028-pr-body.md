# [CodeGen] Preserve undefined-lane definitions in allocated identity copies

A full virtual-register copy defines every destination lane, including lanes whose source subranges are undefined. After allocation makes both operands the same physical register, erasing that copy can discard the only definition of a lane read later. The subsequent machine verifier then rejects otherwise valid machine SSA.

Keep lane state local to a per-instruction rewrite and retain an allocated identity copy as a zero-code KILL when it carries the required lane definition. Ordinary redundant copies remain removable; the existing undef-source and implicit-definition behavior is preserved. This is the previously tested refactor, not a new alternative algorithm.

The X86 regression explicitly enables subregister liveness. It defines AL, copies the full AX virtual value, consumes AH with MOVZX, and returns EAX. Six companion cases cover normal identity deletion, already-undef copies, partial definitions, nonidentity copies, and instruction-local state. These are MIR contract tests, not evidence of a naturally generated stock C trigger.

The originating downstream workloads include the published SNES [L-System Plant](https://biohack.net/snes/lsystem/) and [Newton Fractal](https://biohack.net/snes/newton/) demos. Those pages provide application context; the retained inputs and MIR verifier checks establish the compiler contract, not the demo runtime alone.

The original MOS bitboard and coalescing witnesses remain in their canonical evidence records; they are two sightings routed through this existing repair, not separate new upstream defects. The preparation packet identifies the selected implementation, independent review, source base, and exact test runs.

The exact standalone LLVM package (`f312c1c59d31b7ee00fccbc21d529f449bf3938e9aa2f89c36c855bf0d15d8c2`) was built on LLVM `e59a0c697552ae7d1c3aeed5774e829cdc5e16b5` in Release mode with assertions enabled. The baseline rejects the matching MIR for an undefined physical AH use after identity-copy removal; the candidate passes both focused RUNs, including all six companion cases. Filtered AArch64/X86 allocation/spill suites pass 102 tests with one unchanged expected failure and no unexpected failures. These are filtered suites, not full-target or runtime coverage. The retained local preparation receipt identifies the patch, compilers, inputs, configuration, commands and logs; the final independent audit verified their hashes. The technical build/test gate is complete.

Local publication hold: this draft remains held for the separately recorded #320/#321 presentation. The generic patch and X86 regression do not depend on SNES implementation code. Nothing has been posted.

Earlier contributors' credits remain in the original 0028 investigation and canonical defect records; this draft does not reassign their implementation. Submission extraction: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0db16-f6a0-7e32-ada6-0c8098813933`. Independent implementation and X86 regression review: OpenAI Codex CLI 0.157.1, model `gpt-6-astra`, `xhigh` reasoning effort; session `01a0db96-a6cd-7800-82a5-6b871eb7e177`. Current LLVM build/test execution: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; coordinator session recorded above.
