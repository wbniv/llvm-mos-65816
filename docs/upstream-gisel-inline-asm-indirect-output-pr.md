# [GlobalISel] Support indirect register outputs in inline asm

`asm("" : "+g"(x))`, the usual optimization-barrier idiom, fails to compile on
every GlobalISel-only target and on any target when GlobalISel is not allowed
to fall back:

```text
error: unable to translate instruction: call (in function: g)
```

Clang lowers the `+g` operand to the multi-alternative, indirect constraint
`"=*imr,0"`: the output is written through a pointer argument, and the same
value is a tied input. Like SelectionDAG, `InlineAsmLowering` picks the
register alternative for it. SelectionDAG then handles the indirection itself
by storing the def register through the pointer after the asm; GlobalISel
never did, so the indirect output was counted as if it produced a call result
and the lowering gave up on the mismatch ("Expected the number of output
registers to match the number of destination registers (ResRegs=0,
OutputOperands=1)"). The same shape fails on AArch64 with
`-global-isel -global-isel-abort=1`, and unconditionally on MOS, whose only
instruction selector is GlobalISel; four gcc C-torture files fail there for
this reason. (X86's GlobalISel has no inline-asm lowering at all, so it is not
affected either way.)

Record the element type of indirect operands, keep indirect register outputs
out of the direct-output/result accounting, and after the `INLINEASM` copy each
such def register to a value of the element type and `G_STORE` it through the
pointer, with a machine memory operand on the pointer value and the type's ABI
alignment. Tied inputs referring to such an output need no change: the output
is still a register def. Outputs needing more than one register remain
unsupported, as they are for direct outputs.

Tests: a MOS test with the `"=*imr,0"` idiom and a bare `"=*r"` output,
checked at the IR-translator boundary (the `G_STORE` through the pointer) and
through full codegen with the verifier at `-O0` and `-O2`; an AArch64
GlobalISel test with `-global-isel-abort=1` for the same idiom, plus an `i8`
output in a 32-bit register to cover the truncating path.

Validated on llvm-mos `742d554bf08042b8df93d791c335260fadd16643` with
assertions enabled:

- Both new tests fail on the unpatched `llc` at every RUN line (`unable to
  translate instruction: call`) and pass with the change.
- gcc C-torture `execute`: the 1,390 files the pinned Clang accepts, compiled
  to IR and run through `llc -verify-machineinstrs` at `-O0`, `-O2` and `-Os`
  before and after. 10 compilations newly succeed (`pr65053-1` at `-O0`;
  `pr65053-2`, `pr65956` and `pr88904` at all three levels), none newly fails,
  and all 4,109 compilations that succeed on both sides produce identical
  assembly.
- MOS CodeGen and MC suites: 141 pass, 1 unsupported, 0 fail.
- The complete `test/CodeGen/{X86,ARM,AArch64}` suites, since the change is in
  generic code: 11,460 tests: 11,436 pass, 23 expectedly fail, none fails (the AArch64 GlobalISel directory, 785 tests, rerun after a CHECK spelling fix to the new test: all pass).

Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`, `high`
reasoning effort) for the diagnosis, implementation, tests, validation, and PR
drafting.
