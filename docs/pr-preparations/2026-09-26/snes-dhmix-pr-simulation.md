# Simulated upstream PR — Legalize native s64 unmerge and odd-width extension

**Internal only; feature-series scope.** The [DH Mix ROM](https://biohack.net/snes/dhmix/) exposed missing native-width s64 unmerge and odd-width extension legalization.

## Proposed PR body

Complete the 65816 legalizer glue for the s64 split and odd-width extension shapes described in the [investigation](../../investigations/2026-06-30-a16-s64-unmerge-anyext-legalize-crash.md).

## Acceptance before submission

Submit only with the complete reconciled target series. Replay the minimal C reproducer, `dev/run.sh dhmix`, and the native-width corpus slice; do not split an incomplete 65816 feature into a misleading standalone PR.
