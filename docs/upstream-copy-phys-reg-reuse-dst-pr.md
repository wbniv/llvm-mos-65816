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
to `main` at the time of writing), with the preceding fix and this change
applied and assertions enabled:

- MOS CodeGen: 84 pass, one existing unsupported test, including the new test
  and the updated `copy-phys-reg.mir`. MOS MC: 46 pass.
- The new MIR cases fail their output checks without this change (the fallback
  reload is emitted) and pass with it; the two controls pass either way.
- gcc `c-torture/execute` (1,390 of its 1,656 files compile with the pinned
  Clang) at `-O0`,
  `-O2` and `-Os` with MachineVerifier, comparing the backend with only the
  preceding fix against this change on top: no new failures; 3,655
  compilations are identical and 435 differ. Over the 374 differing pairs that
  assemble, `.text` shrinks by 2,530 bytes (1,364,382 → 1,361,852); six pairs
  grow by one to four bytes because the reused register's longer live range
  changes a later scavenger choice, and no function executes more instructions.
  The typical change is `ldx __rcN; stx __rcM` becoming `sty __rcM`, or a
  `T_A`/`TA` pair becoming a single `TA`.
- The `-O0` reproducer from the preceding fix still verifies at all six levels;
  its assembly is unchanged at `-O0` and three to six lines shorter above it.
- The project's SNES corpus gate (each program's result compared across the host
  oracle, the default 8-bit build, `+mos-a16` and `+mos-xy16`, on MAME and
  bsnes-jg) with this change in the toolchain: 70 of 80 programs pass (host == default == +mos-a16 == +mos-xy16 on MAME and bsnes-jg), 0 fail; run still in progress at commit time, final figure to follow.


Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`, `high`
reasoning effort) for the diagnosis, implementation, tests, validation, and PR
drafting, while reviewing the preceding change.
