# [clang] Emit __builtin_prefetch's rw and locality operands as i32

`llvm.prefetch` takes `i32` for its rw, locality and cache-type operands.
`__builtin_prefetch` passes the rw and locality arguments through
`EmitScalarOrConstFoldImmArg`, which preserves the promoted integer expression
type. For plain integer literals on targets whose `int` is 16 bits (MSP430,
AVR, MOS), an explicit-argument call has an incompatible signature:

```llvm
call void @llvm.prefetch.p0(ptr %p, i16 1, i16 2, i32 1)
```

Wider expressions also fail on conventional targets. On x86-64,
`__builtin_prefetch(p, 1L, 2L)` emits `i64` options. The builtin is variadic,
so its explicit options are not restricted to C `int`. The IR verifier rejects
both mismatches. Omitted options are unaffected because their constants are
constructed as `Int32Ty` directly.

Cast both operands to `i32` after evaluating them; for the immediate
arguments the builtin requires this folds to a constant. Sema already limits
rw to 0–1 and locality to 0–3, so both widening and narrowing preserve accepted
values. The bundled test runs on `msp430` and `x86_64` and covers the default
and two-argument forms, plain literals, `long` and `long long` arguments; the
literal cases discriminate on `msp430`, the wide-argument cases on both.

Target audience: llvm/llvm-project (the change is in generic Clang CodeGen).
It is carried in llvm-mos until it lands upstream.

Validated against llvm-mos `742d554bf08042b8df93d791c335260fadd16643`:

- The new test fails on the unpatched Clang on both triples (`i16` operands
  for literals on `msp430`; `i64` operands for `long`/`long long` arguments on
  both) and passes with the change.
- An independent frontend matrix checks eight option forms on MOS, MSP430,
  AVR, and x86-64, including wider arguments and the two-argument form. All 32
  patched modules pass the LLVM verifier; 21 fail on the baseline. The 11
  already-valid modules retain byte-identical IR.
- Existing address-space and poison-argument tests pass before and after.
  Range and nonconstant-argument diagnostics remain intact on all four targets.
- With the MOS legalizer change (`G_PREFETCH` dropped), all six
  `builtin-prefetch-*.c` C-torture files compile at `-O0`, `-O2` and `-Os`
  with `-verify-machineinstrs`; before, every one failed the IR verifier with
  `Intrinsic called with incompatible signature`.

Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`, `high`
reasoning effort) for the diagnosis, implementation, test, validation, and PR
drafting.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`, `xhigh`
reasoning effort) for independent review, wider-argument diagnosis, frontend
validation, and corrections to the submission evidence.
