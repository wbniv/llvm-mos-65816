# [MOS] Report an error on out-of-range PCRel8/PCRel16 branch fixups

<!-- MINTED + VERIFIED 2026-08-04, NOT POSTED (posting is user-triggered; sequenced WITH/AFTER #549).
     Source: patches/llvm-mos/0019-mos-branch-range-diagnostic.patch (in the fork's tracked
     standalone stack, e8ccda8; found during the Round-7 demo work when an out-of-range branch
     assembled silently).
     ⚠ COORDINATION: llvm-mos PR #549 (mlund, [65CE02] 16-bit branch PC-relative offset fix)
     modifies the SAME hunk of MOSAsmBackend::applyFixup — the PCRel8/PCRel16 cases around
     getRelativeMOSPCCorrection. Checked 2026-08-04 via `gh pr view 549`: #549 is still **OPEN**,
     not merged — post this PR WITH or AFTER #549, not before. The changes are complementary
     (theirs fixes the correction constant per CPU, this adds range diagnostics on the corrected
     value); on a textual conflict this branch's hunk yields and rebases onto #549's landed form,
     since #549 changes the corrected *value* this patch then range-checks. If #549 merges before
     this posts, rebase mos-branch-range-diagnostic onto it and re-verify before posting.
     Branch: mos-branch-range-diagnostic, cut from upstream main 1f334fef02b5, one commit
     4195df6e3b56, living locally in ~/llvm-mos. 0019 applied with `git apply` cleanly (no
     hand-resolution needed — `git apply --check` reported no conflicts against tip).
     Verified in ~/llvm-mos/build-pr (MOS-only, Release+asserts) under the 2026-08-04/05
     tool-complete methodology rule (every tool the suites RUN — llvm-mc, llc, opt, llvm-readelf,
     llvm-objdump, FileCheck, not, count — rebuilt and confirmed newer than the changed source
     before quoting numbers; an exit-127 in a lit log is an environment defect, not a test
     result):
       - branch-range-errors.s: confirmed red without the patch (binary hash matched the
         pre-patch build exactly; llvm-mc silently truncated the offset, no diagnostic, so
         FileCheck saw empty stdin and errored) and green with it (binary hash changed on
         rebuild). Proven via `git stash` of MOSAsmBackend.cpp + rebuild, both directions.
       - llvm/test/MC/MOS/: 40/40 passed, 0 failed, exit 0.
       - llvm/test/CodeGen/MOS/: 79 discovered, 78 passed, 1 UNSUPPORTED
         (getchar-regression.ll, upstream-preexisting), 0 failed, exit 0.
     Post commands (posting is user-triggered):
       git -C ~/llvm-mos push origin mos-branch-range-diagnostic
       gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-branch-range-diagnostic --base main \
         --title "[MOS] Report an error on out-of-range PCRel8/PCRel16 branch fixups" \
         --body-file <(sed '2,/^-->$/d; 1d' docs/upstream-branch-range-diagnostic-pr.md)
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

`llvm/test/MC/MOS/branch-range-errors.s` pins both messages.

## Relation to #549

#549 fixes the *value* of the PC-relative correction per CPU (65CE02 16-bit branches are
PC+2-based, unlike the 65816's PC+3 `BRL`); this patch adds *range checking* of the corrected
value. They touch the same few lines and are designed to compose: whichever lands first, the
other rebases trivially, and the diagnostics then guard #549's corrected offsets too.
