# Patch 0036 — independent review (Claude)

Review of Codex's zero-page indexed-globals fix, 2026‑09‑23, on the pinned
llvm-mos revision `742d554bf08042b8df93d791c335260fadd16643`. Scope: the C++
change, the three tests, the PR draft and validation record, and the rest of
the lowering code the change sits in. Not maintainer feedback. The defect
itself came out of the 0032 review (Codex's audit reduced it).

**Verdict: correct, ready to post.** The design call is right and the fix is
the minimal one. Two findings, neither a defect in the patch: the store-operand
bug it also fixes is the more consequential half in practice, and the same
whole-object contract is what the assembler already applies, so both output
paths now agree everywhere I could push them.

## The change

`canUseZeroPageIdx` decides whether an indexed access to a global can use the
zero-page,X form. It accepted only address-space-1 globals; a global placed in
a zero-page *section* (`.zp.bss`, `.zeropage.*`, `.directpage`) was printed as
`mos8(sym),x` by `lowerOperand`, which already knows those sections, but
encoded directly as absolute,X. The patch uses the same `isZeroPageSectionName`
predicate in `canUseZeroPageIdx`, resolving aliases first.

The second hunk fixes a real but narrow bug: `STAbsIdx` was checked on operand
0, which is the *stored value* register, so the predicate could never be true
for a store. Its reach is smaller than it first looks, and I measured before
believing my own first reading: stores into address-space-1 globals (the ones
`MOSZeroPageAlloc` creates) already select the `STZpIdx` pseudo at instruction
selection, so the check only decides stores whose base is the global symbol
behind an address-space-0 pointer, that is section-placed globals or an
address-space-1 global reached through a cast. Neither the SNES corpus nor the
c-torture corpus contains one (both measured below, zero changed programs), so
this is a consistency and code-size fix for user code that places globals in
zero-page sections, not a broad size win.

**Why zero-page,X is the right side.** A zero-page global must fit wholly in
page zero, so an in-bounds index can never carry the address out of the page,
and `zp,x` (which wraps within the page) computes the same address as `abs,x`
in two bytes instead of three. The argument covers valid accesses within the object; out-of-bounds probes
only establish encoding consistency, not runtime semantics. The assembler makes the same
call on its own: for a symbol defined in a zero-page section it selects the
8-bit form even without `mos8()`, which is why a large negative offset
(`samples-200,x`, printed without the modifier because `lowerOperand` only
applies it for offsets ≥ −128) still reassembles to exactly the direct object.

The other address-space-only check in the same file, `lowerSymbolOperand`, is
not an inconsistency: `lowerOperand` calls it and then applies the section
classification as a "last chance" step, so printing and fixups already agreed
for sections; only the opcode choice did not.

## What I verified myself

| Check | Result |
|---|---|
| The three new tests on my assertion build (stacked on 0030…0035) | all PASS; each compares instruction bytes and complete direct vs reassembled objects |
| MOS CodeGen + MC suites, assertion build | 140 pass, 1 unsupported, 0 fail |
| Offset edge: `@samples - 200`, `+ 300`, `- 129` indexed loads/stores | verifier clean; direct and reassembled objects identical |
| Applies to the assertion tree with 0030…0035 present; applies to pristine per Codex's record | clean |
| c-torture, 1,390 files × `-O0/-O2/-Os`, before → after 0036 | 4,170 comparisons: 4,109 identical successful pairs, 61 failures on both sides, 0 new failures (no zero-page sections in that corpus, and zero-page-allocated stores already use `STZpIdx`) |
| SNES corpus, 137 programs (installed `mos-clang -Os` with the SDK config → IR → assertion `llc`, `mosw65816`) | 137/137 compile with the verifier before and after; `.text` 214,821 bytes both sides, 0 programs change; `llc -S \| llvm-mc` equals `llc -filetype=obj` for all 137 both before and after |
| Project toolchain (already carrying 0036) on the MAME + bsnes-jg gate | 79 of 79 programs pass (host == default == +mos-a16 == +mos-xy16 on MAME and bsnes-jg), 0 fail |

## Notes on the draft

Accurate and complete; the `mos16(constant)` parser defect Codex found in its
numeric controls is correctly kept out of this patch and is tracked as its own
`[T4]` item.

Artifacts under `build/0030-claude-review/`: `llc-before-0036`, `llc-0036`,
`lit-0036.json`, `diff6-results.json`, `snes-size-0036.json`,
`corpus-a16-0036.log`; probes in the session scratchpad.

Follow-up: [Codex audit](0036-review-audit.md) confirms the implementation and
corrects the public scope and corpus accounting.

Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`,
`high` reasoning effort) for the original independent review, corpus and offset checks, and emulator gate.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`, `xhigh`
reasoning effort) for the follow-up audit and corrections to this record.
