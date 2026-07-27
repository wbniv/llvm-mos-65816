| Date | Change |
|------|--------|
| [2026-07-27](https://github.com/wbniv/llvm-mos-65816/commit/4fc642c) | feat(snesgfx): backdrop_gradient.h — reusable HDMA backdrop vignette; trimerge first consumer |
| [2026-07-27](https://github.com/wbniv/llvm-mos-65816/commit/ab35c87) | fix(trimerge): atomic single-v-blank field flush — close the waterfall tear |
| [2026-07-27](https://github.com/wbniv/llvm-mos-65816/commit/bc83003) | feat(trimerge): #99b visual rework — waterfall braid + stride-unit offset + palette breathing |

<!--history-meta v1
4fc642c	author	Will Norris
4fc642c	added	40
4fc642c	deleted	1
4fc642c	files	1
4fc642c	body	New library helper (hdma_hscroll.h conventions: header-only, generic chan,\ncaller owns write-only HDMAEN): BDROP_SPAN/BDROP_END declare a static ROM\ntable, bdrop_arm(chan, tab) points mode-3 HDMA at $2121 — per-scanline\nCGRAM colour-0 gradient, zero per-frame CPU, zero v-blank budget. trimerge\narms ch7 post-title with a 28-band (8-line) vignette (16-line first cut was\nvisibly stripey); breathe_palette now pushes cgidx 1..3 since HDMA owns\ncolour 0. Gate PASS 0xCCCC (scmp probe intact), tear check ATOMIC with HDMA\nactive, backdrop samples ramp smoothly. Published biohack.net v1.0.288.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
ab35c87	author	Will Norris
ab35c87	added	43
ab35c87	deleted	0
ab35c87	files	1
ab35c87	body	User-reported tearing: the band painter marked each 4-row band dirty as it\npainted, flushing bands in separate v-blanks while the waterfall shifted\nthe whole field -> marching shear boundary 15x/s. field_band now paints the\nshadow only; the sweep-boundary branch marks the whole canvas dirty once\nthe shadow completes -> one atomic 4 KB flush (4440 B worst-case v-blank\nincl. HUD+CGRAM, budget 5100 B; CANVAS_FLUSH_TILES 256 prevents re-split).\nGate re-run PASS (0xCCCC, scmp probe intact); new tear check in the plan:\nconsecutive-frame canvas diffs are full-span (121 px) or nil, 500..507.\nSite: biohack.net v1.0.286.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
bc83003	author	Will Norris
bc83003	added	106
bc83003	deleted	0
bc83003	files	1
bc83003	body	The published field was measured static (105 B framebuffer delta over 6.7 s\n= HUD digits only): the old (phase+r)*7 offset step is 4 orders of magnitude\nbelow one stream stride (0x10001), so no merge decision ever flipped and the\nemit-both branch never fired. Display-only rework: offset steps in whole\nstride units (64-phase cycle, ties fire -> yellow cells), 16-row waterfall\nhistory (one merge/sweep, newest at top), +/-2/32-luma palette breathing\n(8 B CGRAM job/sweep). Gate unchanged: 0xCCCC, llvm.scmp=4 incl. s64 still\ncontrol flow; liveness now 29.4% delta/60 frames with all three branch\ncolors live. Published biohack.net v1.0.284 (manifest off 0x20 -> 0x39).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
