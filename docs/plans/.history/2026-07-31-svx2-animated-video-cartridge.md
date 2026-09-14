| Date | Change |
|------|--------|
| [2026-08-03](https://github.com/wbniv/llvm-mos-65816/commit/f536d25) | docs(svx2): record animated-cartridge plan verification (6/7 PASS) |
| [2026-08-01](https://github.com/wbniv/llvm-mos-65816/commit/21179d7) | feat(snes): prove SVX2 60 fps pipeline |
| [2026-08-01](https://github.com/wbniv/llvm-mos-65816/commit/79bb73b) | Keep SVX2 dashboard active across video cut |
| [2026-07-31](https://github.com/wbniv/llvm-mos-65816/commit/427632a) | snes: combine both Artemis video corpora |
| [2026-07-31](https://github.com/wbniv/llvm-mos-65816/commit/bd344a1) | snes: ship complete 300-frame SVX2 reel |
| [2026-07-31](https://github.com/wbniv/llvm-mos-65816/commit/d71d298) | Add animated SVX2 video cartridge |

<!--history-meta v1
f536d25	author	Will Norris
f536d25	added	185
f536d25	deleted	0
f536d25	files	1
f536d25	body	Ran the plan's seven verification gates against main @ 1feca62. Gates 1-6\npass on the delivered 900-frame two-video Fast HiROM cartridge. Gate 7 fails:\nthe plan's recorded LoROM ROM 825e3848 exists nowhere, the gate builds\nf741e49a, and the gallery serves 8 MiB c3d7cd9e from the 59.94 fps successor.\nA preliminary also fails - the 4-frame LoROM configuration no longer compiles\n(snes-video-reel.c references VIDEO_REEL_HIROM_BASE_BANK unconditionally,\nwhich the non-packed-far asset path never emits; suspected bd344a1).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
21179d7	author	Will Norris
21179d7	added	2
21179d7	deleted	0
21179d7	files	1
79bb73b	author	Will Norris
79bb73b	added	2
79bb73b	deleted	2
79bb73b	files	1
427632a	author	Will Norris
427632a	added	5
427632a	deleted	4
427632a	files	1
bd344a1	author	Will Norris
bd344a1	added	14
bd344a1	deleted	2
bd344a1	files	1
d71d298	author	Will Norris
d71d298	added	149
d71d298	deleted	0
d71d298	files	1
-->
