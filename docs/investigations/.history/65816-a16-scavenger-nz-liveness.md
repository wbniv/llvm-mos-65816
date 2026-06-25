| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/94b2bcb) | #321 docs: note corpus-a16 supersedes the "corpus is 8-bit" reason (scavenger XFAIL) |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/229662a) | #321 $p-spill scavenger: feasibility re-probe — no narrow fix; deferral stands |
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/b015df5) | #321 a16 scavenger crash: root-cause + XFAIL + investigation + upstream draft |

<!--history-meta v1
94b2bcb	author	Will Norris
94b2bcb	added	7
94b2bcb	deleted	0
94b2bcb	files	1
94b2bcb	body	The "corpus never caught it because the corpus is 8-bit" line was accurate\non 2026-06-18 but corpus-a16 (c998d7f) landed 2026-06-19. Add a Superseded\nnote: this crash is fuzzer-only (a fuzz-generated scavenge-under-live-N/Z\nshape, 8/500 seeds), so even the now-+mos-a16 corpus doesn't exercise it;\nthe corpus's one a16 casualty is the separate globals.c RA failure. Keeps\nthis doc consistent with deferred-and-rejected-items.md.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
229662a	author	Will Norris
229662a	added	22
229662a	deleted	0
229662a	files	1
229662a	body	Pivoted to the $p-spill (scavenger-p-not-gpr) crash, the sole residual xy16-track\nfailure (8/500 fuzz xfails). Re-confirmed live and probed both fix options against\nsaveScavengerRegister + the repro MIR:\n\n- Option 2 (upstream PHP/PLP) is NOT a drop-in: P has no GPR spill home, and PHP/PLP\n  can't bracket P across the unbalanced push/pull range a16 lands the scavenge in\n  (the PLP would pop the wrong byte) — needs a stack-relative P restore or a flag-safe\n  spill-point choice, touching the upstream scavenger contract across all MOS subtargets.\n- Option 1 (a16-side flag-kill) bottoms out in the same register-pressure core as the\n  deferred globals.c RA failure (the live N/Z is a genuine later-consumed compare result).\n\nVerdict: no narrow low-risk fork-side fix; deferral stands; the genuine unblock is the\nupstream issue (drafted, user-triggered). Recorded in the investigation doc.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
b015df5	author	Will Norris
b015df5	added	101
b015df5	deleted	0
b015df5	files	1
b015df5	body	The 8 fuzz crashes (169/173/196/268/271/272/306/420) are one bug: a +mos-a16\nregister-scavenger crash, "Bad machine code: $p is not a GPR register" under\n-verify-machineinstrs at -O1/-Os (clean at -O0 / default 8-bit).\n\nRoot cause, confirmed via an isolated asserts build: MOSRegisterInfo::\nsaveScavengerRegister (pristine UPSTREAM llvm-mos, NOT in 0002) assumes N/Z are\ndead at every scavenging point ("NZ cannot be live ... virtual registers are\nnever inserted into CmpBr instructions"). Under +mos-a16 a 16-bit compare/ALU\nkeeps N (or Z) live across a frame-vreg spill, violating the precondition; the\nrelease build (assert compiled out) then emits the illegal STImag8 $p\nP(rocessor-status)-spill. The asserts build aborts earlier at assertNZDeadAt\n("expected N to be free when saving scavenger register").\n\nDeliverables (no vendor change — upstream bug, fix deferred like globals.c):\n  - dev/asserts-build.sh: reusable isolated Release+LLVM_ENABLE_ASSERTIONS=On\n    toolchain into build/llvm-mos-asserts{,-install} (shared toolchain untouched).\n  - examples/65816/a16scavnz.c: deterministic repro (delta-debugged from seed-306;\n    verify-crashes +mos-a16 -Os, clean default + -O0).\n  - tools/a16_fuzz.py: KNOWN_ISSUES "scavenger-p-not-gpr" -> the 8 seeds now XFAIL\n    (verified: fuzz 1 306 reports known-issue, 0 new-crash).\n  - docs/investigations/65816-a16-scavenger-nz-liveness.md: full writeup.\n  - docs/321-upstream-scavenger-nz-issue.md + upstream-contribution-status.md\n    item 4: ready-to-post upstream issue (user-triggered).\n  - TODO.md: $p-spill item re-rooted (it's the scavenger NZ precondition, not a\n    "pointer reg"); upstream pointer mirrored.\n\nAlso corrects seed-157's note: FIXED earlier by the transfer X-annotation.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
