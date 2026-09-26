# Patch 0037: indirect register outputs in GlobalISel inline-asm lowering

Found 2026‑09‑23 in the c-torture triage (order 2 in the
[triage table](../../upstream-pending-work.md#backend-failure-triage-gcc-c-torture-2026-09-23)):
`asm("" : "+g"(x))` fails with `unable to translate instruction: call` in 10
compilations (`pr65053-1`, `pr65053-2`, `pr65956`, `pr88904`).

- [x] Root cause: Clang lowers `+g` to `"=*imr,0"`. `InlineAsmLowering` picks the register
  alternative for the indirect output but never stores it back through the pointer, then rejects
  the call because the indirect output is counted as a missing call result (`ResRegs=0,
  OutputOperands=1`). SelectionDAG stores such defs through the pointer (`DAG.getStore`, collected in `OutChains`).
- [x] Layer: generic `InlineAsmLowering`, not a MOS hook. The failure reproduces on AArch64 with
  `-global-isel -global-isel-abort=1`; X86's GlobalISel has no inline-asm lowering at all.
- [x] Fix: record the indirect operand's element type, keep indirect register outputs out of the
  direct-output accounting, and after the `INLINEASM` copy each def to the element type
  (truncating when the register is wider) and `G_STORE` it through the pointer with a memory
  operand on the pointer value.
- [x] Tests: `llvm/test/CodeGen/MOS/inline-asm-indirect-output.ll` (`"=*imr,0"` and `"=*r"`;
  MIR at the IR-translator boundary, verifier at `-O0`/`-O2`) and
  `llvm/test/CodeGen/AArch64/GlobalISel/inline-asm-indirect-output.ll` (same idiom plus an `i8`
  output in a 32-bit register for the truncating path).
- [x] Patch `patches/llvm-mos/0037-llvm-gisel-inline-asm-indirect-output.patch`; applies to the
  newer `~/llvm-mos` clone; comment-history check clean. Registered in `dev/toolchain.sh`.
- [x] Suites, corpus differential, project toolchain rebuilt, emulator gate.

## Results

Builds: `build/newton-postra-src` (pinned upstream + 0011, 0030, 0031, 0032, 0033, 0034, 0036,
then this change), assertion-enabled. `build/0030-claude-review/llc-0036` is the last binary
without it; `llc-asmg` the first with it; `llc-final` also carries the 0033 accounting revision
(a statistic only).

| Check | Result |
|---|---|
| MOS test on `llc-0036` / `llc-final`, each RUN line | FAIL ×3 / PASS ×3 |
| AArch64 test on `llc-0036` / `llc-final`, each RUN line | FAIL ×2 / PASS ×2 |
| The 4 torture files at `-O0/-O2/-Os` as IR through `llc-final` with the verifier | 12/12 clean |
| c-torture, 1,390 accepted files × `-O0/-O2/-Os`, `llc-0036` vs `llc-asmg` (`diff7`) | 10 repaired (`pr65053-1` `-O0`; `pr65053-2`, `pr65956`, `pr88904` all levels); 0 newly failing; 51 fail on both sides; 4,109 ok/ok pairs, all identical |
| same, `llc-0036` vs `llc-final` (`diff8`) | 10 repaired (same set); 0 newly failing; 51 fail on both sides; 4,108 ok/ok pairs, all identical; `pr92904` `-O0` hit the script's 120 s limit on the baseline side under load (55 s standalone, identical assembly on both binaries) |
| MOS CodeGen + MC, `llc-final` | 141 pass, 1 unsupported, 0 fail |
| X86 + ARM + AArch64 CodeGen suites, `llc-final` | 11,460 tests: 11,436 pass, 23 expectedly fail, 1 fail (the new AArch64 test, whose `i8`/`s8` CHECK spelling was corrected while the run was in flight; the AArch64 GlobalISel directory rerun on the committed content: 785/785 pass) |
| Project toolchain (vendor) + MAME/bsnes-jg corpus gate, first rebuild (0037 only added) | 79 of 79 programs pass (host == default == +mos-a16 == +mos-xy16 on MAME and bsnes-jg), 0 fail, 0 xfail |
| Project toolchain + gate, final rebuild (0037 + 0033 accounting + 0035 test/comment) | 79 of 79 programs pass (host == default == +mos-a16 == +mos-xy16 on MAME and bsnes-jg), 0 fail, 0 xfail |

The `barrier` function in the MOS test compiles at `-O2` to a store of the tied input through the
alloca and a reload, which is what SelectionDAG produces for the same IR on other targets.

Artifacts under `build/0030-claude-review/`: `diff7.py` / `diff7-results.json` / `diff7/`,
`diff8.py` / `diff8-results.json` / `diff8/`, `suite-asmg.out`, `suite-final.out`,
`lit-final-*.json`, `build-asmg3.log`, `build-hoist2.log`, `toolchain-asmg.log`,
`corpus-a16-asmg.log`, `toolchain-final.log`, `corpus-a16-final.log`.

**Independent review complete:** [audit](0037-review-audit.md). No implementation
revision requested. Fresh 0037-only MOS/AArch64 GlobalISel suites: 915 pass, one
unsupported; all 12 focused corpus compilations pass. The combined cross-target
run plus named-test rerun totals 11,437 passes and 23 expected failures.
The [llvm/llvm-project submission variant](0037-llvm-project.patch) contains the
generic source change and AArch64 test. Current-main applicability remains to
be checked before submission.

Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`,
`high` reasoning effort) for diagnosis, implementation, tests, initial validation, and PR drafting.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`, `xhigh`
reasoning effort) for independent review, standalone validation, submission extraction, and evidence corrections.
