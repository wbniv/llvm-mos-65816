# Simulated SDK PR — Restore page-1 stack in native longjmp

**Internal only; SDK/platform scope.** The [Backtrack ROM](https://biohack.net/snes/backtrack/) exposed native `longjmp` failing to reconstruct the page-1 hard stack.

## Proposed PR body

Correct the native stack reconstruction immediate-width encoding and retain the multi-frame regression. The [investigation](../../investigations/2026-09-15-longjmp-page1-reconstruct-never-executes.md) preserves the minimal witness and observed machine state.

## Acceptance before submission

Confirm the SDK destination and native-stack contract, then replay the minimal witness, `backtrack_sim`, and the existing one-frame guard. This is a simulated SDK PR, not a claim that it has been submitted.
