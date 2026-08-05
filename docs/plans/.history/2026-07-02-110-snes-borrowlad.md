| Date | Change |
|------|--------|
| [2026-07-02](https://github.com/wbniv/llvm-mos-65816/commit/8915348) | feat(snes/borrowlad): #110 Borrow-Ladder Odometer (Round 6, Cluster E, harden 0012) |

<!--history-meta v1
8915348	author	Will Norris
8915348	added	80
8915348	deleted	0
8915348	files	1
8915348	body	Re-stresses patch 0012 (LDCImm-set): a 128-bit descending odometer (8x16-bit\nlimbs) built from chained 16-bit subtracts-with-borrow whose carry-in is a\nset/clear i1 (SEC / LDCImm 1) before the SBC chain, borrows rippling limb to\nlimb as the number ticks down through zero. The a16/xy16 legs are load-bearing\n(0012 accum-gated).\n\nClean positive, fix holds: sbc=4 preceded by sec=1 (the set-i1 carry-in that\n0012 materializes), rep/sep=14; host==default==+mos-a16==+mos-xy16==0x1BE3 on\nMAME+bsnes-jg, -verify clean x3. Renders a 128-bit binary counter ticking down.\n\nPublished: https://biohack.net/snes/borrowlad/\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
