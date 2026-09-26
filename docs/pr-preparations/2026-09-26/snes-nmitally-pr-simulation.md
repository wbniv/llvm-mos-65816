# Internal PR simulation — NMI Tally interrupt widths

**Status: platform-series work; not ready to submit.** The [NMI Tally ROM](https://biohack.net/snes/nmitally/) exposed a 65816 C interrupt prologue inheriting unknown M/X widths.

## Proposed change

Give the interrupt entry/prologue an explicit width contract before generated C code executes. The [interrupt investigation](../../investigations/2026-08-03-65816-interrupt-width-prologue.md) is the technical source of truth.

## Submission gate

This requires the SNES platform and ABI prerequisites, so it is not a standalone compiler PR. Reconcile the platform series before opening an upstream submission.
