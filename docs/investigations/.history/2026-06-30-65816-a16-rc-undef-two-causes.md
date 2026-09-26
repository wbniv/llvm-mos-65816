| Date | Change |
|------|--------|
| [2026-09-25](https://github.com/wbniv/llvm-mos-65816/commit/6065ebec) | fix(mos): finish defect review, near-store fixes, and evidence enforcement |
| [2026-07-01](https://github.com/wbniv/llvm-mos-65816/commit/b9407d6d) | docs(rc-undef): record #69/#71 as new Cause-#2 witnesses |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/7e3e3c8f) | docs(rc-undef): durable two-cause investigation report + plan pointer |

<!--history-meta v1
6065ebec	author	Will Norris
6065ebec	added	9
6065ebec	deleted	0
6065ebec	files	1
6065ebec	body	Extend the inline-asm physical-register width guard to named registers,\ncheck the fixup-table length at compile time, and keep symbolic addr-asciz\nhandling scoped to directive text output. Refresh all required lit tools\nand make missing rcundef witnesses fail with useful diagnostics.\n\nKeep byte-built absolute argument stores and narrowly gated plain indirect\nA:X stores on their profitable byte paths. Preserve atomic word stores,\nnative consumers, and call-preserved contexts. Add lit/runtime regressions,\nbefore/after corpus measurements, plans, and reproduction scripts. Setters\nshrink 14 to 7 bytes absolute and 13 to 8 bytes indirect, with no measured\ncorpus growth. Regenerate and round-trip-check patch 0002.\n\nRecheck the three older reports without claiming unsupported closure.\nNarrow-count shifts and inline-bitboard register pressure remain not\nreproduced with historical baseline gaps; reentrant remains a contract\nclarification. Retain current-build observations, original attributions,\nand follow-up work. Require structured defect records and immutable\nbaseline evidence through agent instructions and the staged commit hook.\nDocument how to activate the repository hooks in each clone.\n\nValidation: 132 older-report verifier compiles and runtime differentials\npass; both store regressions and native-copy controls pass on MAME and\nbsnes-jg. Final MOS lit: 162 pass, 2 unsupported, the same 4 existing\nfailures. Evidence checker: 12 tests pass. Comment-history, staged evidence,\nSNES display-quality, and whitespace checks pass.\n\nOpenAI Codex performed the independent review, follow-up implementations,\nreproduction audit, evidence enforcement, and documentation reconciliation.\nInclude Claude Sonnet 5's initial PR drafts and pinned-base validation with\ntheir original credits and explicit limits for the revised artifacts.\nPreserve the original Claude implementation credits in the review record.\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nCo-Authored-By: OpenAI Codex <noreply@openai.com>
b9407d6d	author	Will Norris
b9407d6d	added	9
b9407d6d	deleted	1
b9407d6d	files	1
b9407d6d	body	The Round-4 demos #69 (Gouraud, per-pixel barycentric divide) and #71\n(marching-squares, per-pixel edge-crossing divide) both reproduce the deferred\na16-rc-undef-ra-pure-virtual known issue: -verify-machineinstrs crashes at\n-O1/-Os under +mos-a16 AND +mos-xy16 ('Using an undefined physical register'),\nwhile -O0 is clean and the full 5-way differential is green (code bit-exact\ncorrect — 0xC5E9 / 0x86A7 on bsnes-jg).\n\nMeasured all opt levels; added them to the witness tables in both the fix plan\nand the durable two-causes write-up. Significance: they broaden the known\ntrigger population — before Round 4 the deferred-Cause-#2 witnesses were an\nL-system + soft-float slices; #69/#71 show ordinary high-register-pressure\nint32-divide graphics kernels hit it too. No new action (same deferred\ngeneric-LLVM RA fix); recorded as XFAIL witnesses.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
7e3e3c8f	author	Will Norris
7e3e3c8f	added	152
7e3e3c8f	deleted	0
7e3e3c8f	files	1
7e3e3c8f	body	New docs/investigations/2026-06-30-65816-a16-rc-undef-two-causes.md — the standalone\nwrite-up of the whole arc: one verifier symptom = two distinct defects. Cause #1\n(coalescer copy-hint) FIXED+shipped+upstream-ready; cause #2 (RA undef sub-lane)\nroot-caused with three reverted fix attempts and deferred upstream (a generic-LLVM\npath-sensitive/loop-aware/subreg-lane-precise undef-propagation feature). Plan links\nto it.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
