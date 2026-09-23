# [MOS] Legalize G_PREFETCH by dropping it

MOS cannot legalize `G_PREFETCH`; for example,
`void p(char *q) { __builtin_prefetch(q); }` reaches a backend error:

```text
fatal error: error in backend: unable to legalize instruction: G_PREFETCH %0:_(p0), 1, 3, 1 (in function: p)
```

The [intrinsic contract](https://llvm.org/docs/LangRef.html#llvm-prefetch-intrinsic)
permits unsupported prefetch hints to have no effect. Mark `G_PREFETCH` custom
and erase it for MOS. Instructions that compute the address remain subject to
their own semantics, including any observable side effects. Add a test at
`-O0` and `-O2` with MachineVerifier, covering a read hint at locality 3 and
write hints at all four localities.

Note that Clang emits `llvm.prefetch` with `i16` operands on 16-bit-`int`
targets when the rw/locality arguments are written explicitly, which the IR
verifier rejects independently of this change; that is fixed separately in
Clang (`CGBuiltin.cpp`, cast the immediates to `i32`).

Validated on llvm-mos `742d554bf08042b8df93d791c335260fadd16643`, assertions enabled:

- The new test fails on the unpatched `llc` (backend abort) at `-O0` and `-O2`
  and passes with the change.
- With the Clang fix applied as well, all six `builtin-prefetch-*.c` torture
  files compile at `-O0`, `-O2` and `-Os` with `-verify-machineinstrs`, both
  directly with `clang -c` and as IR through `llc`.
- Independent build with this patch alone: MOS CodeGen 84 pass, one unsupported;
  MC 46 pass, zero failures.
- An expanded legalization check covers both supported pointer address spaces,
  all localities, and data/instruction-cache read hints plus data-cache write
  hints. All 14 stock MOS CPUs fail on pristine upstream and pass with the fix
  at `-O0` and `-O2`. Every hint is removed, while a volatile store and an
  address-producing call are retained. These extra checks stop after legalization.

Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`, `high`
reasoning effort) for the diagnosis, implementation, test, validation, and PR
drafting.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`, `xhigh`
reasoning effort) for independent review, standalone validation, and corrections
to the submission evidence.
