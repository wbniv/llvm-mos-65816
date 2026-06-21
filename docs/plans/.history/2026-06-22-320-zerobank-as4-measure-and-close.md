| Date | Change |
|------|--------|
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/51af94b) | #320 zero-bank (AS4): plan to measure-and-close the last address space |

<!--history-meta v1
51af94b	author	Will Norris
51af94b	added	320
51af94b	deleted	0
51af94b	files	1
51af94b	body	Adds docs/plans/2026-06-22-320-zerobank-as4-measure-and-close.md + a TODO M1\nitem. Closes the only one of asiekierka's five spaces not formally\nevidence-closed: the five-space §Phase 2 "NO-GO" rode a circular, lumped census\n("zero-bank likewise has 0 users") — the same trap packed-24's twin finding was\ncorrected for. The plan de-lumps it to the project bar (mirroring\nframeabi-census.sh), with both a measured-null close (frame-ABI shape, expected)\nand a gated GO build path (packed-24 shape) kept.\n\nPremise-checked via a 4-reader + 3-skeptic workflow (3/3 found no win):\nzero-bank is bit-identical to a near pointer (both ...:16:8, both 16-bit-abs), so\nit competes with "near ptr + lazy ->far cast", not with far, and ties it on\nstorage/access/boundary. Two structural facts make the null non-circular:\n(1) the cheap ad/8d access AS4 was invented for is already delivered on AS0 via\nthe assembler's ZeroBank relaxation (MOSAsmBackend.cpp relaxInstructionTo);\n(2) no far indexed-long mode + AS4 cheap access is globals-only, so a runtime\nAS4 arg derefs no cheaper than near. Feasibility is higher than packed-24\n(~30 LoC, reuses near path + 0006 cast template, no MVT workaround) => null by\nworth, not infeasibility. Closing AS4 formally completes the five-space model.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
