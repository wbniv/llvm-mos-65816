| Date | Change |
|------|--------|
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/ee7e1a4) | docs(plan): far-font plan completed end-to-end after the codegen fix |
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/fd79934) | snes: far-rodata FONT16 attempt — codegen bug found, infra landed, demo unchanged |

<!--history-meta v1
ee7e1a4	author	Will Norris
ee7e1a4	added	17
ee7e1a4	deleted	0
ee7e1a4	files	1
ee7e1a4	body	Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
fd79934	author	Will Norris
fd79934	added	96
fd79934	deleted	0
fd79934	files	1
fd79934	body	Goal was to keep the real 16x16 Waldo font on mandel-double instead of the\nchunky pixel-doubled fallback, by parking the 4 KB FONT16 table in bank $01\nfar rodata. The mechanism is sound and the infra works, but the font renders\nWRONG under realistic register pressure, so the demo is left as-is for now.\n\nWhat landed (all inert unless opted into):\n  - font16.h / gen-font16.py: FONT16_STORAGE macro. Under TITLE_FONT16_FAR the\n    table gets section(".far_rodata") + address_space(2); otherwise byte-for-byte\n    `static const` as before. Emitted by the generator so a regen keeps it.\n  - build.sh / rebuild-web-roms.sh / mandel-double.sh: honour a `snes-far-platform`\n    source marker to pick mos-snes-far.cfg, same discipline as the existing\n    `mos-a16-only` marker. A linker config cannot be a #define, so it must be\n    discoverable by EVERY build path rather than living in one script's table --\n    that drift is what made this demo unbuildable in the first place (0467e5b).\n\nThe bug (docs/investigations/2026-07-26-far-rodata-read-under-pressure-title-upload.md):\nfar FONT16 renders wrong -- fft loses line 1 entirely, mandel-double shows solid\nbars. The gate CRC still PASSES both times, because corpus_result comes from the\ndemo's math and never from the title; only a rendered screenshot catches it.\n\nIsolated by changing one variable at a time, each build actually rendered:\n  fft / snes      / near font  -> correct\n  fft / snes-far  / near font  -> correct   (platform is NOT the cause)\n  fft / snes-far  / FAR font   -> line 1 missing\n  mandel-double   / FAR font   -> line 1 solid bars\n\nNot the far read itself: standalone ROMs reading a 4 KB far table return\nhost-exact CRCs -- constant indices (0xACDB), the exact nested computed-index\nfont loop shape (0x2776), and that same loop with an interleaved volatile store\nstanding in for REG_VMDATA (0x2776). Placement is right too (FONT16 at 0x18000,\ncorrect glyph bytes in the ROM), and the emitted sequence reads correct on\ninspection (two `lda [__rc20]` byte loads assembled, then rep #32, 16-bit\nsta $2118). Hypothesis is register pressure -- a far pointer needs a 4-byte\nImag32 __rc quad, and the synthetic repros are tiny leaf loops while the real\nupload sits inside _title_reserve (0x57b) in a large program. Project Lesson 1.\n\nmandel-double keeps TITLE_FONT16_OFF (chunky title) until this is root-caused;\nverified still green after reverting: RESULT PASS, 0x0EDF on bsnes-jg.\nFor bulk VRAM data the better route regardless is DMA straight from the far bank\n(REG_A1B0 takes a source bank, as mode7.h already does), avoiding CPU far loads.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
