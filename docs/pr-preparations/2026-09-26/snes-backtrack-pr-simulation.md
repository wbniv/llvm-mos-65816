# Internal PR simulation — Backtrack native longjmp

**Status: SDK/platform work; not ready to submit.** The [Backtrack ROM](https://biohack.net/snes/backtrack/) exposed native `longjmp` failing to reconstruct the page-1 hard stack.

## Proposed change

Correct the native stack reconstruction immediate-width encoding and retain the multi-frame regression. The [investigation](../../investigations/2026-09-15-longjmp-page1-reconstruct-never-executes.md) preserves the minimal witness and observed machine state.

## Submission gate

The fix belongs with the 65816-aware SDK/platform implementation. Confirm the SDK destination and native stack contract before preparing an upstream PR.
