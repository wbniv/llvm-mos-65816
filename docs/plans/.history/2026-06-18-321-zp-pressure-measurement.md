| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/9fc5cf2) | #321 ZP-pressure measurement: baseline + globals.c +mos-a16 -Os RA-failure finding |

<!--history-meta v1
9fc5cf2	author	Will Norris
9fc5cf2	added	95
9fc5cf2	deleted	0
9fc5cf2	files	1
9fc5cf2	body	Investigation on a throwaway branch (CC-frame DP-window revival trigger + the\nmulti-value-register-pressure Phase 0 scan, in one host-only measurement).\n\ndev/measure-zp-pressure.sh (standalone): per-function distinct allocatable __rc<N>\nin +mos-a16 -Os -S (live-range reuse => distinct names ~ peak imaginary-register\npressure), excluding reserved __rc0/1 (soft-SP) + __rc16/17 (scavenger), vs the\n14-pair/28-byte usable pool.\n\nBaseline:\n  - Real code (6 kernels + 5/6 corpus, 13 fns): max 10 bytes (~5 of 14 pairs,\n    k_bits:main), mean 5.6. Zero functions near/over the budget.\n  - Synthetic ladder validates the metric: monotonic 0->2->8->22, and the ~20-live\n    shape fragments into 13 rep/sep brackets (matches the prior session).\n  Verdicts: CC-frame DP-window (a) = SHELVE with evidence (ZP is slack). Multi-value\n  fragmentation Phase 0 = DEFER confirmed (no real function exhausts the pool).\n\nFINDING (new defect): globals.c:main fails RA under +mos-a16 -Os ("ran out of\nregisters") while DEFAULT -Os and +mos-a16 -O0 both succeed. The corpus is built\ndefault 8-bit, so this was never exercised under +mos-a16; the fuzzer doesn't generate\nthis shape. A hard crash (not fragmentation) in the F3/spill-coverage family. Promoted\nto a separate follow-up (file + repro + fuzzer coverage + fix); NOT fixed here.\n\nNo codegen change (vendor/ untouched, 0002 not regenerated).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
