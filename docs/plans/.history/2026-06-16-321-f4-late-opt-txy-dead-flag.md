| Date | Change |
|------|--------|
| [2026-06-16](https://github.com/wbniv/llvm-mos-65816/commit/0fe82ab) | #321 P0+F4: fuzz recursion → soft-stack coverage, finds + fixes an upstream mos-late-opt crash |

<!--history-meta v1
0fe82ab	author	Will Norris
0fe82ab	added	121
0fe82ab	deleted	0
0fe82ab	files	1
0fe82ab	body	P0 (tools/a16_fuzz.py): the differential fuzzer now emits genuinely RECURSIVE\nfunctions — the only soft-stack trigger the generator can produce (MOSNonReentrant\nmarks every non-recursive function `nonreentrant` → static frame). Each recursive\nfunction holds several volatile-anchored 16-bit values live across the self-call, so\nthe caller spills to its (soft) frame, exercising expandLDSTStk — the path the F3\nAc16-spill bug lived on and which the fuzzer never reached before. Validated:\n25/25 host-gcc agreement (UB-free, oracle-exact), soft-stack spills exercised incl.\nthe Ac16 path, `dev/run.sh fuzz 50 1` → 50/50 (host==default==+mos-a16 on MAME +\nbsnes-jg). Closes the coverage gap the F3 plan flagged.\n\nF4: on its first run P0 surfaced a pre-existing UPSTREAM llvm-mos bug. The\nmos-late-opt `combineLdImm` peephole rewrites `LDImm` → a TYX/TXY index transfer\nbut, unlike its TAX/TAY/TXA/TYA siblings, never set `Load`, so it skipped the\ndead/kill-flag cleanup — leaving a `dead` source def, which the verifier rejected\n("Using an undefined physical register") on +mos-a16 reentrant code. Fixed with the\n2-line `Load = &LoadX/Y` carried as patches/llvm-mos/0003-late-opt-txy-dead-flag.patch\n(+ a late-opt-65816.mir regression). Upstream branch pushed to\nwbniv/llvm-mos:mos-late-opt-txy-dead-flag; PR preview in\ndocs/321-upstream-late-opt-txy-pr.md (PR not opened).\n\nNon-breaking: corpus 7/7, a16spillr/a16spill/a16localx/a16localbit green;\n0001+0002+0003 round-trip on pristine. Plans:\ndocs/plans/2026-06-16-321-soft-stack-spill-coverage.md (P0, already committed) and\ndocs/plans/2026-06-16-321-f4-late-opt-txy-dead-flag.md (F4).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
