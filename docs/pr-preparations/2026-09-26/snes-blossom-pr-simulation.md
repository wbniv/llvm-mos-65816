# Simulated upstream PR — Route far memset to the far runtime

**Internal only; do not submit yet.** The [Blossom ROM](https://biohack.net/snes/blossom/) exposed address-space-2 `memset` selecting the near runtime and losing the destination bank.

## Proposed PR body

Route address-space-2 `G_MEMSET` to the far runtime entry point and preserve its far-pointer ABI. The [defect record](../../defects/mos-far-memset-wrong-bank.json) contains the exact C, preprocessed input, MIR, baseline/candidate identities, and physical-WRAM red/green evidence.

## Acceptance before submission

Reconcile the target revision, runtime ownership, and standalone regression location; then replay the preserved input and the Blossom runtime check. This is a complete review packet, not an assertion that the upstream destination is ready.
