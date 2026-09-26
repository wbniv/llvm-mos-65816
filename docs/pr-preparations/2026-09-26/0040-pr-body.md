# [CodeGen][MOS] Keep scratch-vreg stack accesses during spill coalescing

`InlineSpiller::coalesceStackAccess` can erase a reload that defines an
early-clobber scratch virtual register in addition to its loaded value. The
scratch interval may already have a physical-register assignment. Removing
its defining instruction without removing that assignment leaves interference
at a slot index with no instruction; a subsequent greedy split fails in
`SplitEditor::enterIntvAfter`.

Decline this coalescing optimization when the access defines a virtual register
other than the register being spilled. The normal `spillAroundUses` path can
rewrite the loaded or stored value while keeping the scratch definition and
its allocator bookkeeping alive. The change does not alter accesses without
additional virtual definitions.

The regression pins the jump-table/64-bit-shift register-pressure shape at the
pre-greedy MIR boundary. It exercises stock `mos65c02` opcodes and passes input
MachineVerifier checks on current main. Both greedy-only and full-pipeline
replay reproduce the exact assertion on the current baseline. Spill hoisting
is disabled to isolate this contract from the separately tracked spill-hoist
scratch-vreg issue (0033); that repair is not a source or merge prerequisite.

Destination: `llvm-mos/llvm-mos`, based on
`7bd67c0ae4e8bb65a3f980912bf201df22131e34`. The source guard is generic, but this
package's causal regression uses MOS. No downstream native-width, far-pointer,
ABI, or SNES platform patch is required. The earlier IR-only reproducer depends
on a fork register-pressure shape; its historical validation is retained and
is not presented as a current stock-IR red test.

This packages the existing repair from commit
`03d3b33cb52607e1ba0ce30cb4c8afedd4daf174`; it is not a new defect discovery.
The retained independent review records exact inputs, binary and
patch hashes, historical red/green replay, and current isolated validation.
The exact candidate on main passes both regression RUNs and all MOS CodeGen/MC
suites: 132 passed, one existing unsupported test, no failures. The preserved
baseline fails on the same input with the intended SplitKit assertion.
Nothing has been posted.

Original attribution is retained as recorded: the original PR draft credits
Claude Code CLI (version unknown), Claude Fable 5.1 (`claude-fable-5-1`), `high`
reasoning effort. The implementation commit separately credits Claude Opus 5
(1M context); exact tool/version, model ID and effort for that commit credit
are unknown from the recovered metadata. These inconsistent historical credits
are not silently reconciled or reassigned.

Independent review and current-base extraction: OpenAI Codex CLI 0.157.1
(`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session
`01a0db97-39fe-7452-bbab-73d26f1d19a9`.

Fresh isolated build and validation: OpenAI Codex CLI 0.157.0 (`codex-tui`),
model `gpt-6-astra`, `xhigh` reasoning effort; verified session
`01a0db16-f6a0-7e32-ada6-0c8098813933`.
