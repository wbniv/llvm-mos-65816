# [MOS] Complete and check the fixup information table

The `Fixups` enum contains AddrAsciz but the metadata table omits its initializer. The explicitly sized array silently supplies a zero-filled tail entry, including a null name. Add the missing named row in enum order, infer the array bound, and assert that its length equals `MOS::NumTargetFixupKinds`.

AddrAsciz deliberately has offset, size, and flags zero: its decimal-string width is supplied at the directive call site, not by an instruction operand. It must not request instruction relaxation. Existing object-writing paths already handle its contents directly, so this is a latent metadata-invariant repair, not a demonstrated runtime miscompile.

The compile-time assertion guards omitted rows; review still needs to check ordering. Existing directive tests are positive controls and pass on both sides. No failing runtime regression is claimed for this metadata-only change. It has no dependency on native-width or SNES support. Unposted.

Earlier recorded investigation and drafting: Claude Code CLI (version unknown), model `claude-sonnet-5`, `high` reasoning effort. Compile-time invariant and independent review: OpenAI Codex CLI 0.155.1, model `gpt-6-astra`, `xhigh` reasoning effort. Original credits remain unchanged in their records. Submission preparation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0db16-f6a0-7e32-ada6-0c8098813933`.

Validation: an isolated Release build with assertions enabled on llvm-mos main `7bd67c0ae4e8bb65a3f980912bf201df22131e34` passes the compile-time invariant and the existing MOS CodeGen/MC suites: 131 passed, one existing unsupported test, no failures. No other candidate patch is applied. Existing tests pass on both sides; no runtime failure is claimed for the latent metadata omission. Exact input, patch, binary hashes, and logs are retained in the local packet.
