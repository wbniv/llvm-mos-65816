# [CodeGen][MOS] Reject spill hoists that need scratch virtual registers

MOS can fail with `Remaining virtual register` when greedy register allocation
hoists a spill. `HoistSpillHelper::hoistAllSpills` runs after the allocation
queue has drained, but it calls `storeRegToStackSlot` again. The MOS hook can
introduce scratch virtual registers: soft-stack spills need an Imag16 frame
address, and some static-stack spills also need temporaries. Those registers
have no subsequent allocation opportunity.

Reject a hoist group if the emitted instructions reference a virtual register
other than the value being spilled. Discard its inserted instructions and keep
the original spills; the `NumSpills` statistic is only updated once a group is
kept. Groups whose hooks need no extra virtual registers remain eligible. Remove the MOS driver's blanket `-disable-spill-hoist`, so the same
check governs both driver compilations and direct `llc` use.

The regression is reduced from `gcc.c-torture/execute/950714-1.c`. It exercises
a soft-stack spill through both enabled and disabled hoisting paths. With
hoisting enabled, pristine upstream asserts; this change compiles it with
MachineVerifier clean.

Validation against llvm-mos `742d554bf08042b8df93d791c335260fadd16643`:

- Independent assertion-enabled build with this patch alone: the reduced test
  passes; the unpatched compiler also passes it with hoisting disabled.
- The same standalone build passes 84 MOS CodeGen tests (one unsupported) and
  all 46 MC tests. Complete X86/ARM/AArch64 CodeGen suites: 11,436 pass and
  23 expected failures, with no unexpected failures.
- Regenerating the 18 affected C-torture compilations with the pinned frontend
  clears the original virtual-register failure in all 18. Sixteen complete;
  `ashrdi-1.c` at `-O2` and `-Os` subsequently reaches an independent scavenger
  assertion. An integration build carrying the scavenger fix completes all 18.
- Stacked assertion build with the current revision: the reduced test passes
  with hoisting enabled and disabled; MOS CodeGen and MC 141 pass, 1
  unsupported; X86/ARM/AArch64 CodeGen suites 11,460 tests: 11,436 pass, 23 expectedly fail, none fails (the AArch64 GlobalISel directory, 785 tests, rerun after a CHECK spelling fix to the new test: all pass).
- A saved integration comparison of guarded hoisting enabled versus disabled
  has 4,109 successful pairs and 61 failures on both sides. Sixteen compilations
  change; independently reassembled `.text` totals fall from 290,375 to 285,865
  bytes, with no increases. This comparison holds the compiler and its other
  MOS fixes constant.

Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`,
`high` reasoning effort) for diagnosis, implementation, tests, and initial
validation and drafting.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`, `xhigh`
reasoning effort) for independent review, standalone validation, and corrections
to the analysis and submission evidence.
