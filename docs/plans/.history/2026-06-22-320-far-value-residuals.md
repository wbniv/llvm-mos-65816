| Date | Change |
|------|--------|
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/18f9218) | #320 far-value residuals: implement — DP-arg upstream issue drafted+queued; 8-bit storage CLOSED by-design |
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/a98964f) | #320 far-value residuals: plan the dp→near upstream issue + default-8-bit storage close-out |

<!--history-meta v1
18f9218	author	Will Norris
18f9218	added	94
18f9218	deleted	15
18f9218	files	1
18f9218	body	Part A (dp→near) — drafted + queued an upstream issue (posting user-triggered):\nroot-caused to MOSCallingConv.td:65 `CCIfPtr<CCAssignToReg<[RS1..RS7]>>`\n(= CCIf<"ArgFlags.isPointer()">, address-space-blind) assigning the 8-bit\naddrspace(1) (direct-page) pointer ARGUMENT a 16-bit RS home → illegal\n`(p1)=COPY $rs` (Def 8, Src 16). Three faces re-confirmed (release -verify;\nasserts UNREACHABLE MOSRegisterInfo.cpp:1146 copyCost/RAGreedy; release\nSIGSEGV in MOSLateOptimization). Pure upstream: p1:8:8 is stock, 0001 only\nadds p2:32:8, reproduces on base mos6502; our pin c798c31 == upstream HEAD.\nNo dup found. Body docs/320-upstream-dp-arg-cc-issue.md; queued as item 8 in\nupstream-contribution-status (TL;DR 2→3 issues). Fix dir uses the real\nCCIfPtrAddrSpace<AS,…> LLVM class.\n\nPart B (default-8-bit far storage) — CLOSED, a16-gated by design. A far ptr\nis a 32-bit value; its s32↔bytes bridge (G_MERGE/G_UNMERGE {S32,S8}) is fully\nhasAccum16-gated (MOSLegalizerInfo.cpp:152-169, unsupported() else). Under\n8-bit, storage fails as a clean Legalizer `unable to legalize` rejection —\nno object, no miscompile (verified all four s1-s4 fixtures, no -verify) —\nunlike the (a) crash that survives to MOSLateOptimization. Verdict is\n0005-invariant (0005 only moves which instruction the Legalizer names), so\nestablished by measured equivalents + source gating rather than a full\npost-F2 rebuild (vendor/ is a stale shared partial missing 0005; rebuild\ndisproportionate for a no-code-change close). No 8-bit-only use case. No fork\nfix.\n\nPlan Verification filled (6/6 PASS) + Outcome section. TODO residual (b)\nclosed; far-value-evidence/README pre-F2-snapshot note added.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
a98964f	author	Will Norris
a98964f	added	316
a98964f	deleted	0
a98964f	files	1
a98964f	body	Plan to close the two Residuals bullets on the M1 far-pointer DATA-VALUE item\n(no fork patch, no codegen change):\n\n(A) "dp→near cast" — root-caused this turn as a DP-pointer-ARGUMENT crash: any\nuse of an addrspace(1) (8-bit DP) pointer arg fails on plain mos6502 (the CC\npasses it in a 16-bit RS reg → illegal (p1)=COPY $rs). Pure upstream (stock\np1:8:8; our 0001 only adds p2:32:8) → draft + queue an upstream issue with a\n2-line repro (user-triggered post). Three faces measured: -verify rejection,\nasserts UNREACHABLE MOSRegisterInfo.cpp:1146, no-verify SIGSEGV in MOSLateOpt.\n\n(B) default-8-bit far-ptr storage — a16-gated by design (works under +mos-a16\nvia F2; 8-bit is a clean compile-time rejection; no 8-bit-only use case) →\nconfirm on a post-F2 toolchain + close by-design.\n\nTODO: new Upstream/Contribution item for the DP-arg issue; M1 item residuals\n(a)/(b) updated in place to point at the plan.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
