| Date | Change |
|------|--------|
| [2026-07-27](https://github.com/wbniv/llvm-mos-65816/commit/673cb42) | fix(demos): atomic single-v-blank flush for the 19 per-band tearing demos (F1 batch A) |
| [2026-07-27](https://github.com/wbniv/llvm-mos-65816/commit/0a5e007) | docs(investigation): 60 fps demo sweep — full static+empirical table, fix batches |

<!--history-meta v1
673cb42	author	Will Norris
673cb42	added	31
673cb42	deleted	3
673cb42	files	1
673cb42	body	The 60fps sweep found 19 cell-grid band painters marking dirty per band —\ntrimerge's pre-#99b tearing bug, verbatim (identical marking blocks). Patch\n= the #99b change applied by exact-match replacement: painter no longer\nmarks; sweep-boundary full-marks the canvas -> one <=4 KB DMA in one\nv-blank. Verified on a fresh full rebuild, all 19: map-derived selfcheck ==\nmanifest want, and atomicity holds (<=1 canvas-changing pair in 5; per-band\nwould change all). Republish rides the standing bulk-republish TODO; NOTE\nmost corpus_result WRAM offsets moved, manifests must be regenerated from\nfresh .maps at publish. Investigation doc updated (Batch A struck through,\nresults appended).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
0a5e007	author	Will Norris
0a5e007	added	195
0a5e007	deleted	0
0a5e007	files	1
0a5e007	body	All 115 sources classified (render surface, band painter, dirty-marking) and\nall 114 published ROMs measured headlessly (d1 = frame 500v501 delta, d60 =\n500v560). Headlines: 19 demos carry trimerge's pre-#99b per-band tearing bug\n(F1 atomic flush applies mechanically); 10 band painters already atomic;\ntrue scroll-ring (F2) candidates are few (ovmove, mvscrl, truncstair,\nlfsr2?); plotters/compute-then-hold need nothing; life/cgrade/bitcensus/\nnewton already animate per-frame. Batches: A = F1 on the 19 (in flight),\nB = F2 rings, C = F3 stall hunts. hull/truchet/truncstair band matches were\nfalse positives (no per-band marking).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
