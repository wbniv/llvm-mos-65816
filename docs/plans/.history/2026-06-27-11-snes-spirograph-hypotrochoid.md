| Date | Change |
|------|--------|
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/80ff596) | #11 spirograph: tune EPI scale to fit the canvas (golden 0xB8AA->0x32D4) |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/8d0fe7d) | #11 spirograph: (R,r,d) parametric rose demo on snesgfx (full 5-way bar) |

<!--history-meta v1
80ff596	author	Will Norris
80ff596	added	13
80ff596	deleted	13
80ff596	files	1
80ff596	body	The epitrochoid's amplitude is R+r (vs R-r for the hypotrochoid), so at the\nshared shift its outer lobes ran ~76-88 px from centre and clipped the 64 px\nhalf-canvas. Give EPI its own shift (SPIRO_EPI_SHIFT=10) so the full figure\nstays on-canvas — now a clean ring of interlocking loops.\n\nThe gate hash shifts with it: 0xB8AA -> 0x32D4 (expected.tsv, the demo\nself-verify, dev/spirograph.lua default, docs). Re-verified:\n  - dev/run.sh corpus-a16  9/9 (spiro_sim 0x32D4, spiro_ctrl_sim 0x6A26).\n  - dev/run.sh spirograph  RESULT PASS (disasm gate, bsnes 3x byte-identical,\n    MAME+bsnes screenshots == host 0x32D4).\nThe hypo/rose/Lissajous figures and the bloom visual are unchanged (the demo\nboots HYPO; its screenshot SHA is identical).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
8d0fe7d	author	Will Norris
8d0fe7d	added	426
8d0fe7d	deleted	0
8d0fe7d	files	1
8d0fe7d	body	Demo #11 of the compiler stress-test battery: the Spirograph (hypotrochoid),\nthe sin/cos-LUT + fixed-point-multiply member. Four curve families (hypo /\nepi / rose / Lissajous) bloom into a NEAR 2bpp bitmap canvas, joypad-interactive\nwith an on-screen (R, wheel, pen, mode, petals) HUD.\n\nBecause the canvas is near (bank-0 WRAM, no far pointers) it builds default-8bit\nAND +mos-a16 AND +mos-xy16, earning the full 5-way differential bar.\n\nCodegen under test (examples/65816/spiro.h, the shared host+target math): a\nsin/cos-LUT pair + two 16x16->32 __mulsi3 + 32-bit add/shift per point, plus a\ngear-ratio __udiv per parameter change. Confirmed by the disasm gate.\n\nNew reusable snesgfx pieces:\n  - bitmap_canvas.h  — software plot surface: set-pixel + Bresenham line into a\n                       2bpp tile shadow, capped dirty-tile DMA on BG3.\n  - text_layer.h     — BG3-cotenant tiled text HUD (reuses font8.h).\n\nVerification:\n  - dev/run.sh corpus-a16  9/9: spiro_sim 0xB8AA (curve math) + spiro_ctrl_sim\n    0x6A26 (controller + HUD-format math), host==default==+mos-a16==+mos-xy16\n    on MAME + bsnes-jg, -verify-machineinstrs clean. (spiro_ctrl_sim is the\n    deterministic-scripted-input equivalent of a JGX replay.)\n  - dev/run.sh spirograph  RESULT PASS: disasm gate (__mulsi3+__udiv+rep/sep),\n    bsnes-jg 3x byte-identical, MAME + bsnes-jg screenshots == host 0xB8AA.\n\nFiles: examples/65816/spiro.h, examples/snes/spirograph.{c,h},\nsnesgfx/{bitmap_canvas,text_layer}.h, font8.h, corpus/spiro_{sim,ctrl_sim}.c,\ntools/{spiro-sim.c,gen-font8.py}, dev/spirograph.{sh,lua}. Publish to\nhttps://biohack.net/spirograph/ pending user OK.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
