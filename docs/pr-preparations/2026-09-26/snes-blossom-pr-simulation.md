# Internal PR simulation — Blossom far memset

**Status: not ready to submit.** This packet preserves the prospective submission boundary for the [Blossom ROM](https://biohack.net/snes/blossom/), which exposed far `memset` selecting the near runtime.

## Proposed change

Route address-space-2 `G_MEMSET` to the far runtime entry point with the far-pointer ABI. The preserved [defect record](../../defects/mos-far-memset-wrong-bank.json) contains the exact C, preprocessed input, MIR, baseline/candidate identities, and runtime red/green evidence.

## Submission gate

Do not submit until the exact destination revision, runtime ownership, and standalone regression placement are reconciled. This simulation is not an upstream PR and records no claimed upstream readiness.
