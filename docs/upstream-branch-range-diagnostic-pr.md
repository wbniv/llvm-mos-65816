# [MOS] Report an error on out-of-range PCRel8/PCRel16 branch fixups

<!-- DRAFT 2026-08-04 — NOT MINTED, NOT VERIFIED, NOT POSTED (posting is user-triggered).
     Source: patches/llvm-mos/0019-mos-branch-range-diagnostic.patch (in the fork's tracked
     standalone stack, e8ccda8; found during the Round-7 demo work when an out-of-range branch
     assembled silently).
     ⚠ COORDINATION: llvm-mos PR #549 (mlund, [65CE02] 16-bit branch PC-relative offset fix)
     modifies the SAME hunk of MOSAsmBackend::applyFixup — the PCRel8/PCRel16 cases around
     getRelativeMOSPCCorrection. Post this WITH or AFTER #549 and rebase over whichever lands
     first; the changes are complementary (theirs fixes the correction constant per CPU, this
     adds range diagnostics on the corrected value).
     BEFORE POSTING (per the 2026-08-04 methodology rule): mint off upstream tip, red/green the
     new branch-range-errors.s test, and run the FULL MC+CodeGen suites with the complete tool
     set (opt + llvm-readelf built) — quote only tool-complete numbers. Verify the extraction is
     non-empty and starts at "## Summary".
     Post commands (after mint+verify):
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
