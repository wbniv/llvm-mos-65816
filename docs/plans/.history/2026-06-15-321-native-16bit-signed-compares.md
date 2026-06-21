| Date | Change |
|------|--------|
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/7748e99) | #321 native s16: native 16-bit signed ordering compares (sign-flip to unsigned) |

<!--history-meta v1
7748e99	author	Will Norris
7748e99	added	107
7748e99	deleted	0
7748e99	files	1
7748e99	body	An s16 signed compare (< <= > >=) narrowed to the 8-bit N^V byte chain. Signed\norder equals unsigned order after flipping the sign bit:\n  a <s b  <=>  (a ^ 0x8000) <u (b ^ 0x8000)\nso legalizeICmp now rewrites the canonical signed primitive (SLT — the other three\nreduce to it via negate/swap) to an unsigned ULT on the sign-flipped operands. The\nXORs are the already-native 16-bit EOR (selectAlu16Native -> eor #$8000) and the\ncompare re-legalizes through the already-native unsigned UGE carry path\n(selectSbc16 -> rep; lda; cmp; sep; bcc/bcs). No new flag handling (no V, no N^V\nidiom), no selector or pseudo changes — a single guarded block in legalizeICmp.\n\nA constant RHS stays constant (b ^ 0x8000) and folds into cmp #imm.\n\na16scmp reads 0x0111 with negative operands (an unsigned misread would get every\nordering wrong); -verify-machineinstrs clean; both MAME + bsnes-jg. Non-breaking:\ncorpus 7/7, all 19 a16* tests green, 0002 round-trips.\n\nFollow-up: compare producing a stored bool (non-branch) still narrows to 8-bit.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
