| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/827e88e) | #321 plan: +mos-a16 s32 (long/int32_t) support — investigation + decision (a) INVEST |

<!--history-meta v1
827e88e	author	Will Norris
827e88e	added	100
827e88e	deleted	0
827e88e	files	1
827e88e	body	The Csmith fuzzer surfaced that +mos-a16 aborts the backend on valid C using\nint32_t/long in s16-interacting shapes (G_UNMERGE_VALUES s32; seed 11 + 9 more,\nXFAILed on wt/321-csmith as a16-unmerge-s32). Investigated to root cause: default\nnarrows every s32 op to s8 bytes, but under +mos-a16 s16 is a legal type so\nnarrowing stops at s16 and diverts s32 into 2x s16 pieces — and the s32<->s16\nmachinery (legalizer trunc/ext/merge/unmerge + selector) doesn't exist.\n\nMeasured: there is no minimal fix — unlocking one s32 op just exposes the next\n(unmerge -> trunc -> anyext -> ...), and s16-legal blocks forcing s32 -> s8. So\nthe correctness fix IS the s32-under-a16 feature (also delivers the i32 16-bit-\nchunk optimization). Decision (a) INVEST. Plan: P1 legalizer artifacts, P2\nselector/artifact-combiner, P3 differential correctness, P4 frozen-.ll\nregression + remove XFAIL + regen 0002.\n\nDocs only (plan + TODO); toolchain at baseline, implementation follows.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
