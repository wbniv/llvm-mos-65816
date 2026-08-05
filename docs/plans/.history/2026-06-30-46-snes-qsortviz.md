| Date | Change |
|------|--------|
| [2026-08-05](https://github.com/wbniv/llvm-mos-65816/commit/a45b67d) | snes: run qsort animation without added holds |
| [2026-08-05](https://github.com/wbniv/llvm-mos-65816/commit/b3f9c0c) | snes: animate qsortviz from live array mutations |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/b092a00) | docs: deepen #46 G_SCMP bug write-up + mark Round-3 battery complete |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/3c2c7a5) | #46 qsort Sort Visualizer SNES demo — caught + FIXED a real backend crash (G_SCMP) |

<!--history-meta v1
a45b67d	author	Will Norris
a45b67d	added	4
a45b67d	deleted	3
a45b67d	files	1
b3f9c0c	author	Will Norris
b3f9c0c	added	7
b3f9c0c	deleted	0
b3f9c0c	files	1
b092a00	author	Will Norris
b092a00	added	39
b092a00	deleted	0
b092a00	files	1
b092a00	body	- #46 qsortviz plan: add "Root-cause mechanism (three layers)" — clang canonicalizes\n  (x>y)-(x<y) to the newer llvm.scmp intrinsic (IR shown) -> generic G_SCMP opcode ->\n  MOSLegalizerInfo had no rule -> report_fatal_error. Why the one-line .lower() fix is\n  correct + minimal (routes to LegalizerHelper::lowerThreewayCompare; sits next to the\n  identical G_SMIN/SMAX/UMIN/UMAX handling).\n- Battery ideas tracker: Round 3 (#33-#52) banner flipped to COMPLETE (18/20 built;\n  #34/#35 non-buildable library/toolchain gaps), with the G_SCMP find called out.\n- Completion-status report: headline now Rounds 1-3; added the Round-3 coverage table\n  (18 shipped demos + the 2 non-buildable rows), the G_SCMP bug in "Bugs found",\n  corpus slice count 38->53, and a Round-4-needs-idea-list note.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
3c2c7a5	author	Will Norris
3c2c7a5	added	135
3c2c7a5	deleted	0
3c2c7a5	files	1
3c2c7a5	body	Demo #46 (a libc-qsort sort visualizer with a rotating function-pointer comparator)\ncaught a general backend crash: the standard C three-way-compare comparator idiom\n`return (x>y)-(x<y);` canonicalizes to the generic opcode G_SCMP, and the mos\nGlobalISel legalizer had NO rule for G_SCMP/G_UCMP:\n\n    fatal error: unable to legalize instruction: %N:_(s16) = G_SCMP ...\n\nIt fired in default 8-bit, +mos-a16 and +mos-xy16 alike, at every width, in both\nthe -fno-lto and the LTO-link path — i.e. any program sorting with a spaceship\ncomparator failed to build.\n\nFix (patches/llvm-mos/0016-mos-scmp-ucmp-legalize.patch): one line in\nMOSLegalizerInfo.cpp next to the analogous min/max lowering —\n    getActionDefinitionsBuilder({G_SCMP, G_UCMP}).lower();\nrouting to LLVM's existing LegalizerHelper::lowerThreewayCompare (icmp+select\nexpansion the backend already legalizes). Rebuilt toolchain.\n\nPost-fix: clean 5-way positive host==default==+mos-a16==+mos-xy16==0x8EA5 on\nbsnes-jg, -verify clean under a16 and xy16 (MAME leg SKIP — no SPC700 IPL on this\nbox). The gate folds sorted VALUES so it's independent of qsort tie-breaking.\nReproduces on plain -mcpu=mosw65816 C (not AS2/accum-gated) -> queued upstream in\ndocs/upstream-contribution-status.md. Live at https://biohack.net/snes/qsortviz/\n(biohack v1.0.163).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
