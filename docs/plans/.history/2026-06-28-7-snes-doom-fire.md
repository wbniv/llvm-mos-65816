| Date | Change |
|------|--------|
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/32a4114) | feat(snes): #7 Doom-fire / heat-field demo — array sweep + PRNG, palette ramp |

<!--history-meta v1
32a4114	author	Will Norris
32a4114	added	118
32a4114	deleted	0
32a4114	files	1
32a4114	body	Demo #7 of the compiler stress-test battery. The classic PSX-Doom fire: a\n32×28 heat grid rises and flickers from a constant max-heat source row through\na 16-colour black→red→orange→yellow→white CGRAM ramp on BG1 4bpp (one solid\ntile per cell, half-tilemap DMA split over 2 frames).\n\nDeliberately the multiply-/divide-FREE member of the battery — the hot loop is\na flat-index 8-bit array sweep (lda/sta (zp),y over a variable write offset)\nplus a 16-bit xorshift16 PRNG per non-zero cell (native eor/asl/lsr under one\nrep/sep bracket). It exercises indexed array bandwidth + the PRNG, the corners\nthe arithmetic demos (rdiff/n-body/spigot) don't hit.\n\nShared host+target header examples/65816/doom-fire.h (fire_step + xorshift16 +\ndoomfire_gate_crc). No far pointers ⇒ full 5-way bar. Verified:\n  dev/run.sh doom-fire RESULT PASS — host oracle == bsnes-jg corpus_result\n  0x3C59 (16×16 gate grid, 30 steps); disasm gate eor=6 asl/lsr=8 rep/sep=21,\n  zero __mulsi3/__udivmodsi4. bsnes-jg framebuffer shows textbook rising fire.\n  MAME leg SKIPped (SPC700 IPL absent — env-wide non-blocker, demos-only policy).\n\nFiles: examples/65816/doom-fire.h, examples/snes/doom-fire.c,\nexamples/snes/corpus/doom-fire_sim.c, tools/doom-fire-sim.c,\ndev/doom-fire.{sh,lua}, docs/plans/2026-06-28-7-snes-doom-fire.md + tracking.\n(Taskfile.yml + expected.tsv doom-fire rows landed in 9f3d71e — a concurrent\nagent's git add swept them into the #18 maze commit; content is correct.)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
