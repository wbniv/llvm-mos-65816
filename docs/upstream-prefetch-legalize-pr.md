# [MOS] Legalize G_PREFETCH by dropping it

`__builtin_prefetch` aborts the backend on every MOS CPU:

```text
fatal error: error in backend: unable to legalize instruction: G_PREFETCH %0:_(p0), 1, 3, 1 (in function: p)
```

for `void p(char *q) { __builtin_prefetch(q); }`. Six gcc C-torture files
(`builtin-prefetch-1.c` … `builtin-prefetch-6.c`) fail at every optimization
level for this reason, and any portable code that uses the builtin cannot be
compiled for the target.

A prefetch is a hint. The 6502 has no cache and no prefetch instruction, so the
correct lowering is nothing: mark `G_PREFETCH` custom and erase it, the same way
AMDGPU and SPIR-V declare it always legal and AArch64 rewrites it into its
own instruction. Add a test for both `-O0` and `-O2` with the verifier, covering
the read and write forms at every locality.

Note that Clang emits `llvm.prefetch` with `i16` operands on 16-bit-`int`
targets when the rw/locality arguments are written explicitly, which the IR
verifier rejects independently of this change; that is fixed separately in
Clang (`CGBuiltin.cpp`, cast the immediates to `i32`).

Validated on llvm-mos `742d554bf08042b8df93d791c335260fadd16643` (identical to
`main` at the time of writing), assertions enabled:

- The new test fails on the unpatched `llc` (backend abort) at `-O0` and `-O2`
  and passes with the change.
- With the Clang fix applied as well, all six `builtin-prefetch-*.c` torture
  files compile at `-O0`, `-O2` and `-Os` with `-verify-machineinstrs`, both
  directly with `clang -c` and as IR through `llc`.
- MOS CodeGen and MC suites: 137 pass, 1 unsupported, 0 fail (includes the new prefetch test).

Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`, `high`
reasoning effort) for the diagnosis, implementation, test, validation, and PR
drafting.
