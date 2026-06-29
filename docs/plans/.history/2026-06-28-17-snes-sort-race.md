| Date | Change |
|------|--------|
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/f8aff1c) | feat(snes): #17 Sorting Race demo — quicksort/heapsort/mergesort recursion stress |

<!--history-meta v1
f8aff1c	author	Will Norris
f8aff1c	added	162
f8aff1c	deleted	0
f8aff1c	files	1
f8aff1c	body	Demo #17 of the compiler stress-test battery: the recursion / soft-stack /\nframe-ABI member. Recursive sr_qsort + sr_msort (noinline) force the reentrant\nsoft-stack spill path (an array pointer lives across the self-jsr — the\na16spillr.c machinery in a real workload); iterative sr_hsort is the\nnon-recursive contrast. On-screen animation is record/replay (each sort emits an\nop-log of position:=value stores; the ROM replays 1 op/algo/frame, repainting\ntouched columns) so GENUINE recursion stays the compiler stress while three bar\narrays race to sort in real time.\n\nGate: sortrace_gate_crc() folds 8 rounds, each asserting all three sorts agree\non the identity permutation, then folding each algorithm's cmps^moves.\ndev/run.sh sort-race RESULT PASS — host == bsnes-jg 0xB28F; disasm gate\nrecursion(sr_qsort/sr_msort refs=695) + cmp=44 + rep/sep=233, zero 32-bit\nlibcalls; default/+mos-a16/+mos-xy16 -verify-machineinstrs clean. MAME leg SKIPs\n(env-wide SPC700 IPL absent; non-blocker per the 2026-06-28 demos policy).\n\nFiles: examples/65816/sort-race.h, examples/snes/sort-race.c,\nexamples/snes/corpus/sort-race_sim.c, tools/sort-race-sim.c, dev/sort-race.{sh,lua},\nTaskfile.yml, TODO.md, docs (plan + demo-ideas strike).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
