# [MOS] Report an error on out-of-range PCRel8/PCRel16 branch fixups

<!-- ✅ POSTED 2026-08-05 as llvm-mos/llvm-mos PR #591 (wbniv:mos-branch-range-diagnostic @
     4195df6e3b56; a user-triggered companion post alongside open #549, with a courtesy comment
     left on #549: https://github.com/llvm-mos/llvm-mos/pull/549#issuecomment-5188046767).
     Source: patches/llvm-mos/0019-mos-branch-range-diagnostic.patch (in the fork's tracked
     standalone stack, e8ccda8; found during the Round-7 demo work when an out-of-range branch
     assembled silently).
     ⚠ COORDINATION: llvm-mos PR #549 (mlund, [65CE02] 16-bit branch PC-relative offset fix)
     modifies the SAME hunk of MOSAsmBackend::applyFixup — the PCRel8/PCRel16 cases around
     getRelativeMOSPCCorrection. Checked 2026-08-04 via `gh pr view 549`: still **OPEN**, not
     merged. The changes are complementary (theirs fixes the correction constant per CPU, this
     adds range diagnostics on the corrected value); on a textual conflict this branch's hunk
     yields and rebases onto #549's landed form. If #549 merges, rebase
     mos-branch-range-diagnostic onto it and re-verify before pushing further.

     ✅ PUSHED 2026-08-05: the second commit `b47ed3ee08e2` now sits on top of the posted
     `4195df6e3b56` on PR #591. It did NOT amend the posted commit, so
     the PR's existing history is untouched. It hardens `0019` with a #549-class regression net
     (postmortem: `long-branches-65ce02.s`'s own CHECK values were golden output copied from the
     very buggy correction constant #549 fixes, and this branch's own `branch-range-errors.s`
     originally only checked a displacement — 128 filler bytes over — that's out of range under
     *either* a correct or an off-by-one constant, so it discriminated nothing about which one is
     running):
       - Boundary-exact legal/illegal pairs at the PCRel8 and PCRel16 edges (new
         `branch-range-boundary.s` for the legal encodings, extended `branch-range-errors.s` for
         the illegal mirror one byte past each edge) — the same test proves both the range check
         and the correction arithmetic at the edge.
       - A byte-exact resolved-fixup matrix (new `branch-range-matrix-bcc8.s`,
         `branch-range-matrix-65816.s`) across mos6502 `bcc`, mosw65816 `bra`/`brl`, and
         mos65ce02 8-bit `bcc`, forward and backward, hand-derived from 6502-family relative-
         addressing semantics (displacement = target − address-of-next-instruction) and verified
         against the tool, never captured from it.
       - The 65CE02 16-bit `bcc` rows (new `branch-range-matrix-65ce02-16bit-pending-549.s`),
         written with the DATASHEET-CORRECT opcode+2-relative displacement rather than what this
         tree's still-buggy `applyFixup` emits today (opcode+3-relative, off by one low). `XFAIL`d
         and cited to #549 by name; deleting the `XFAIL` line after the #549 rebase is the signal
         that both fixes compose correctly — an unexpected `XPASS` there is a positive result.
     Re-verified in ~/llvm-mos/build-pr under the tool-complete methodology rule (llvm-mc, llc,
     opt, llvm-readelf, llvm-objdump rebuilt/confirmed current; `ninja llvm-readelf` reported "no
     work to do", confirming by the build graph itself — not just mtime — that it has no
     dependency on the changed source): the new `branch-range-errors.s` boundary checks proven
     red without `0019` (binary hash matched the pristine pre-`0019` build exactly) and green with
     it; `llvm/test/MC/MOS/` 44 total — 43 passed, 1 expected `XFAIL` (the gated 65CE02 file), 0
     failed, exit 0; `llvm/test/CodeGen/MOS/` unchanged, 79 total — 78 passed, 1 pre-existing
     `UNSUPPORTED` (`getchar-regression.ll`), 0 failed, exit 0.

     ✅ POSTED to #591 on 2026-08-05:
     https://github.com/llvm-mos/llvm-mos/pull/591#issuecomment-5189214169
       "Added a regression net for the #549 class of bug this PR's range check would otherwise
       miss: boundary-exact legal/illegal pairs at the PCRel8/PCRel16 edges, and a byte-exact
       resolved-fixup matrix across mos6502/mosw65816/mos65ce02, all hand-derived from the
       datasheet rather than captured from the assembler. The 65CE02 16-bit rows are written with
       the datasheet-correct values `#549` restores and are `XFAIL`'d against today's still-buggy
       correction constant — they'll flip to passing (and lose the `XFAIL`) once this rebases onto
       #549, which is a nice joint proof that the two PRs compose correctly."

     The branch and explanatory comment are both published.
-->

## Summary

`MOSAsmBackend::applyFixup` applies the PC-relative correction to `PCRel8`/`PCRel16` branch
fixups and writes the result without checking that it fits: a branch whose target is out of
range assembles silently, with the offset truncated into the encoding — the branch lands
somewhere else, with no diagnostic at any stage.

This patch checks resolved `PCRel8`/`PCRel16` values against their ranges after the
correction is applied, and reports a source-located error when they don't fit:

```
error: 8-bit branch target out of range
error: 16-bit branch target out of range
```

`llvm/test/MC/MOS/branch-range-errors.s` pins both messages; it is red without the change (the
offset truncates silently, so no diagnostic is emitted) and green with it.

## Tests

Beyond the two error messages, this PR adds a regression net for the arithmetic that decides
them, hand-derived from 6502-family relative-addressing semantics (displacement = target −
address-of-next-instruction) and verified against the assembler rather than captured from it:

- **Boundary-exact pairs**: `branch-range-boundary.s` pins the legal encoding at the last valid
  displacement for both `PCRel8` (`beq`, ±127/−128) and `PCRel16` (`brl`, ±32767/−32768);
  `branch-range-errors.s` pins the error one byte past each edge. The same displacement family is
  the same test at the edge, so this exercises the range check and the correction arithmetic
  together.
- **CPU × branch-kind × direction matrix**: `branch-range-matrix-bcc8.s` (mos6502 and mos65ce02
  8-bit `bcc`, forward/backward) and `branch-range-matrix-65816.s` (mosw65816 `bra`/`brl`,
  forward/backward) pin byte-exact resolved encodings at a modest distance via
  `llvm-mc | llvm-objdump -d`.
- **The 65CE02 16-bit rows** (`branch-range-matrix-65ce02-16bit-pending-549.s`) are written with
  the *datasheet-correct* opcode+2-relative displacement, not what this tree's `applyFixup` emits
  today (opcode+3-relative, off by one low) — the file is `XFAIL`'d and names #549 in a comment.

The suites are otherwise unchanged: `llvm/test/MC/MOS/` 44/44 (43 pass, 1 expected `XFAIL`),
`llvm/test/CodeGen/MOS/` 78 pass + 1 upstream-disabled, 0 failures.

## Relation to #549

#549 fixes the *value* of the PC-relative correction per CPU (65CE02 16-bit branches are
PC+2-based, unlike the 65816's PC+3 `BRL`); this patch adds *range checking* of the corrected
value. They touch the same few lines and are designed to compose: whichever lands first, the
other rebases trivially, and the diagnostics then guard #549's corrected offsets too.

This PR's test suite is also, concretely, a regression net for the exact class of bug #549 fixes:
the in-tree `long-branches-65ce02.s` test had its own `CHECK` values copied as golden output from
the buggy correction constant, so it couldn't have caught the bug it was nominally testing.
`branch-range-matrix-65ce02-16bit-pending-549.s` is the same test written the other way around —
datasheet-derived expectations that are currently `XFAIL` against the bug, and that flip to
passing the moment this branch rebases onto #549. That flip is a free, automatic proof that the
two PRs compose correctly, which is itself an argument for landing them together rather than in
either order with a gap between.
