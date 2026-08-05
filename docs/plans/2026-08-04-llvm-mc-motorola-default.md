# Preserve target Motorola-integer defaults in llvm-mc

**Status:** implemented, verified, and posted as [llvm-mos PR #587](https://github.com/llvm-mos/llvm-mos/pull/587)  
**Date:** 2026-08-04

## Scope

- Keep `AsmLexer`'s target-provided Motorola-integer default when the `llvm-mc` option is absent.
- Preserve explicit `-motorola-integers=true/false` override behavior.
- Add a focused MOS regression using `$ea` without the enabling flag.
- Carry the fix independently as `0025`; do not couple it to BRK PR #586.

## Verification

- Rebuilt the local `llvm-mc` target.
- Focused lit test passes.
- Default run emits `[0xa9,0xea]`; explicit false emits symbolic/fixup `[0xa9,A]`.
- Branch `wbniv:llvm-mc-preserve-motorola-default`, commit `579bc0f087c1`.
- Posted PR: [llvm-mos/llvm-mos #587](https://github.com/llvm-mos/llvm-mos/pull/587).
- PR body mirror: `docs/upstream-llvm-mc-motorola-default-pr.md`.
