| Date | Change |
|------|--------|
| [2026-07-27](https://github.com/wbniv/llvm-mos-65816/commit/bc83003) | feat(trimerge): #99b visual rework — waterfall braid + stride-unit offset + palette breathing |

<!--history-meta v1
bc83003	author	Will Norris
bc83003	added	106
bc83003	deleted	0
bc83003	files	1
bc83003	body	The published field was measured static (105 B framebuffer delta over 6.7 s\n= HUD digits only): the old (phase+r)*7 offset step is 4 orders of magnitude\nbelow one stream stride (0x10001), so no merge decision ever flipped and the\nemit-both branch never fired. Display-only rework: offset steps in whole\nstride units (64-phase cycle, ties fire -> yellow cells), 16-row waterfall\nhistory (one merge/sweep, newest at top), +/-2/32-luma palette breathing\n(8 B CGRAM job/sweep). Gate unchanged: 0xCCCC, llvm.scmp=4 incl. s64 still\ncontrol flow; liveness now 29.4% delta/60 frames with all three branch\ncolors live. Published biohack.net v1.0.284 (manifest off 0x20 -> 0x39).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
