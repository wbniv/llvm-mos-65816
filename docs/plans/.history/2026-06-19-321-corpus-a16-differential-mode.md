| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/c998d7f) | #321 corpus-a16: run the SNES regression corpus under +mos-a16 (differential gate) |

<!--history-meta v1
c998d7f	author	Will Norris
c998d7f	added	178
c998d7f	deleted	0
c998d7f	files	1
c998d7f	body	New dev/corpus-a16.sh (dev/run.sh corpus-a16): builds every examples/snes/corpus/*.c\n(arith/control/arrays/structs/funcs/globals) under +mos-a16 AND +mos-xy16 and asserts\nhost == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg via the shared engine\n(tools/a16_fuzz.py check). globals.c auto-XFAILs via KNOWN_ISSUES\n(regalloc-out-of-registers) with no special-casing in the script. Closes the\n"corpus only ever built default 8-bit" coverage gap -- the gap that hid the globals.c\n+mos-a16 -Os regalloc crash until the ZP-pressure scan happened to compile it +mos-a16.\n\nAdditive: no vendor/, no 0002, no toolchain rebuild. Dispatch is automatic\n(dev/run.sh execs /work/dev/<target>.sh, so no run.sh code change needed).\n\nVERIFIED 2026-06-19: arith/control/arrays/structs/funcs PASS, globals XFAIL, exit 0;\ncorpus-a16 -h usage exit 0; default corpus still 7/7; a16eqval spot-check PASS; 0002\nunchanged. (Summary prints 5/6 passed, 1 xfail -- total counts all 6 corpus_result\nprograms incl. the XFAIL'd globals, matching dev/corpus.sh's $pass/$total convention.)\n\n- dev/corpus-a16.sh    new differential harness\n- dev/run.sh           corpus-a16 help/targets line (documentation only)\n- TODO.md              Test Bench/CI standing-capability item ([x], verified)\n- docs/plans/2026-06-19-...corpus-a16   plan -> DONE/VERIFIED + filled Verification\n- docs/plans/2026-06-18-...zp-pressure  one-line back-ref (the gap now closed)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
