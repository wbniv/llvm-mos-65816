| Date | Change |
|------|--------|
| [2026-07-01](https://github.com/wbniv/llvm-mos-65816/commit/b9407d6d) | docs(rc-undef): record #69/#71 as new Cause-#2 witnesses |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/7e3e3c8f) | docs(rc-undef): durable two-cause investigation report + plan pointer |

<!--history-meta v1
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
