# [MOS] Add the COP mnemonic with a mandatory signature operand

<!-- RE-SYNCED 2026-09-14: H1 = published title, body below = the published description
     (docs/pr-revisions/2026-09-13/588-body.md) at branch head `fb1b4ba325a8` (heads.json).
     Fork-patch follow-ups: docs/plans/2026-09-14-fork-patch-followups.md. Original banner follows. -->
<!-- [DRAFT — PR body for llvm-mos/llvm-mos; strip the H1 and this comment when posting]
     COP-only complement to PR #586 (BRK's optional signature operand). Cut independently from
     upstream main so its history stays clean -- it does NOT build on #586's branch, it cites it.
     The old BRK+COP combined preview branch (`mos-65816-cop-brk-signature`, superseded 2026-08-04)
     stays untouched as reference only; this branch replaces it for the COP portion.

     DESIGN (2026-08-04 T5 call): MANDATORY operand -- the fork's `0002` shape (decoder-visible,
     2-byte decode). Bare `cop` is rejected; `cop #imm` is required. This retires the combined
     draft's optional-operand / isAsmParserOnly / 1-byte-decode COP. Rationale: (1) bare `cop` is a
     footgun -- hardware always consumes the signature slot, so a 1-byte `cop` silently eats the next
     opcode; WDC's own syntax requires the operand for COP; (2) the BRK 1-byte-decode compatibility
     argument does not apply to COP ($02 is 65816-only, currently `<unknown>`), so decoder-visible
     `cop #imm` gives faithful 2-byte disassembly at zero cost; (3) the optional-BRK(#586) /
     mandatory-COP asymmetry is WDC's own, and matches the `wdm` mandatory precedent already
     upstream; (4) strict -> loose is the reversible direction; (5) the fork ships exactly this
     shape, validated by the #140 brkcop demo gates. Full ruling history: git blame ceead8d on this
     file, and docs/plans/2026-08-04-split-brk-cop-patch-ownership.md.

     Status: ✅ POSTED 2026-08-04 as https://github.com/llvm-mos/llvm-mos/pull/588 (user-triggered
     "publish the PR"; branch pushed + PR created same session; body below is the as-posted text,
     including the de-forked a16/xy16 soak-coverage wording, cb87da8).
     Branch: mos-65816-cop-mnemonic, cut from upstream main 1f334fef02b5, one commit
     3ac109760642, living locally in ~/llvm-mos. Verified in ~/llvm-mos/build-pr (MOS-only,
     Release+asserts): TableGen/build clean (no decoder conflict -- $02 has exactly one
     decoder-visible def per predicate), all new/changed tests proven red-before/green-after, MC
     suite fully green (40/40) once llvm-readelf is built. [CORRECTED 2026-08-04: the earlier '5 pre-existing failures on pristine tip' / '39/40 lone failure' claims were exit-127 tool-missing artifacts of the minimal build-pr tool set (opt, llvm-readelf absent); with the tools built the suites are fully green — CodeGen 79 pass + getchar-regression.ll upstream-disabled (UNSUPPORTED: target), 0 failures; MC 39/39 (+ the branch's own new tests). Rule: build the tools the suite RUNs before quoting numbers; exit-127 in a lit log is an environment defect.]
     PRE-FLIGHT resolved 2026-08-04: the user pushed this repo's main, and the "(source)" link
     verified HTTP 200 before posting. Both links live.
     Post commands (as executed):
       git -C ~/llvm-mos push origin mos-65816-cop-mnemonic
       gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-65816-cop-mnemonic --base main \
         --title "[MOS] Add the COP mnemonic with a mandatory signature operand" \
         --body-file <(sed '1,/^-->$/d' docs/upstream-cop-brk-signature-pr.md)
-->

Add the W65816 COP instruction with a mandatory signature operand, following WDC assembly syntax. COP encodes as opcode $02 followed by the signature byte and disassembles as a two-byte instruction.

Tests cover expression and literal operands, instruction encoding and disassembly, rejection on an unsupported CPU, and rejection of a missing operand. Comments describe the operand requirement without repeating instruction semantics.

Validation: all 40 MOS MC tests pass (Linux, assertions enabled).
