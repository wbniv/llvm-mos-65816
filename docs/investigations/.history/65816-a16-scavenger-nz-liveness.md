| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/b015df5) | #321 a16 scavenger crash: root-cause + XFAIL + investigation + upstream draft |

<!--history-meta v1
b015df5	author	Will Norris
b015df5	added	101
b015df5	deleted	0
b015df5	files	1
b015df5	body	The 8 fuzz crashes (169/173/196/268/271/272/306/420) are one bug: a +mos-a16\nregister-scavenger crash, "Bad machine code: $p is not a GPR register" under\n-verify-machineinstrs at -O1/-Os (clean at -O0 / default 8-bit).\n\nRoot cause, confirmed via an isolated asserts build: MOSRegisterInfo::\nsaveScavengerRegister (pristine UPSTREAM llvm-mos, NOT in 0002) assumes N/Z are\ndead at every scavenging point ("NZ cannot be live ... virtual registers are\nnever inserted into CmpBr instructions"). Under +mos-a16 a 16-bit compare/ALU\nkeeps N (or Z) live across a frame-vreg spill, violating the precondition; the\nrelease build (assert compiled out) then emits the illegal STImag8 $p\nP(rocessor-status)-spill. The asserts build aborts earlier at assertNZDeadAt\n("expected N to be free when saving scavenger register").\n\nDeliverables (no vendor change — upstream bug, fix deferred like globals.c):\n  - dev/asserts-build.sh: reusable isolated Release+LLVM_ENABLE_ASSERTIONS=On\n    toolchain into build/llvm-mos-asserts{,-install} (shared toolchain untouched).\n  - examples/65816/a16scavnz.c: deterministic repro (delta-debugged from seed-306;\n    verify-crashes +mos-a16 -Os, clean default + -O0).\n  - tools/a16_fuzz.py: KNOWN_ISSUES "scavenger-p-not-gpr" -> the 8 seeds now XFAIL\n    (verified: fuzz 1 306 reports known-issue, 0 new-crash).\n  - docs/investigations/65816-a16-scavenger-nz-liveness.md: full writeup.\n  - docs/321-upstream-scavenger-nz-issue.md + upstream-contribution-status.md\n    item 4: ready-to-post upstream issue (user-triggered).\n  - TODO.md: $p-spill item re-rooted (it's the scavenger NZ precondition, not a\n    "pointer reg"); upstream pointer mirrored.\n\nAlso corrects seed-157's note: FIXED earlier by the transfer X-annotation.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
