# Simulated upstream PR — Preserve xy16 frame-index spill values

**Internal only; do not submit yet.** The [RetryJump ROM](https://biohack.net/snes/retryjmp/) exposed an xy16 frame-index spill store that clobbers its own value.

## Proposed PR body

Preserve the spill value while materializing the frame-index address under xy16. The [investigation](../../investigations/2026-09-15-xy16-spill-reload-clobbers-store-value.md) retains the failure mechanism and regression witness.

## Acceptance before submission

Reconcile the exact upstream entry point, produce a minimal standalone regression, and replay the RetryJump differential gate. This simulation provides the PR review shape without recording an upstream submission.
