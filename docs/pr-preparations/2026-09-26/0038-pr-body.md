# [MOS] Legalize llvm.returnaddress and llvm.frameaddress

Both intrinsics currently reach an unsupported-intrinsic legalization error. Implement level zero using the MOS calling convention's separate hardware and software stacks; return null for higher levels because neither stack has a frame chain.

`llvm.frameaddress(0)` produces the incoming software-stack pointer through a fixed frame object at offset zero. Existing frame-index lowering handles both fixed and dynamically sized frames without forcing an otherwise unnecessary frame pointer. This address does not describe locals allocated on MOS's static stack.

`llvm.returnaddress(0)` reads the two-byte return word from the hardware stack and adds one for the 6502 family, matching JSR/RTS. SPC700 CALL already pushes the return address, so its result is not incremented. Interrupt handlers return null. The result is a 16-bit pointer, not a bank-inclusive far return address.

The legalizer emits two side-effecting byte-read operations. Selection reserves the accumulator and, where needed, scratch X before register allocation. A late pass then computes hardware-stack depth across the CFG, including callee-saved pushes and temporary spills, and expands the reads only after frame lowering and scavenging. The 6502/SPC700 path uses the stack-pointer transfer and indexed-load forms; 65816 uses stack-relative loads. Conflicting incoming stack depths are diagnosed rather than silently selecting an offset.

Three regression files cover 6502 at O0/O2, 65816, SPC700, reads displaced by callee-saved pushes, unsupported levels, interrupt handlers, and frame addresses with and without a frame. A late-pass MIR test also checks a predecessor push, a local push between the two reads, and a balanced loop back edge.

This is the existing 0038 repair from commit `2adc7e7799d8146321f62cac26507f6c1eff7909`, rebased for llvm-mos `7bd67c0ae4e8bb65a3f980912bf201df22131e34`; it is not a new defect discovery. The implementation is unchanged. Preparation adds the depth MIR test and clarifies two contract comments. It has no SNES platform or downstream native-width feature prerequisite.

Independent replays confirm all four original regression RUNs fail on the preserved pre-repair compiler and a clean current-main compiler for unsupported intrinsic legalization, and pass on the preserved assertions-enabled repaired compiler. The added depth MIR passes there as well. These retained tools are not themselves a new current-main candidate build. Fresh isolated validation on the exact base above is now complete: five focused RUNs pass, and the full MOS CodeGen/MC suites report 134 passed, one existing unsupported test, and no failures. Exact patch, input, and binary hashes plus logs are retained in the local preparation receipt.

The earlier September 23 validation also records 15 repaired c-torture compilations, 4,119 unchanged successful assembly pairs, and SNES emulator execution of three relevant torture programs. Two further programs had target-inappropriate premises, documented against the generated ROMs; they are not counted as runtime passes. These are dated integrated-stack results, not standalone current-main measurements.

SPC700 has a separate existing late-optimization defect for `LDImm` into an imaginary register (patch 0003 / PR #584). The original regressions here do not hit it, but an additional signed-return-address comparison does. Replaying 0003's own regression reproduces that failure on both historical compilers; the integrated compiler carrying 0003 passes. This patch does not repair or claim closure of that separate defect.

Unposted draft. Exact patch identity and independent review are retained in the local preparation packet.

Original attribution preserved as recorded in the September 23 PR draft: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`), `high` reasoning effort, for design, implementation, tests, validation, and drafting. Independent review, current-main extraction, additional MIR regression, and this draft: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified agent/session `/root/review_mos` / `01a0db96-e0ef-75e2-89ad-2939c4954446`.

Fresh isolated build and validation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0db16-f6a0-7e32-ada6-0c8098813933`.
