| Date | Change |
|------|--------|
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/0034e3c) | #321: collapse the SNES Mandelbrot demos into one far/16-bit tester |

<!--history-meta v1
0034e3c	author	Will Norris
0034e3c	added	174
0034e3c	deleted	0
0034e3c	files	1
0034e3c	body	Delete the separate mandel-mode7 (128x128 far Mode 7) and mandel-interactive\n(baked-image joypad fly-around) demos, and convert the canonical tester\nexamples/snes/mandel-display.c to far / +mos-a16-only so the publish gate now\nexercises the 24-bit far-pointer path (sta [dp] / lda [dp]).\n\nmandel-display now far-stores its 64x56 escape buffer into high WRAM ($7E2000)\nand far-loads it back for the VRAM reveal + CRC, keeping the same 64x56 N=15 grid\nso the host-oracle CRC is unchanged (0x204F). Differential PASS: host == bsnes-jg\n== MAME == 0x204F (dev/run.sh mandel-shot, 5800 frames); disasm gate confirms one\nsta [dp] (87) + two lda [dp] (A7) emitted.\n\n- Removed: examples/snes/{mandel-mode7.c, mandel-interactive.c, view.h}, the\n  generated mandel_image.h, tools/mandel-bake.c, dev/mandel-{mode7,interactive}.sh.\n- mode7.h: pruned the now-dead vbuf/32KiB-DMA/instant-boot helpers; kept the Mode 7\n  setup + tilemap + matrix setters mandel-display uses.\n- dev/build.sh: dropped the mandel_image.h bake step (mandel-bake.c is gone).\n- dev/jgxcheck.cpp: excised the JGX_VIEW input-differential path (it #included the\n  removed view.h; only the deleted mandel-interactive.sh built it).\n- Release gate (release-test-inner.sh): mandel-display now forces a16-only\n  (default-8bit can't legalize the far G_PTR_ADD); k_mandel still builds both.\n- Taskfile/run.sh: removed mandel-mode7 / mandel-interactive / mandel-play tasks +\n  help; fixed mandel-mame ROM choices and the stale "fat-pixel"/0x9103 descs.\n- Docs: plan + TODO M2 entry; (removed)/consolidated notes in plan-index and the\n  graphics-rendering handoff (repointed to mandel-display as the far Mode 7 example).\n\nPlan: docs/plans/2026-06-26-collapse-the-snes-mandelbrot-demos-into-one-far-16.md\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
