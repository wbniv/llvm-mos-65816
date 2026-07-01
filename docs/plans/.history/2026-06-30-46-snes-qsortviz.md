| Date | Change |
|------|--------|
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/3c2c7a5) | #46 qsort Sort Visualizer SNES demo — caught + FIXED a real backend crash (G_SCMP) |

<!--history-meta v1
3c2c7a5	author	Will Norris
3c2c7a5	added	135
3c2c7a5	deleted	0
3c2c7a5	files	1
3c2c7a5	body	Demo #46 (a libc-qsort sort visualizer with a rotating function-pointer comparator)\ncaught a general backend crash: the standard C three-way-compare comparator idiom\n`return (x>y)-(x<y);` canonicalizes to the generic opcode G_SCMP, and the mos\nGlobalISel legalizer had NO rule for G_SCMP/G_UCMP:\n\n    fatal error: unable to legalize instruction: %N:_(s16) = G_SCMP ...\n\nIt fired in default 8-bit, +mos-a16 and +mos-xy16 alike, at every width, in both\nthe -fno-lto and the LTO-link path — i.e. any program sorting with a spaceship\ncomparator failed to build.\n\nFix (patches/llvm-mos/0016-mos-scmp-ucmp-legalize.patch): one line in\nMOSLegalizerInfo.cpp next to the analogous min/max lowering —\n    getActionDefinitionsBuilder({G_SCMP, G_UCMP}).lower();\nrouting to LLVM's existing LegalizerHelper::lowerThreewayCompare (icmp+select\nexpansion the backend already legalizes). Rebuilt toolchain.\n\nPost-fix: clean 5-way positive host==default==+mos-a16==+mos-xy16==0x8EA5 on\nbsnes-jg, -verify clean under a16 and xy16 (MAME leg SKIP — no SPC700 IPL on this\nbox). The gate folds sorted VALUES so it's independent of qsort tie-breaking.\nReproduces on plain -mcpu=mosw65816 C (not AS2/accum-gated) -> queued upstream in\ndocs/upstream-contribution-status.md. Live at https://biohack.net/snes/qsortviz/\n(biohack v1.0.163).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
