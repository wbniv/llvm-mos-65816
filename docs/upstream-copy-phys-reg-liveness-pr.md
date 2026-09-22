# [MOS] Preserve liveness when reusing physical-register values

Post-RA copy expansion can reuse a physical register after an instruction marked
as its last use, leaving a stale kill flag. On `mos6502`, this causes
MachineVerifier to reject an ordinary C function at `-O0` with `Using an undefined
physical register`.

The reduced sequence is:

```text
$rc4 = COPY $y
$a = LDIndirIdx killed $rs1, killed $y
$rc6 = COPY $rc4
```

`MOSInstrInfo::getRegWithVal` finds that Y still contains the value stored in
`$rc4`, so the final copy becomes `$rc6 = STImag8 $y`. That reuse is valid, but
the indexed load can no longer mark Y's last use.

Clear overlapping kill flags from the copy establishing the reused value up to
the insertion point. Keep the existing clobber checks and value-reuse
optimization. The pointer's kill flag remains intact.

The MIR regression covers reuse of Y and A, an overlapping subregister kill, a
kill on the establishing copy itself, a value reused twice, and a
clobbered-value control that must retain its kill and reload the saved value.

Validated against llvm-mos `742d554bf08042b8df93d791c335260fadd16643` (identical
to `main` at the time of writing), with only this patch applied and assertions
enabled:

- MOS CodeGen: 84 pass, one existing unsupported test, including the new test.
  MOS MC: 46 pass.
- Four reduced cases trigger the undefined-register verifier diagnostic without
  the fix (the repeated-reuse case twice). Five cases fail their output checks;
  the clobber control passes. All six pass verification and output checks with
  the fix.
- The original C reproducer, compiled with unmodified Clang to IR and the patched
  backend to objects, passes MachineVerifier at `-O0`, `-O1`, `-O2`, `-O3`, `-Os`,
  and `-Oz`. The unpatched backend fails at `-O0`.
- Assembly for that reproducer is byte-for-byte identical with and without the
  fix at all six optimization levels.
- Of 1,656 gcc `c-torture/execute` files attempted, 1,390 compile to IR at each
  of `-O0`, `-O2` and `-Os`. Across those 4,170 backend comparisons with
  MachineVerifier, 20 compilations rejected by the baseline with `Using an
  undefined physical register` pass with the fix (18 at `-O0`, one file at
  `-O2` and `-Os`). All 4,070 pairs that succeed on both sides produce identical
  assembly; 76 pairs fail on both sides. Four other compilations fail only on
  the assertion-enabled candidate in this comparison with an assertions-off
  baseline. All four reproduce `Remaining virtual register` on a pristine
  assertion-enabled build. The differing `strlen-4.c` failure among the 76
  pairs also reproduces its assertion on that pristine build.

No runtime miscompilation is claimed; the change only repairs liveness flags.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`,
`xhigh` reasoning effort) for diagnosis, implementation, tests, validation,
and PR drafting.
Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`, `high`
reasoning effort) for the independent review, the repeated-reuse test case, and
the corpus differential.
