| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/b8a70be) | #321 xy16: mark merge-back checklist all-done (post-rebase push) |
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/c2812d4) | #321 xy16: implement Layers 1-5 of +mos-xy16 (16-bit index register mode) |
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/aa53d03) | #321 xy16: handoff doc — worktree setup, build steps, Layer order, merge-back checklist |

<!--history-meta v1
b8a70be	author	Will Norris
b8a70be	added	8
b8a70be	deleted	8
b8a70be	files	1
b8a70be	body	Rebased onto main (no conflicts). Post-rebase full suite: fuzz 50/50,\ncorpus 7/7, xy16basic/spill/spillr all PASS. Pushed to origin/wt/321-xy16.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
c2812d4	author	Will Norris
c2812d4	added	190
c2812d4	deleted	99
c2812d4	files	1
c2812d4	body	All five build layers compile clean under -verify-machineinstrs:\n\nLayer 1 — Feature flag (FeatureIndex16 / +mos-xy16, implies +mos-a16):\n  MOSFeatures.td, MOSInstrFormats.td (HasIndex16 predicate),\n  MOSSubtarget.h (HasIndex16 member + hasIndex16() accessor).\n\nLayer 2 — X/Y 16-bit register definitions and instruction pseudos:\n  MOSRegisterInfo.td: XH, YH, X16, Y16 registers (nums 0x500-0x503,\n    above all Imag ranges), Xc16/Yc16 register classes.\n  MOSInstrLogical.td: XLow/XHigh TSFlag bits added to MOSLogicalInstr\n    base class (critical: extends Instruction, not Inst, so needs them\n    explicitly); full xy16 instruction set — LDXAbs16/Imag16/Imm16,\n    STXAbs16/Imag16, CPXAbs16/Imag16/Imm16, INX16, DEX16, Y variants,\n    TXA16/TAX16/TYA16/TAY16 (transfer pseudos, both MLow=1 + XLow=1).\n\nLayer 3 — X-flag parallel lattice in MOSInsertREPSEP.cpp:\n  Complete rewrite of the file with dual (M + X) lattices running in the\n  same fixpoint iteration. Key invariant: requiredXWidth() returns XW_None\n  for all X-agnostic ops (LDAbs16, STAbs16, …); only XLow=1, XHigh=1, and\n  call/return are non-None. Combined REP/SEP #$30 emitted when both flags\n  switch to the same mode simultaneously.\n\nLayer 4 — Xc16/Yc16 spill cases:\n  MOSInstrInfo.cpp: Xc16 → LDXAbs16/STXAbs16, Yc16 → LDYAbs16/STYAbs16\n    in loadStoreRegStackSlot (static-stack path).\n  MOSRegisterInfo.cpp: IsXc16/IsYc16 declarations + extended pointer-forming\n    guard + Xc16 (TXA16+STAIndir16/LDAIndir16+TAX16) and Yc16 (TYA16+…/…+TAY16)\n    cases before the Imag16 split in expandLDSTStk (soft-stack path).\n\nLayer 5 — selectXY16 skeleton in MOSInstructionSelector.cpp:\n  selectXY16() stub (returns false), called when STI.hasIndex16(); wired for\n  M2 legalizer integration (full X/Y-index selection is a follow-on).\n\nTest infrastructure:\n  examples/65816/xy16basic.c + dev/xy16basic.sh: +mos-xy16 smoke — feature\n    flag accepted, implies +mos-a16 (rep/stz/sep fires), no spurious rep/sep\n    #$10 for X-agnostic ops, corpus_result==0x0042 on both emulators.\n  examples/65816/xy16spill.c + dev/xy16spill.sh: static-stack Ac16 spill\n    gate under +mos-xy16 (compile-time, no emulator).\n  examples/65816/xy16spillr.c + dev/xy16spillr.sh: soft-stack Ac16 spill\n    gate + value test — corpus_result==0x3457 on both emulators.\n  tools/a16_fuzz.py: +mos-xy16 differential track added — verify-machineinstrs\n    under XY16, compile xy16 ROM, xy16@MAME in comparison dict; compile_rom()\n    and verify_machineinstrs() take explicit flags lists (backward-compatible).\n  dev/run.sh: registers xy16basic, xy16spill, xy16spillr targets; updates fuzz\n    description to mention the three-track differential.\n\nPlan audit addenda (docs): design corrections 8 (XW_None default) and 9\n  (X-dimension fixpoint maps) added to xy16-index-register-mode.md; handoff\n  doc revised to lead with the plan audit.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
aa53d03	author	Will Norris
aa53d03	added	160
aa53d03	deleted	0
aa53d03	files	1
aa53d03	body	Briefing for the next agent: why the worktree exists (main regression isolation),\nhow to bootstrap vendor/ + ccache, Layer 1-5 implementation order, commit\ndiscipline, key risks from the pre-audited plan, and merge-back checklist.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
