# Inline-asm physreg constraints must refuse operands wider than their register

**TODO item:** `MOSTargetLowering::getNumRegistersForInlineAsm` disagrees with
`getRegForInlineAsmConstraint` for non-`"r"` classes.
**File:** `vendor/llvm-mos/llvm/lib/Target/MOS/MOSISelLowering.cpp`
**Patch artifact:** new standalone `patches/llvm-mos/0043-mos-inline-asm-physreg-width.patch`
(stock-llvm-mos defect → standalone, not folded into `0002`; upstream-postable).

**No mockup section:** this change has no visible surface — it is a backend constraint
check whose only output is a compile-time error.

---

## 1. The defect

Two `MOSTargetLowering` hooks describe the same inline-asm operand and disagree.

- `getNumRegistersForInlineAsm(Context, VT)` (line 128) sees **only a VT**. The generic
  `TargetLowering` interface passes no constraint string, so the override special-cases
  `MVT::i16 → 1` unconditionally, meaning "an `i16` inline-asm operand occupies one
  register".
- `getRegForInlineAsmConstraint(TRI, Constraint, VT)` (line 157) sees the constraint.
  For `"r"` it honours the promise — `i16` → the 16-bit `Imag16` class, one register.
  For `"a"`/`"x"`/`"y"` it returns a **single 8-bit `GPR` physreg regardless of VT**, and
  for `"R"`/`"d"` an 8-bit class regardless of VT.

`InlineAsmLowering::getRegistersForValue`
(`llvm/lib/CodeGen/GlobalISel/InlineAsmLowering.cpp:105-143`) takes the class from the
second hook and the count from the first, so for `"=a"` on an `i16` it allocates exactly
one 8-bit `$a` and the size adjustment at the bottom of `lowerInlineAsm` narrows the
`i16` result to it. Observed on the current toolchain
(`build/llvm-mos/bin/llc -mtriple=mos -mcpu=mosw65816`):

```llvm
define i16 @f() {
  %v = call i16 asm "lda #42", "=a"()
  ret i16 %v
}
```
```
f:
	;APP
	lda	#42
	;NO_APP
	ldx	#0        ; high byte invented as zero — the asm never wrote it
	rts
```

The high byte is silently fabricated. This is a **stock llvm-mos defect**: it is
independent of `+mos-a16` and reproduces on `mos6502`. Patch `0041` made the analogous
narrowing *explicit* on the generic side; it did not introduce this, and it does not
catch it (the operand genuinely fits the one register the target asked for).

The opposite direction already fails loudly: `"a"(i16)` as an **input** bails in
`buildAnyextOrCopy` (no implicit truncation of a source), producing
`LLVM ERROR: unable to translate instruction: call`. So the two directions of the same
constraint disagree with each other too.

## 2. The contract: reject

Chosen: **(a) reject — a fixed-width register constraint does not accept an operand
wider than the register.** Three independent reasons, each verified rather than assumed:

1. **There is no well-defined widening.** `"a"` selects exactly `MOS::A`. `GPRRegClass`
   is `{A, X, Y}` — three unrelated 8-bit registers with no pairing and no defined
   ordering as a value. Widening `"=a"` to two registers would mean "A then X", which is
   a calling-convention invention, not something the constraint spells. `"c"`/`"v"` are
   single bits of `$p`. Only `"r"` has a class (`Imag16`) that genuinely holds 16 bits.

2. **Clang already enforces exactly this contract at the front end.**
   `MOSTargetInfo::validateOperandSize` (`clang/lib/Basic/Targets/MOS.cpp:98-113`)
   returns `Size <= 8` for `a`, `x`, `y`, `R`, `d`, `c`, `v`, so
   `asm("" : "=a"(int_value))` is already diagnosed as
   `error: invalid output size for constraint '=a'`. The backend hole is only reachable
   from IR — `llc`, a hand-written `.ll`, or another front end. Rejecting in the backend
   makes the two layers state the same rule instead of one of them silently
   miscompiling; it changes no C-level behaviour.

3. **AVR — the closest precedent, another 8-bit target with physreg constraints —
   does this already.** `AVRTargetLowering::getRegForInlineAsmConstraint`
   (`llvm/lib/Target/AVR/AVRISelLowering.cpp:2595-2665`) guards *every* case on the VT
   the class can hold: `'t'` (r0, 8-bit only) matches `if (VT == MVT::i8)` and otherwise
   **falls through to the generic implementation**, which returns `{0, nullptr}`. The
   wide cases are served by a separate wider class (`'a'` → `LD8lo` for `i8`,
   `DREGSLD8lo` for `i16`) — which MOS has no equivalent of for `A`/`X`/`Y`.

Rejection is expressed as a `{0, nullptr}` return, the documented failure value of the
hook and the same path AVR takes. It reaches the user as a hard compile error rather
than wrong code.

### Scope boundary — what this does *not* claim

The GlobalISel path turns a `nullptr` class into `return false` from `lowerInlineAsm`
(`InlineAsmLowering.cpp:461`, `:662`), which IRTranslator reports as
`LLVM ERROR: unable to translate instruction: call ... PLEASE submit a bug report`.
That is loud and correct but not a *good* diagnostic; SelectionDAG's equivalent path
calls `emitInlineAsmError("couldn't allocate output register for constraint ...")`.
Improving the generic GlobalISel bail into a real inline-asm diagnostic is **the sibling
TODO item's job** (`[T2] Physreg-constrained inline-asm operand wider than its register
class asserts "Ran out of registers to allocate!"`), which already owns the generic-side
diagnostic wording and is a generic-LLVM change. The two compose: this item makes the
MOS hooks agree; that item makes the generic bail readable. Nothing here fixes or
disturbs the `"=a"(i32)` register-exhaustion crash — after this change that shape stops
at the new width check instead, which is a side effect worth recording but is not the
sibling item's fix (the assert is reachable from other targets and other constraints).

`"c"`/`"v"` are deliberately **left alone**. `FlagRegClass` registers are 1 bit, and
`asm("" : "=c"(uint8_t))` — zero-extending the carry into a byte — is established,
tested behaviour (`llvm/test/CodeGen/MOS/inlineasm-constraint.mir:210`) that clang
permits up to 8 bits. Applying a strict width rule there would break working code to
serve consistency. The rule this patch enforces is the one clang already states:
the 8-bit data constraints take at most 8 bits.

## 3. Implementation

In `MOSISelLowering.cpp`:

- Add a file-local helper `isWiderThan(MVT VT, unsigned Bits)` that is false for
  `MVT::Other`/`iPTR`/invalid and otherwise compares `VT.getSizeInBits()`.
- In `getRegForInlineAsmConstraint`, guard `'R'`, `'a'`, `'x'`, `'y'`, `'d'` with
  `if (isWiderThan(VT, 8)) break;` so they fall through to
  `TargetLowering::getRegForInlineAsmConstraint`, which returns `{0, nullptr}`.
- Leave `'r'` (multi-register via `Imag8`, or `Imag16` for `i16`), `'c'`, `'v'` and
  `"{cc}"` unchanged.
- Extend the comment on `getNumRegistersForInlineAsm` to state the invariant the two
  hooks now jointly maintain, so the next reader does not re-derive the asymmetry.

## 4. Test

New `llvm/test/CodeGen/MOS/inline-asm-physreg-width.ll`, carried by `0043` and listed in
`dev/regen-patch.sh`'s `TESTRELS` so a `0002` regeneration neither drops nor absorbs it:
`not llc ... 2>&1 | FileCheck` over `"=a"`, `"=x"`, `"=y"`, `"=R"`, `"=d"` with `i16`,
plus positive cases that must keep working (`"=a"(i8)`, `"=r"(i16)` → `Imag16`,
`"=c"(i8)`). Run on `mos6502` — the defect is not `+mos-a16`-specific.

## 5. Verification steps

1. Build the toolchain with the new patch in the stack: `dev/run.sh toolchain`, and
   confirm `build/llvm-mos-install/bin/clang-23`'s mtime advanced.
2. The pre-fix repro no longer miscompiles:
   `build/llvm-mos/bin/llc -mtriple=mos -mcpu=mosw65816 repro.ll -o -` fails instead of
   emitting `ldx #0`.
3. `dev/run.sh lit` — the MOS suites, against the known 4-failing baseline
   (`legalizer.mir`, `scavenger-p-undef-6502.ll`, `shift-rotate.ll`,
   `addressing-modes-65816.s`). No 5th failure, no silently-fixed 4th.
4. `dev/run.sh corpus` — expect `7/7`.
5. `dev/run.sh corpus-a16` — the differential gate
   (host == default@MAME == `+mos-a16`@MAME == `+mos-a16`@bsnes-jg).
6. `dev/regen-patch.sh` round-trips `0002` and the regenerated `0002` contains no
   hunk from `0043`: `grep -c isWiderThan patches/llvm-mos/0002-321-accum16.patch` → 0.

---

## 6. Verification record (2026-09-24)

### Step 1 — `dev/run.sh toolchain`, clang-23 mtime advanced

```
[3/12] Building CXX object lib/Target/MOS/CMakeFiles/LLVMMOSCodeGen.dir/MOSISelLowering.cpp.o
==> done in 0m 34s: clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)

$ ls -la build/llvm-mos-install/bin/clang-23 build/llvm-mos/bin/llc
-rwxr-xr-x 1 will will 124831424 Sep 24 10:44 build/llvm-mos-install/bin/clang-23
-rwxr-xr-x 1 will will  56312768 Sep 24 10:45 build/llvm-mos/bin/llc
```

(Before the rebuild `llc` was `Sep 24 09:13`.) **PASS**

### Step 2 — the pre-fix repro no longer miscompiles

Before, the 16-bit result was narrowed into `$a` and the high byte invented:

```
$ llc -mtriple=mos -mcpu=mosw65816 one.ll -o -      # one.ll: %v = call i16 asm "lda #42", "=a"()
f:
	;APP
	lda	#42
	;NO_APP
	ldx	#0
	rts
```

After:

```
$ llc -mtriple=mos -mcpu=mosw65816 one.ll -o -
LLVM ERROR: unable to translate instruction: call (in function: f)
```

The C surface is unchanged — 8-bit `"=a"` still compiles, a pointer in `"=r"` still
gets `Imag16`, and a 16-bit `"=a"` is still caught by clang, not the backend:

```
$ mos-clang --target=mos -mcpu=mosw65816 -Os -S c1.c -o -
ok:
	;APP
	lda	#42
	;NO_APP
ptr:
	;APP
	;NO_APP
	lda	(__rc2)

$ mos-clang --target=mos -mcpu=mosw65816 -Os -c c2.c -o /dev/null
c2.c:1:35: error: invalid output size for constraint '=a'
    1 | int f(void){int v;__asm__("":"=a"(v));return v;}
      |                                   ^
```

**PASS**

### Step 3 — `dev/run.sh lit`

```
FAIL: LLVM :: CodeGen/MOS/scavenger-p-undef-6502.ll (1 of 154)
FAIL: LLVM :: MC/MOS/addressing-modes-65816.s (2 of 154)
FAIL: LLVM :: CodeGen/MOS/legalizer.mir (4 of 154)
FAIL: LLVM :: CodeGen/MOS/shift-rotate.ll (5 of 154)
Testing Time: 1.34s

Total Discovered Tests: 154
  Unsupported:   2 (1.30%)
  Passed     : 148 (96.10%)
  Failed     :   4 (2.60%)
```

154 discovered (was 153) and 148 passed (was 147) — the one new test is the one added
here. The four failures are exactly the recorded baseline; none fixed, none added.
The new test on its own:

```
$ dev/run.sh lit /work/build/llvm-mos/test/CodeGen/MOS/inline-asm-physreg-width.ll
Total Discovered Tests: 1
  Passed: 1 (100.00%)
```

**PASS**

### Step 4 — `dev/run.sh corpus`

```
==> corpus: 80/80 passed
```

(The 7/7 in `docs/agent-handoff.md` predates the corpus growing to 80 demos.) **PASS**

### Step 5 — `dev/run.sh corpus-a16`

First run, 78/79 with `pi_sim FAIL` and an empty detail column — the runner prints the
first line matching `RESULT: FAIL|mismatch|CRASH`, and there was none, so the check
exited nonzero without reporting a differential disagreement. Re-run in isolation on the
same toolchain and the same ROM:

```
$ dev/container.sh -- python3 /work/tools/a16_fuzz.py check \
    --src /work/examples/snes/corpus/pi_sim.c --name corpus-pi_sim --expected 0x7711
==> corpus-pi_sim: differential default vs +mos-a16  (expected 0x7711; bsnes=yes)
  [PASS] corpus-pi_sim  0x7711 (all agree)
RESULT: PASS — corpus-pi_sim: default == +mos-a16 == host on both emulators
```

The box was not quiet during the first run (a concurrent docker build and poll loop),
which is the documented MAME settle-window failure mode; the exact interleaving was not
captured, so that is a consistent explanation rather than a proven one. Full re-run on a
quiet box:

```
$ rm -rf build/fuzz-work build/fuzz-triage && dev/run.sh corpus-a16
==> corpus-a16: 79/79 passed, 0 xfail
RC=0
```

**PASS** (host == default@MAME == `+mos-a16`@MAME == `+mos-xy16`@MAME ==
`+mos-a16`@bsnes-jg for all 79 slices).

### Step 6 — `0002` carries none of `0043`

`dev/regen-patch.sh` was **not** run. It regenerates `0002` from the live shared
`vendor/`, which currently holds other workers' in-progress edits (and `0002` is already
modified in the working tree by another worker), so a live regen would both clobber their
artifact and absorb their hunks. The same check was made statically instead:

```
$ grep -c "isWiderThan\|inline-asm-physreg-width" patches/llvm-mos/0002-321-accum16.patch
0
```

and the operation `regen-patch.sh` performs on a `STANDALONE_MOSDIR` entry —
`git apply --reverse` of the patch over a tree that has it applied — was exercised
directly, together with a forward round trip:

```
$ git apply 0043-mos-inline-asm-physreg-width.patch && diff -r rt post
ROUND-TRIP: identical
$ git apply --reverse --check 0043-mos-inline-asm-physreg-width.patch
REVERSE: applies cleanly
```

**PASS (static)**; a live `dev/regen-patch.sh` round trip remains unverified and is
called out in the commit message.

---

## 7. Side effect worth recording

After this change, `asm("" : "=a"(long))` on MOS — the reproducer named by the sibling
TODO item `[T2] Physreg-constrained inline-asm operand wider than its register class
asserts "Ran out of registers to allocate!"` — stops at the new width check and never
reaches the generic physreg walk:

```
$ llc -mtriple=mos -mcpu=mos6502 h.ll -o /dev/null   # %v = call i32 asm "", "=a"()
LLVM ERROR: unable to translate instruction: call (in function: h)
```

Previously it segfaulted (release) / asserted (assertions build). The generic defect is
untouched and still reachable from other targets and other constraints; only the MOS
reproducer quoted in that item is now shadowed, so whoever takes it needs a different
one. That item is otherwise out of scope here and was not modified beyond a pointer note.

## 8. Not done

- No upstream PR draft written for `0043`, so nothing was added to
  `docs/upstream-contribution-status.md`. The patch is upstream-shaped (MOS-dir plus one
  MOS lit test, no `+mos-a16` dependency, AVR precedent cited) but posting it needs a PR
  body and a validation record against the pinned base.
- `dev/run.sh torture` and the Csmith fuzzer were not run; neither exercises inline asm
  with a physreg constraint on a wide operand, and the lit suite plus both corpus gates
  cover the shapes this change can reach.
