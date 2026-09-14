# [MOS] Fix non-GPR immediate loads in mos-late-opt

<!-- RE-SYNCED 2026-09-14: H1 = published title, body below = the published description
     (docs/pr-revisions/2026-09-13/584-body.md) at branch head `7f4c37de6219` (heads.json).
     Fork-patch follow-ups: docs/plans/2026-09-14-fork-patch-followups.md. Original banner follows. -->
<!-- NOT POSTED. Ready-to-post artifact; posting is user-triggered.
     Body below minus the H1 and this comment is the as-posted text.
     Staging record: red/green proven — RED = SIGSEGV on the unfixed
     build/upstream-llc (pristine tip) AND on the fork toolchain; GREEN = llvm-lit
     PASS after the fix + rebuild.
     Branch mos-late-opt-nongpr-ldimm to mint from the current upstream tip.
     Post commands (title = the H1 above; body = this doc minus the H1 and this comment):
       git -C vendor/llvm-mos push https://github.com/wbniv/llvm-mos.git mos-late-opt-nongpr-ldimm
       gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-late-opt-nongpr-ldimm --base main \
         --title "[MOS] Fix null-pointer crash in mos-late-opt on an LDImm with a non-GPR destination (SPC700)" \
         --body-file <(sed '2,/^-->$/d; 1d' docs/upstream-late-opt-nongpr-ldimm-pr.md)
     After posting: (1) flip item 15 in docs/upstream-contribution-status.md to posted with the
     PR number; (2) refresh wald3n.com's public contributions snapshot — in ~/wald3n.com run
     `task open-source:refresh` (auto-discovers the new PR), then commit/deploy per that repo's
     flow; its refresh:check gate fails on a stale snapshot otherwise.
-->

On SPC700, LDImm accepts imaginary-register destinations to represent `mov dp, #imm`. `combineLdImm` tracks only A/X/Y; processing an imaginary destination through that path dereferences a null tracking pointer.

Restrict immediate-load folding to GPR destinations in the existing filtering condition. Other instructions use the existing register-invalidation path. The sibling TA handler keeps its original behavior.

The SPC700 MIR regression covers an imaginary-register immediate load and confirms that it does not interfere with folding an adjacent GPR load to TAX.

Validation: MOS CodeGen suite 79 pass, 1 unsupported (Linux, assertions enabled).
