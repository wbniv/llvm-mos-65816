# [MOS] Reuse the destination of an earlier copy in getRegWithVal

Post-RA copy expansion looks for an earlier register that already holds the
value being copied, so that an `Imag8`-to-`Imag8` copy can be a single store
from a GPR and a GPR-to-GPR copy through `A` can skip the transfer into `A`.
`MOSInstrInfo::getRegWithVal` has two ways to find one: a copy that *defined*
the wanted value from a register of the right class, and a copy that *stored*
the wanted value into a register of the right class. The second one never
fires. The clobber map is updated for each instruction before that instruction
is inspected, so a copy's own destination is always recorded as clobbered by
the time the copy is checked.

```text
$a = T_A $x
STAbs $a, 1234
$y = COPY $x        ; wants X in A: $a still holds it, but is never reused
```

Today this lowers to a second `T_A $x` into a scavenged accumulator temporary
followed by `TA`. With the destination reuse working, it lowers to `$y = TA $a`.
The `Imag8` case is the common one: after `$y = LDImag8 $rc4`, a later
`$rc6 = COPY $rc4` becomes `$rc6 = STImag8 $y` instead of a scavenged
`LDImag8` plus `STImag8` pair.

Record a copy's own definition only after it has been checked, so the clobber
map reflects the instructions after the copy. The existing rejection cases are
unchanged: a redefined destination is still clobbered, and a redefined source
still stops the search. Reusing a destination also has to clear a `dead` flag
on the establishing copy, in the same way the existing reuse clears stale kill
flags, so `ReuseReg` now does both.

This depends on the stale-kill fix in the preceding change
(`copy-phys-reg-liveness`): the reuse it enables is exactly the situation that
leaves a stale kill behind, so it is submitted on top of that change (as a
second PR based on its branch, or as a second commit in the same PR), not on
its own.

Add a MIR test with the accumulator and imaginary-register reuse shapes, a dead
establishing definition, and two controls (clobbered destination, redefined
source) that must keep the fallback.

Validated against llvm-mos `742d554bf08042b8df93d791c335260fadd16643` (identical
to `main` at the time of writing; both changes also apply cleanly on a tree
carrying newer LLVM merges), comparing the preceding liveness fix alone with
this change on top, with assertions enabled in both backends:

- MOS CodeGen: 85 pass, one existing unsupported test, including the new test
  and the updated `copy-phys-reg.mir`. MOS MC: 46 pass.
- All five MIR cases pass verification with either backend. The three reuse
  cases fail their output checks without this change and pass with it; the two
  clobber controls pass either way. All six preceding liveness cases still pass.
  Additional review probes cover alias clobbers, a call's register mask,
  subregister kills, repeated reuse, and an unrelated dead definition.
- Of 1,656 gcc `c-torture/execute` files attempted, 1,390 compile to IR at each
  of `-O0`, `-O2` and `-Os`. Across 4,170 backend comparisons with
  MachineVerifier, 3,655 successful pairs are identical, 435 differ, and 80
  fail on both sides. No compilation newly fails or newly succeeds.
- Reassembling the 374 differing pairs accepted by the assembler gives a net
  `.text` reduction of 2,530 bytes (1,364,382 → 1,361,852): 352 pairs shrink,
  16 retain their size, and six grow by one to four bytes. The other 61 pairs
  fail to assemble on both sides and are excluded from this size measurement.
  The six increases involve a changed scavenger choice; a later `inx` or `dex`
  becomes an immediate load. Across all 435 changed pairs, the static emitted
  instruction count falls by 1,824, with no file-level increase. This is not
  an execution-time or cycle-count measurement. The same comparison at `-O2`
  for `mos65c02` and `mosw65816` shows no new failures either (1,323 identical,
  41 differing, 26 failing on both sides, for each).
  The typical change is `ldx __rcN; stx __rcM` becoming `sty __rcM`, or a
  `T_A`/`TA` pair becoming a single `TA`.
- The `-O0` reproducer from the preceding fix still verifies at all six levels;
  its assembly is unchanged at `-O0`, with one redundant load removed at `-O1`
  and two removed at `-O2`, `-O3`, `-Os` and `-Oz`.

Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`, `high`
reasoning effort) for the diagnosis, implementation, tests, validation, and PR
drafting, while reviewing the preceding change.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`,
`xhigh` reasoning effort) for independent review, validation, and corrections
to the submission evidence.
