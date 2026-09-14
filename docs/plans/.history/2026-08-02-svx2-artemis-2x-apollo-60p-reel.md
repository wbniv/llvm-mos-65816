| Date | Change |
|------|--------|
| [2026-09-15](https://github.com/wbniv/llvm-mos-65816/commit/32142e6) | svx2: split dev/svx2-emulator-validation.sh into record, asset and code contracts |
| [2026-08-02](https://github.com/wbniv/llvm-mos-65816/commit/22b2348) | Record mixed video reel publication |
| [2026-08-02](https://github.com/wbniv/llvm-mos-65816/commit/f61472a) | Add mixed-cadence Artemis and Apollo video reel |

<!--history-meta v1
32142e6	author	Will Norris
32142e6	added	92
32142e6	deleted	0
32142e6	files	1
32142e6	body	The gate compared the whole rebuilt 8 MiB ExHiROM image byte-for-byte to the\npublished v1.0.360, so it could only pass on the exact toolchain that built\nthe release. Reshape it per the Mode 7 gallery reconciliation policy\n(docs/plans/2026-09-14-m7-gallery-web-reconcile.md, decision row 2): (1) the\ndeployed ROM matches the SHA-256 in the plan's publication record; (2) the\nrebuild's packed stream regions (file $010000-$3FFFFF and $410000-) are\nbyte-identical to the deployed ROM -- the asset contract; (3) the rebuild\npasses every functional gate of dev/snes-video-artemis-apollo.sh -- the code\ncontract. The rebuilt whole-ROM SHA-256 is still printed; a differing code\nwindow is classified instead of failed, by asking the preprocessor for the\nROM's tracked compile inputs and checking whether any commit after the\npublication commit (f61472a) touches them: none -> ACCEPTED DIVERGENCE\n(toolchain drift); otherwise DIVERGENCE (demo-source drift), naming the\ncommits and the policy action (a user-triggered republish). Both exit 0; the\ngate's pass/fail is checks 1-3, as in the reconciliation's own row 2.\n\nThe classification matters because the drift measured today is mixed, not\ntoolchain-only: rebuilding the publication commit's sources with today's\ntoolchain gives a third image (S0 != P: 19,712 code bytes, toolchain;\nS0 != S1: 17,183 code bytes, source -- 8eca83a shared FPS gauge and ff35036\nMode 7 splash contract both touch this ROM's inputs after f61472a; 09fb433\ntouches snes-video-reel.c but is byte-neutral for this build). Streams are\nidentical in every pairing. A gate that printed "toolchain drift" here would\nbe wrong, so it prints the source-drift line. Recorded with raw output in the\nartemis-2x-apollo plan; the anchors-decision plan's step 5 is closed by 5b.\n\nRe-run: checks 1-3 PASS, 0x0B06/3000, seam offsets, transport, 0x2327/9177\nwith zero slips, streams byte-identical, exit 0.\n\nCo-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011AP736JtwzSGYH4bmxDWTa\n(cherry picked from commit 6cd63ef9db522a96bf59d135584eded8634b7f0b)
22b2348	author	Will Norris
22b2348	added	17
22b2348	deleted	5
22b2348	files	1
f61472a	author	Will Norris
f61472a	added	104
f61472a	deleted	0
f61472a	files	1
-->
