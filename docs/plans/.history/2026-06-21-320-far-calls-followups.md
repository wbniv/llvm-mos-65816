| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/93c7336) | #320 (a): p2-value legalization root-caused as a deep multi-layer 0004 sub-project |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/560900c) | #320 (a): far-indirect call MECHANISM built + verified (IR-rep #1, i32-target path) |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/5fd0ff5) | #320 (a): Layer-3 finding — far fn ptr can't be a ptr addrspace(2) IR callee |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/5d81d44) | #320 far-followups: (b) shipped to main (5717f6b); (a) paused, front-end LOCKED=F2 |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/dd33017) | #320 (b) mixed-banking: far->near calls via __call_near_from_far thunk |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/827596d) | #320 far-followups: absorb cross-agent A0 evidence; (b) DONE; (a) gated on 0004 |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/b6dde43) | #320 far-followups (a): graft cross-agent A0 spike evidence + 2 backend gaps |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/34e9542) | #320 far-followups: refine (b) to generic __call_near_from_far thunk; register worktree |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/3aa2944) | #320 far-calls follow-ups: plan (a) far fn pointers + (b) mixed-banking |

<!--history-meta v1
93c7336	author	Will Norris
93c7336	added	21
93c7336	deleted	4
93c7336	files	1
93c7336	body	Pushed on (a)'s p2 path. Asserts-build root-causing found 0004's p2-value handling\nis unfinished across layers:\n- Layer 1 FIXED: copyCost missing the Imag32 case (RA copy-hint unreachable on any\n  imag32/p2 copy).\n- Layer 2 FIXED: getRegAllocationHints costs size-mismatched sub-register pairs from\n  the p2 decompose (copyCost(imag16,imag8)); added a size-match guard.\n  Both regression-clean (corpus 7/7, far_near_call PASS; only fire for imag32/p2).\n- Layer 3 OPEN: post-RA SelectImm with an Imag8 condition ($rs1 = SelectImm $rc5)\n  -> verify "Illegal physical register".\n- Gap B: raw G_STORE p2 unable to legalize. Gap A: &far_sym->24-bit.\nSo (a)'s p2 path = finishing 0004's p2-value handling (Layer 3 + Gaps A/B) + clang\nF2 + e2e. The 2 RA-hint fixes are in the worktree's vendor (recipes in the plan).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
560900c	author	Will Norris
560900c	added	25
560900c	deleted	8
560900c	files	1
560900c	body	Built IR-rep #1 (user choice) end-to-end, backend-first. Realized "set_far_target"\nas a volatile store to a runtime slot __mos_far_target + call @__call_indir_far\n(lighter than a formal LLVM intrinsic, which would need Intrinsics.td regen for no\nfunctional gain). Verified on hand-authored IR with an i32 target: lowerCall makes\nthe __call_indir_far call a JSL; stub jml (__mos_far_target) + the 4-byte slot;\nslot-store + jsl, -verify-machineinstrs clean.\n\nRemaining (substantial, scoped): (1) p2-value legalization — ptrtoint(p2)->i32 /\np2-param decompose crash ("Illegal physical register ... SelectImm") + Gap A\n(&far_sym->24-bit); (2) clang F2 far attr + CodeGen; (3) e2e runtime gate. WIP on\nthe worktree (0004 stacked); plan/TODO/handoff updated.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
5fd0ff5	author	Will Norris
5fd0ff5	added	47
5fd0ff5	deleted	24
5fd0ff5	files	1
5fd0ff5	body	Continuing toward (a): stacked 0004 (p2 base) and prototyped indirect-far lowering.\nMeasured a third, deeper blocker: LLVM forbids a non-program-addrspace callee\n(verifier "expected 'ptr'"; MOS datalayout has no P<n> field; addrspacecast p2->p0\ndrops the bank). So a far fn ptr can't be a `ptr addrspace(2)` callee and the\n"detect p2 callee in lowerCall" trigger is untriggerable (prototyped + backed out).\nThe 24-bit address must be threaded via a front-end IR representation: #1 a\nset_far_target intrinsic + call @__call_indir_far(args) (leaning), #2 a custom\nMOS_FarIndirect CC, or #3 a full call intrinsic. The runtime stub __call_indir_far\n(jml (__rc18)) is built + assembled (correct, design-independent half). So (a) is\nblocked on the IR-representation DESIGN decision + 0004 on main; recipe captured in\nthe plan. (b) remains shipped + unaffected.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
5d81d44	author	Will Norris
5d81d44	added	13
5d81d44	deleted	6
5d81d44	files	1
5d81d44	body	User decisions 2026-06-21: ship (b) now (done), pause (a) as a follow-up gated on\n0004 (far-CC Imag32 p2 base reaching main), and lock (a)'s front-end spelling to\nF2 (MOS far attribute). Plan Open-decision -> resolved; TODO + handoff updated.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
dd33017	author	Will Norris
dd33017	added	77
dd33017	deleted	60
dd33017	files	1
dd33017	body	A far (.far_*) function calling a NEAR function now routes through a bank-0 generic\nthunk reached by JSL, lifting the "far must be a leaf-or-far-only" constraint.\n\n- MOSCallLowering::lowerCall (0001, HasW65816-gated, a16-free): detect caller-far +\n  direct near callee -> materialize &g into RS9, ChangeToES(__call_near_from_far),\n  emit JSL. far->far and near->far already went long; near->near unchanged.\n- platforms/snes/call-near-from-far.s: the thunk (pea .Lback-1; jmp (__rc18); rtl),\n  built -mcpu=mosw65816 (per-file), in its own section so --gc-sections drops it\n  from ROMs with no far->near call (near corpus stays byte-identical).\n- Gate examples/65816/far_near_call.c + dev/far_near_call.sh + dev/xcheck row.\n\nVerified: far_near_call == 0xE0 on MAME + bsnes-jg (main->far->near->near chain;\nnear callee ran at PBR=$00 incl. its own near JSR); disasm gate (jsl thunk; thunk\npea/jmp-ind/rtl; near rts); corpus 7/7; all prior far ROMs PASS; thunk gc'd from\nnear ROMs; -verify-machineinstrs clean. 0001 round-trips for MOSCallLowering,\na16-free (0 accum16), 0 foreign hunks.\n\nPlan synced to main's canonical version (generic-thunk + (a) cross-agent findings).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
827596d	author	Will Norris
827596d	added	42
827596d	deleted	12
827596d	files	1
827596d	body	(b) mixed-banking DONE + verified both emulators (far_near_call == 0xE0 on MAME &\nbsnes-jg; corpus 7/7; thunk gc'd from near ROMs -> byte-identical). Plan/Sequencing/\nVerification updated off the per-callee-veneer wording to the shipped generic thunk.\n\n(a) far function pointers: fold in the wt/320-far-cc A0 spike + re-confirm here -\ntwo BACKEND gaps (G_TRUNC/G_UNMERGE/G_STORE on p2) crash today; they are the same\np2-VALUE class the far-CC study shipped as Imag32 in 0004-320-far-cc.patch (not on\nmain yet). So (a) = front-end story + the far-CC p2 base (0004) + stub/indirect\nlowering + residual legalizer fixes; gated on 0004 reaching main.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
b6dde43	author	Will Norris
b6dde43	added	17
b6dde43	deleted	0
b6dde43	files	1
b6dde43	body	From a parallel A0 spike on wt/320-far-cc (now stood down as duplicate of this\ncanonical branch). Doc-only addendum to the (a) gaps section:\n\n- Empirical receipts for plan points 2/4: &far_leaf relocs R_MOS_ADDR16_LO/_HI\n  (bank lost) vs a far data access R_MOS_ADDR24 (bank baked, access-only); IR\n  shows address_space(2) on a function DECLARATION is silently ignored (no\n  warning) -> the MIPS-far-style decl attribute won't alone place the fn in AS2.\n- Two BACKEND gaps the plan didn't note: returning &far_sym as a far pointer\n  crashes today (SelectImm "Illegal physical register"; G_STORE p2 "unable to\n  legalize"), and decomposing a far fn-ptr value hits the unsupported\n  s32->4xs8 G_UNMERGE_VALUES. So (a) = front-end story + 2 legalizer fixes\n  before __call_indir_far is reachable.\n\nReproducible: /tmp/a0_*.c (4 probes).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01MfznzHZwGwQHUDg7yjrJ8u
34e9542	author	Will Norris
34e9542	added	38
34e9542	deleted	34
34e9542	files	1
34e9542	body	Measure-the-implementation check: MOSAsmPrinter has no emitEndOfAsmFile hook and\nonly basic target flags, so a per-callee veneer needs ~5 touch-points. The generic\nbank-0 thunk (pea .back-1; jmp (__rc18); rtl) reached by JSL is correct, needs only\nlowerCall + a static .s stub, and shares the copy-addr->slot + JSL-to-stub plumbing\nwith (a)'s __call_indir_far. Per-callee veneer kept as a future byte-optimization.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
3aa2944	author	Will Norris
3aa2944	added	316
3aa2944	deleted	0
3aa2944	files	1
3aa2944	body	Probes reshaped scope before committing the plan:\n- far->far already works (non-leaf JSL/RTL chains); (b) = far->near only.\n- (a) far fn pointers blocked on a front-end: address_space(2) is forbidden on\n  function types (clang Sema), far/long_call attr is MIPS-only, &far_fn yields\n  only 16 bits today. Recommend (b) first (backend-only), then (a) backend, then\n  (a) front-end (F1 builtin / F2 MOS far attr [rec] / F3 far-fn-ptr type).\nDesigns: (b) bank-0 veneer (jsr g; rtl) reached by JSL; (a) __call_indir_far\n(jml [__rc18]) mirroring the near __call_indir.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
