# [clang] Emit __builtin_prefetch's rw and locality operands as i32

`llvm.prefetch` takes `i32` for its rw, locality and cache-type operands.
`__builtin_prefetch` passes the rw and locality arguments through
`EmitScalarOrConstFoldImmArg`, which produces them in the C `int` type, so on
targets whose `int` is 16 bits (MSP430, AVR, MOS) an explicit-argument call is
emitted with an incompatible signature:

```llvm
call void @llvm.prefetch.p0(ptr %p, i16 1, i16 2, i32 1)
```

The IR verifier rejects it (`Intrinsic called with incompatible signature`),
and pipelines that do not run the verifier lower an ill-typed call. The
default-argument form is unaffected because those constants are built as
`Int32Ty` directly. The existing `FIXME` on that code ("Technically these
constants should of type 'int', yes?") is the other half of the same
observation.

Cast both operands to `i32` after evaluating them; for the immediate
arguments the builtin requires this folds to a constant. Add a test on
`msp430` (and `x86_64` as the unchanged control) checking the emitted operand
types for both the explicit and the default forms.

Target audience: llvm/llvm-project (the change is in generic Clang CodeGen).
It is carried in llvm-mos until it lands upstream.

Validated on llvm-mos `742d554bf08042b8df93d791c335260fadd16643` (Clang and
LLVM in lockstep with upstream):

- The new test fails on the unpatched Clang for `msp430` (the explicit form
  is emitted with `i16` operands) and passes with the change; the `x86_64`
  control passes before and after.
- With the MOS legalizer change (`G_PREFETCH` dropped), all six
  `builtin-prefetch-*.c` C-torture files compile at `-O0`, `-O2` and `-Os`
  with `-verify-machineinstrs`; before, every one failed the IR verifier with
  `Intrinsic called with incompatible signature`.

Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`, `high`
reasoning effort) for the diagnosis, implementation, test, validation, and PR
drafting.
