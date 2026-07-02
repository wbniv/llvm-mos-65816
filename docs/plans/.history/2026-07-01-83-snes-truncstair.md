| Date | Change |
|------|--------|
| [2026-07-01](https://github.com/wbniv/llvm-mos-65816/commit/8fada55) | wip(snes/truncstair): #83 surfaces a real ZP-allocation miscompile |

<!--history-meta v1
8fada55	author	Will Norris
8fada55	added	144
8fada55	deleted	0
8fada55	files	1
8fada55	body	Truncation Staircase (#83) targets G_FPTOSI/G_SITOFP (__fixsfsi/__floatsisf)\nas the truncf-via-cast pattern (floorf/ceilf/truncf are .unsupported() in the\nSDK). The differential gate surfaced a REAL COMPILER BUG — the success\ncondition of a stress-test demo, NOT worked around:\n\n  host / corpus / bare ROM : 0x02CA  (gate ZP frame @ $20)  CORRECT\n  full display ROM         : 0x1EB5  (gate ZP frame @ $69)  WRONG\n\nThe truncstair_gate_crc assembly is byte-identical between the passing (corpus)\nand failing (full-ROM) LTO builds — only the linker-assigned static ZP frame\nbase differs. Display-code ZP pressure pushes the gate's persistent frame from\n$20 to $69, where the 16-bit accumulator held across the soft-float call chain\nis corrupted. No ISR runs during the gate (snes_wait_vblank polls); no\nsoft-float callee writes $69-$74 (they use $7B-$7F). Whole-program-dependent\nZP-allocation/aliasing miscompile — suspect MOSZeroPageAlloc interference\nanalysis vs. the soft-float call tree.\n\nDiagnosis reached the 3-hypothesis debugging cap without a pinned fix; a fix\nneeds deeper MOSZeroPageAlloc tracing on a throwaway vendor/llvm-mos worktree +\na shared-toolchain rebuild. Demo left in natural form so the bug reproduces\n(NOT papered over with static/noinline/volatile, which merely relocate the\nframe). Full diagnosis in the plan; minimal repro under docs/plans/spikes/.\nNOT published until the compiler is fixed. G_FPTOSI/G_SITOFP codegen itself is\ncorrect (corpus is bit-exact).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
