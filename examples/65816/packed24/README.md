# packed-24 (addrspace 3) — fixtures for a DEFERRED feature

Test fixtures for the **packed-24 far pointer** (`AS_FarPacked`, addrspace 3) — the 3-byte storage form
of a far pointer in the [five-address-space model](../../../docs/plans/2026-06-21-320-five-address-space-model.md).

> **Status: DEFERRED** (2026-06-21). Increment A (the 3-byte *type*) was built + verified on the
> `wt/320-five-space` worktree (since torn down); Increment B (codegen to *use* packed pointers) is
> blocked on 24-bit (`s24`) width and is **deferred until the F2 far-value work lands on `main`** — so
> packed-24 builds on the complete far-value foundation it extends, instead of rebasing onto a moving
> base (both touch `getPointerWidthV` / the datalayout / the far legalizer rules). Full rationale +
> recipe + the exact Increment-B blocker: the plan's *§Build packed-24*.

## To rebuild packed-24 (when F2 has landed on `main`)

1. Apply the recorded Increment A recipe — exact diff in
   [`docs/plans/spikes/2026-06-21-320-packed24-incrementA.patch`](../../../docs/plans/spikes/2026-06-21-320-packed24-incrementA.patch)
   (`AS_FarPacked=3` + datalayout `p3:24:8` ×2 + clang `getPointerWidthV` case 3 → 24).
2. Rebuild the toolchain; the fixtures below are the gate.

## Fixtures

| file | increment | what it checks | status |
|------|-----------|----------------|--------|
| `incA_sizeof.c`  | A (type)    | `sizeof(packed far*)==3`, `table[16]==48 B` (vs 64 for 32-bit far) | **PASS** with Increment A applied (verified 2026-06-21) |
| `incA_storage.c` | A (storage) | a packed global / table emits 3-byte / 48-byte objects | **PASS** with Increment A applied (verified: `g`=3 B, `table`=48 B) |
| `incB_use.c`     | B (codegen) | store / load / deref a packed far pointer (`addrspacecast p2↔p3` + `load/store p3`) | **BLOCKED** — needs the `s24`-width work (the deferred Increment B) |

These are **compile-evidence / future-gate fixtures**, not green tests on `main` (Increment A/B aren't in
`main`'s toolchain) — kept here so the packed-24 rebuild has its regression gate ready. Compile with the
worktree toolchain once the recipe is applied:

```
mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 \
  -Os -std=c23 -mllvm -verify-machineinstrs -c incA_sizeof.c -o /dev/null
```
