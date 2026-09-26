# Patch 0028: search for an ordinary 6502 C trigger

## Result

No ordinary 6502 C reproducer for patch 0028 was found in this search. The
constructed MIR regression fails with explicit `-mcpu=mos6502` and no native-width
features, but that does not establish a naturally generated C trigger.

The complete stock-upstream C compilation matrix had **570 cases: 568 passed and
two failed for a separate post-RA expansion problem unaffected by 0028**. The
publication hold until #320/#321 are ready to open remains in place.

The separate failure is now diagnosed and fixed by
[patch 0030](../pr-preparations/2026-09-22/0030-validation.md): copy expansion
reuses a physical value without clearing its earlier kill flag. The original
input's assembly is unchanged by the repair at all six optimization levels.

## Compiler and inputs

The frontend and backend were built from unpatched llvm-mos revision
`742d554bf08042b8df93d791c335260fadd16643`. This compiler is retained as the
[permanent upstream reference](../upstream-reference-build.md). It is a Release
build with assertions disabled; every compilation explicitly enabled
`-verify-machineinstrs`.

All tests selected `--target=mos -mcpu=mos6502`; none enabled `+mos-a16`,
`+mos-xy16`, or far-pointer features. The final matrix compiled through object
emission, including the integrated assembler:

| Inputs | Optimization levels |
|---|---|
| `rcundef.c`, `rcundef2.c`, `newton_sim.c`, `lsystem_sim.c` | `-O0`, `-O1`, `-O2`, `-O3`, `-Os`, `-Oz` |
| All 137 `examples/snes/corpus/*.c` files | `-O1`, `-O2`, `-Os`, `-Oz` |
| One generated translation unit with 35 pointer-pressure functions | All six levels above |

Overlapping source/optimization cases were run once, giving 570 cases across 140
translation units. The generated pointer tests varied pointer selection, loops,
calls, dereferences, and low/high-byte extraction with 1–12 live pointer values.
These were constructed search probes, not demo-derived reproductions.

The SNES corpus wrappers contain a `wai` idle instruction. Scratch copies replaced
only `__asm__ volatile("wai")` with `__asm__ volatile("")`, retaining the volatile
barrier loop while allowing genuine 6502 object assembly. Original source files
were not edited; the two `examples/65816/rcundef*.c` inputs need no replacement.
The compiler used its own resource headers and an explicit include path to
`vendor/llvm-mos-sdk/mos-platform/common/include`.

Before stock Clang finished building, a preliminary scan used the downstream
frontend targeting plain 6502, then normalized the emitted IR datalayout for the
unpatched upstream backend. All 24 witness cases, 548 corpus cases, and six
pointer-probe cases passed through `virtregrewriter`. Comparing patched and
unpatched upstream output for those 548 corpus IR inputs produced **identical
post-rewriter MIR in every case**. These preliminary results are separate from
the final stock-frontend object-compilation matrix.

## The two failures are not 0028

At `-O0`, both `examples/65816/rcundef.c` and the Newton corpus wrapper fail in
`newton_step` **after post-RA pseudo instruction expansion**:

```text
*** Bad machine code: Using an undefined physical register ***
- instruction: $rc6 = STImag8 $y
- operand 1:   $y
```

The smaller input can be compiled directly, without any source adaptation:

```sh
dev/upstream-reference.sh clang --target=mos -mcpu=mos6502 -O0 \
  -mllvm -verify-machineinstrs -c examples/65816/rcundef.c \
  -o build/newton-step-upstream-6502.o
```

For each input, stock Clang emitted IR which was then passed to both saved
upstream `llc` binaries at `-O=0`: one unpatched, one with precisely the 0028
refactor. Both binaries failed at the same expansion stage and instruction.
Thus these failures do not demonstrate 0028's identity-copy mechanism. The
subsequent 0030 investigation identifies the stale kill and validates its repair;
no runtime miscompile is claimed.

## MIR control and scope

```sh
dev/upstream-reference.sh llc -mtriple=mos -mcpu=mos6502 \
  -run-pass=greedy,virtregrewriter -verify-machineinstrs \
  vendor/llvm-mos/llvm/test/CodeGen/MOS/virtregrewriter-undef-lane-identity-copy.mir \
  -o /dev/null
```

This constructed control fails with an undefined `$rc3` on the unpatched
reference. The patched compiler retains the required `KILL` and passes. This
establishes that the MIR mechanism itself does not need the #320/#321 flags.
The negative C search is bounded by the inputs and options above; it does not
prove that stock 6502 compilation can never produce the pattern.

## Local evidence

Under `build/0028-6502/`:

- `stock-full/results.json`, `stock-full.log`, and per-input logs record the final
  commands and outcomes; `stock-full/sources/` retains the adapted inputs.
- `full-check.py` reproduces the final matrix; `make-pointer-probes.py` and
  `pointer-probes.c` record the generated search probes.
- `preliminary*/results.json`, `preliminary-corpus-comparison.json`, `probe.py`,
  and `compare.py` record the early backend scan and output comparisons.
- `newton-stock.O0.ll`, `rcundef-stock.O0.ll`, and their `.unpatched.log` /
  `.patched.log` files record the separate expansion failures.
- `plain6502-synthetic.log` records the constructed MIR control.

These scratch scripts name the original build paths. For later tests, use the
saved reference wrapper so an incremental rebuild cannot silently change the
baseline.
