# Internal PR simulation — RetryJump xy16 spill store

**Status: not ready to submit.** The [RetryJump ROM](https://biohack.net/snes/retryjmp/) exposed an xy16 frame-index spill store that clobbers its own value.

## Proposed change

Preserve the spill value while materializing the frame-index address under xy16. The [investigation](../../investigations/2026-09-15-xy16-spill-reload-clobbers-store-value.md) retains the failure mechanism and regression witness.

## Submission gate

Reconcile the exact upstream entry point and a minimal standalone regression before converting this simulation into an upstream PR.
