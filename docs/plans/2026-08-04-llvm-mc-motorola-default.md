# Preserve target Motorola-integer defaults in llvm-mc

**Status:** implemented, verified, and posted as [llvm-mos PR #587](https://github.com/llvm-mos/llvm-mos/pull/587)  
**Date:** 2026-08-04

## Scope

- Keep `AsmLexer`'s target-provided Motorola-integer default when the `llvm-mc` option is absent.
- Preserve explicit `-motorola-integers=true/false` override behavior.
- Add a focused MOS regression using `$ea` without the enabling flag.
- Carry the fix independently as `0025`; do not couple it to BRK PR #586.

## Verification

**Run + recorded 2026-08-05**, on branch `llvm-mc-preserve-motorola-default` @ `579bc0f087c1` in
`~/llvm-mos`, build `~/llvm-mos/build-pr` (MOS-only, Release+asserts).

- Rebuilt the local `llvm-mc` target.

  ```
  $ md5sum bin/llvm-mc                       # before
  4fd650a043b19f8504f99842cc67b8dd  bin/llvm-mc
  $ ninja llvm-mc
  [...]
  [25/30] Building CXX object tools/llvm-mc/CMakeFiles/llvm-mc.dir/llvm-mc.cpp.o
  [...]
  [30/30] Linking CXX executable bin/llvm-mc
  $ md5sum bin/llvm-mc                       # after
  959d44c2912aadfc53b2ecec22aeb611  bin/llvm-mc
  ```

  Binary hash changed (`4fd650a0...` -> `959d44c2...`), confirming the rebuild actually picked up
  the source change rather than serving a stale binary. PASS.

- Focused lit test passes.

  ```
  $ ./bin/llvm-lit -v ../llvm/test/MC/MOS/motorola-integers-default.s
  -- Testing: 1 tests, 1 workers --
  PASS: LLVM :: MC/MOS/motorola-integers-default.s (1 of 1)

  Testing Time: 0.12s

  Total Discovered Tests: 1
    Passed: 1 (100.00%)
  ```

  PASS.

- Default run emits `[0xa9,0xea]`; explicit false emits symbolic/fixup `[0xa9,A]`.

  ```
  $ echo '        lda #$ea' | ./bin/llvm-mc -triple mos -show-encoding
          lda     #234                            ; encoding: [0xa9,0xea]

  $ echo '        lda #$ea' | ./bin/llvm-mc -triple mos -show-encoding -motorola-integers=false
          lda     #$ea                            ; encoding: [0xa9,A]
                                          ;   fixup A - offset: 1, value: $ea, kind: Imm8
  ```

  Both match the spec exactly: with no flag, `$ea` is lexed as Motorola hex (target default
  preserved) and encodes numerically as `0xea`; with `-motorola-integers=false`, `$` is no longer a
  hex prefix, so `$ea` is lexed as a separate token and the operand becomes an unresolved fixup
  (`A`). PASS.

- Branch `wbniv:llvm-mc-preserve-motorola-default`, commit `579bc0f087c1`.
- Posted PR: [llvm-mos/llvm-mos #587](https://github.com/llvm-mos/llvm-mos/pull/587).
- PR body mirror: `docs/upstream-llvm-mc-motorola-default-pr.md`.

**Result: all steps PASS.**
