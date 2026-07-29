| Date | Change |
|------|--------|
| [2026-07-28](https://github.com/wbniv/llvm-mos-65816/commit/66d59c9) | docs(gallery): root-cause notes for the work-0 repack divergence; #137 step 6 is FAIL |

<!--history-meta v1
66d59c9	author	Will Norris
66d59c9	added	144
66d59c9	deleted	0
66d59c9	files	1
66d59c9	body	The lzss-gallery "Verify fidelity" selfcheck cannot be pointed at gallery_last_z\nyet: the ROM recompresses great-wave to 15254 bytes against its own embedded\nlz_len of 15305, so gallery_last_ok = 0.\n\nRecords what is now ruled out, correcting an earlier hypothesis:\n\n- The images WERE palette-remapped. Both 3e3f054 (223-colour) and dcc80d9\n  (221-colour) regenerated .idx/.lz/.pal, lzss-gallery-assets.h and\n  derived/report.json in the same commit. No asset-vs-oracle desync.\n- Host side is self-consistent: GALLERY_ASSETS[0] is great_wave at 15305 and\n  report.json[0] is great-wave at 15305, in the same array order.\n- Not a mis-indexed artwork: no work in the 62-work corpus compresses to 15254.\n- Not a cancelled compress: compress_far returns 0 on nav_cancel, and 15254 is\n  non-zero, so it is a complete run.\n\nLeading hypothesis is that the compressed buffer is wrong rather than the codec:\nthe main loop is entered with decoded = 1, so work 0 skips unpack_slide and\nrepacks whatever FB_A already held, and record_result rewrites gallery_last_z\nwithout advancing gallery_progress on a revisit -- which explains the previously\nunexplained 0x3B96 -> 0x3B98 drift for a single artwork. A deterministic\ncompressor cannot emit two lengths for identical input, so the input varies.\n\nAlso demotes #137 from "verification not yet run" to step 6 FAILS: 200 000\nframes completes only 22 of 62 works, and the manifest frames value doubles as\nthe in-browser verify budget, so it cannot simply be raised to ~710 000.\n\nTwo follow-up TODO items (the divergence itself, and lsystem's BLANKSCAN) are\nleft for ranking -- adding tiers is T5 and reserved for Fable.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
