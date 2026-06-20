| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/364de87) | #321 c-torture -Os sweep + load-fold fix: record results (1114 PASS, 0 FAIL) |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/86c2602) | #321 fix: a16 load-fold must not move a load across a memory-clobbering call |

<!--history-meta v1
364de87	author	Will Norris
364de87	added	13
364de87	deleted	2
364de87	files	1
364de87	body	Final verification of the -Os sweep and the load-fold-across-call fix:\n- full -Os re-sweep 1114 PASS, 0 FAIL, 54 SKIP (was 1112/2); pr34768-1/-2 PASS\n- fuzz 45/50, 0 mismatch / 0 crash\n- folds preserved (no win lost); verify-machineinstrs clean\n\nMarks the suite's -Os pass DONE in the [wip] c-torture item, adds the fix Done\nentry, and records the sweep + fix plan verdicts.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
86c2602	author	Will Norris
86c2602	added	111
86c2602	deleted	0
86c2602	files	1
86c2602	body	The -Os c-torture sweep found 2 FAILs (pr34768-1/-2): default PASS but\na16@MAME=a16@bsnes=0xDEAD. Root cause is a pre-existing a16 backend miscompile,\nNOT the middle-end (post-LTO IR is identical to default and correct).\n\nfoldableAbsLoad16 / foldableIndirLoad16 fold a single-use, same-BB 16-bit load\ninto the consuming ALU op or compare as a memory operand (adc abs / cmp abs /\ncmp (zp)) instead of staging through an Imag16 pair. Folding re-reads the memory\nat the USER's location, but the helpers only checked single-use + same-BB, never\nwhether an instruction BETWEEN the load and the user clobbers that memory. With\na call in between (`int tmp = g; clobber(); use(tmp, g)`), folding moves the read\npast the clobber -> wrong value.\n\n  pr34768-1: `int tmp=x; (c?foo:bar)(); return tmp+x;` with foo doing x=-x.\n  At -Os LTO const-props c=1 -> straight-line `foo()` call, exposing the shape.\n  a16 emitted `jsr foo; lda x; adc x` (x+x) instead of saving tmp before the\n  call. -O1 passed because it didn't const-collapse the ternary; this was the\n  first full -Os torture pass, so the latent bug had never been exercised.\n\nFix: new noStoreBetween(Def, User) scans the strictly-between instructions in\nthe common block; if any mayStore()/isCall()/hasUnmodeledSideEffects(), bail\n(don't fold -> stage through Imag16 as before). Applied to both helpers.\nConservative per governing lesson #2: a miss only forgoes a win, never\nregresses. Folds with no intervening call keep firing (verified).\n\nThe buggy abs fold was introduced in ef4671d (#321 fold near-abs global operands\ninto the 16-bit compare); foldableIndirLoad16 (9009260) shared the same latent\nflaw and is fixed here too. Default codegen unaffected (no 16-bit fold exists).\n\nRegression guard: examples/65816/a16loadcall.c + dev/a16loadcall.sh (abs + (zp)\n+ compare operands across a clobbering call, host-verified 0x0100).\n\nVerified (clang-23 rebuilt): pr34768-1/-2 -Os PASS both emulators; a16loadcall\n0x0100 4-way; folds preserved (a16cmpidx ≥5 cmp(zp)/a16abscmp/a16loadfold/\na16mixfold/a16cmpaudit/a16cmp all PASS); verify-machineinstrs clean; 0002\nround-trips (noStoreBetween only, no foreign hunks). Full -Os torture re-sweep\n+ fuzz running for final confirmation.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
