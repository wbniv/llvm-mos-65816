# Internal PR simulation — DH Mix s64 legalization

**Status: feature-series work; not ready to submit.** The [DH Mix ROM](https://biohack.net/snes/dhmix/) exposed missing native-width s64 unmerge and odd-width extension legalization.

## Proposed change

Complete the 65816 legalizer glue for the s64 split and odd-width extension shapes described in the [investigation](../../investigations/2026-06-30-a16-s64-unmerge-anyext-legalize-crash.md).

## Submission gate

The work is folded into the local 65816 feature series and is not a standalone upstream artifact. Submit only as part of a reconciled, complete target series.
