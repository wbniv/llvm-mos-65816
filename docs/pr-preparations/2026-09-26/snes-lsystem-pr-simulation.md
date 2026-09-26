# Simulated upstream PR — Preserve X width in xy16 in-place memmove

**Internal only; feature-series scope.** The [L-System ROM](https://biohack.net/snes/lsystem/) exposed an xy16 indexed in-place `memmove` width-state miscompile.

## Proposed PR body

Ensure the indexed load/store sequence establishes the required X width around the in-place move. The [investigation](../../investigations/2026-06-29-xy16-inplace-memmove-16bit-index-miscompile.md) retains the trigger, mechanism, and regression evidence.

## Acceptance before submission

Fold this packet into the reconciled 65816 target series, then run the minimal repro and the L-System ROM gate across its declared width configurations. It is an internal simulated PR, not a claim that a standalone upstream patch is appropriate.
