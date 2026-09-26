# Internal PR simulation — L-System xy16 memmove

**Status: feature-series work; not ready to submit.** The [L-System ROM](https://biohack.net/snes/lsystem/) exposed an xy16 indexed in-place `memmove` width-state miscompile.

## Proposed change

Ensure the indexed load/store sequence establishes the required X width around the in-place move. The [investigation](../../investigations/2026-06-29-xy16-inplace-memmove-16bit-index-miscompile.md) retains the trigger and regression evidence.

## Submission gate

This is part of the unfinished 65816 feature series, not an independent upstream patch. Reconcile it with the target submission prerequisites before preparing a standalone PR.
