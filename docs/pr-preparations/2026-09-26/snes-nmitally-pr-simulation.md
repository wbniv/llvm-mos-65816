# Simulated upstream PR — Define 65816 interrupt-entry width state

**Internal only; platform-series scope.** The [NMI Tally ROM](https://biohack.net/snes/nmitally/) exposed a 65816 C interrupt prologue inheriting unknown M/X widths.

## Proposed PR body

Give interrupt entry and its prologue an explicit width contract before generated C code executes. The [interrupt investigation](../../investigations/2026-08-03-65816-interrupt-width-prologue.md) is the technical source of truth.

## Acceptance before submission

Reconcile the SNES platform and ABI prerequisites, then replay the NMI Tally runtime gate and entry-state checks. This simulation holds the review shape without claiming an independently submit-ready compiler patch.
