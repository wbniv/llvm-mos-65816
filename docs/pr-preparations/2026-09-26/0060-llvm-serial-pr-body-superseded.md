# Superseded LLVM serial-fallback draft — September 26, 2026

This was a local, unposted preparation attempt. Current LLVM already rejects
parallel MIR input through upstream commit b1ba3d515a0238adbfc6c349ed3b33f9060cea72.
The proposed Delta-only fallback is unreachable from that advertised CLI input.
Retained unchanged draft follows; it is not a ready submission. See
[the current MOS backport draft](0060-pr-body.md) and
[the reconciliation review](reducer-feature-review.md#0060-current-upstream-reconciliation).

---

# [llvm-reduce] Keep MIR reduction on the serial work-item path

The parallel delta runner transports work items through LLVM IR bitcode. That
format does not retain MIR machine functions or their MachineModuleInfo. Asking
for multiple workers on a MIR input can therefore reach a null machine-module
state and crash, while the existing serial work-item clone preserves it.

Use the parallel path only for IR inputs. A MIR reduction with `-j > 1` follows
the existing serial cloning path, retaining machine functions and deterministic
reduction order. Parallel IR processing is unchanged. This is a correctness
fallback, **not an implementation of parallel MIR reduction**.

The X86 MIR regression requests one and two workers, checks the retained
interesting instruction, and compares the resulting MIR. Existing parallel IR
tests exercise the unaffected path. Exact-current LLVM validation is pending;
its final receipt must identify the compiler configuration, patch, and results
before this draft is promoted to ready.

The original defect was
reproduced while reducing a MOS register-allocation witness. An earlier local
candidate passed that input by cloning MIR work items in memory across workers.
The independent ownership review found that those
clones share contexts whose general thread safety was not established. No race
was reproduced; this submission deliberately takes the smaller serial fallback
without invalidating the earlier matching-input evidence. This draft is unposted.

Earlier witness investigation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort. Earlier parallel candidate: OpenAI Codex
API (tool version unknown), GPT-6 (exact model ID/version unknown), reasoning
effort unknown, as preserved in the canonical record.
Serial-fallback review and validation: OpenAI Codex CLI 0.157.1, model
`gpt-6-astra`, `xhigh` reasoning effort; reviewer session
`01a0db97-39fe-7452-bbab-73d26f1d19a9`.
Submission preparation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort; verified parent session
`01a0db16-f6a0-7e32-ada6-0c8098813933`.
