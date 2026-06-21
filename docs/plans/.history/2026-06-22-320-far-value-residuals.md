| Date | Change |
|------|--------|
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/a98964f) | #320 far-value residuals: plan the dp→near upstream issue + default-8-bit storage close-out |

<!--history-meta v1
a98964f	author	Will Norris
a98964f	added	316
a98964f	deleted	0
a98964f	files	1
a98964f	body	Plan to close the two Residuals bullets on the M1 far-pointer DATA-VALUE item\n(no fork patch, no codegen change):\n\n(A) "dp→near cast" — root-caused this turn as a DP-pointer-ARGUMENT crash: any\nuse of an addrspace(1) (8-bit DP) pointer arg fails on plain mos6502 (the CC\npasses it in a 16-bit RS reg → illegal (p1)=COPY $rs). Pure upstream (stock\np1:8:8; our 0001 only adds p2:32:8) → draft + queue an upstream issue with a\n2-line repro (user-triggered post). Three faces measured: -verify rejection,\nasserts UNREACHABLE MOSRegisterInfo.cpp:1146, no-verify SIGSEGV in MOSLateOpt.\n\n(B) default-8-bit far-ptr storage — a16-gated by design (works under +mos-a16\nvia F2; 8-bit is a clean compile-time rejection; no 8-bit-only use case) →\nconfirm on a post-F2 toolchain + close by-design.\n\nTODO: new Upstream/Contribution item for the DP-arg issue; M1 item residuals\n(a)/(b) updated in place to point at the plan.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
