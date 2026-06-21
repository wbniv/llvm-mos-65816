# packed-24 (addrspace 3) — fixtures

Test fixtures for the **packed-24 far pointer** (`AS_FarPacked`, addrspace 3) — the 3-byte storage form
of a far pointer in the [five-address-space model](../../../docs/plans/2026-06-21-320-five-address-space-model.md).

> **Status: BUILT + verified** (2026-06-21). Increment A (the 3-byte *type*) and Increment B (codegen to
> store / load / deref a packed far pointer) are both DONE on `wt/320-packed24-incB` (off post-F2 `main`),
> shipped as `patches/llvm-mos/0006-320-packed24.patch`. Full record + the exact approach: the plan's
> *§Build packed-24 → Increment B* and the [handoff](../../../docs/plans/2026-06-21-320-packed24-incrementB-handoff.md).

## Fixtures

| file | increment | what it checks | status |
|------|-----------|----------------|--------|
| `incA_sizeof.c`  | A (type)    | `sizeof(packed far*)==3`, `table[16]==48 B` (vs 64 for 32-bit far) | **PASS** (compile gate) |
| `incA_storage.c` | A (storage) | a packed global / table emits 3-byte / 48-byte objects | **PASS** (`g`=3 B, `table`=48 B) |
| `incB_use.c`     | B (codegen) | store / load / deref a packed far pointer (`addrspacecast p2↔p3` + `load/store p3`) | **PASS** (`-verify-machineinstrs` clean: 3-byte store, far deref) |
| `packed24_e2e.c` | B (e2e)     | runnable: store a far ptr (bank $01) into a packed slot, read back, deref → 0xF3 on both emulators | **PASS** — `dev/run.sh packed24` (MAME + bsnes-jg) |

`incA_*` / `incB_use.c` are compile gates; `packed24_e2e.c` is the runnable differential test (proves the
**bank byte survives** the 3-byte packing — the far pointer targets bank $01, so a dropped bank would read
the wrong byte). Compile a fixture:

```
mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 \
  -Os -std=c23 -mllvm -verify-machineinstrs -c incB_use.c -o /dev/null
```

Run the e2e differential (host: `dev/run.sh packed24`; bsnes-jg leg via `dev/run.sh xcheck`).
