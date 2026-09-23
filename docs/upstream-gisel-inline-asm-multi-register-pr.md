# [GlobalISel] Support inline asm register operands that need several registers

`InlineAsmLowering` assumes every register operand of an inline asm occupies
exactly one register. A value that needs more than one — anything wider than an
`int` on a target whose `"r"` class is narrow, or `i128` on AArch64, where `"r"`
selects `GPR32common` for every non-64-bit type — hits one of three dead ends:

```text
; asm("" : "=r"(l) : "0"(l))   with a tied multi-register operand
Assertion `NumOpRegs == 1 && "Wrong flag: multi-register tied operands "
"not supported in GlobalISel inline asm"' failed.

; asm("" : "=r"(l))   and   asm("" :: "r"(l))
error: unable to translate instruction: call
```

The assertion reproduces on AArch64 at plain `-O0`, where GlobalISel is the
default:

```llvm
define i128 @tied128(i128 %x) {
  %r = call i128 asm "", "=r,0"(i128 %x)
  ret i128 %r
}
```

and unconditionally on MOS, whose only instruction selector is GlobalISel and
whose `"r"` maps to an 8-bit class for everything but `i16`, so a `long` needs
four registers. Two gcc C-torture files (`20030222-1.c`, `pr52286.c`, six
compilations) abort the compiler there. Relaxing only the assertion does not
help: the same statement's *output* is equally multi-register and would then be
rejected by the bail-out a few lines further on.

SelectionDAG has always handled this, in `RegsForValue`. For the example above
it emits

```text
INLINEASM &"", attdialect,
  regdef:GPR32common, def %4, def %5,
  reguse tiedto:$0, %6(tied-def 3), %7(tied-def 4)
```

— one flag word carrying the register count and the matching operand, followed
by that many use registers, each tied to the def it matches. `MachineInstr`
already supports this: `findTiedOperandIdx` resolves inline-asm ties by walking
the operand-group descriptors and applying the index delta, so nothing below the
lowering needs to change.

This change teaches `InlineAsmLowering` the same lowering:

- an output spanning *N* registers is reassembled with `G_MERGE_VALUES`, least
  significant piece first, and then runs through the existing truncate /
  extend / copy adjustment to the result type;
- an input spanning *N* registers — plain or tied — is narrowed or `G_ANYEXT`ed
  to the registers' combined width and split with a shift and a truncate per
  piece, which is what `getCopyToParts` does for the same value;
- a tied input emits one `RegUse` flag with the def's register count and the
  matching operand index, then ties each use to its def.

Splitting via a shift rather than `G_UNMERGE_VALUES` is deliberate: several
targets declare a scalar-to-scalar unmerge legal without being able to select it
(see the `// TODO: Handle other unmerges into GPRs and from scalars to scalars`
in `AArch64InstructionSelector::selectUnmergeValues`), and the shifts cost
nothing once legalized — MOS assembly is byte-identical either way.

Shapes that are still not handled now take the existing soft bail-out instead of
asserting, so an unsupported inline asm is a diagnostic and never a compiler
crash: a big-endian data layout (the piece order above is only verified for
little endian, and `getCopyToParts`/`getCopyFromParts` swap the halves there), a
non-scalar value, an operand whose registers have differing widths, and a value
that does not live in a single virtual register.

Tests: a MOS test covering the tied, plain-input and output forms for `i32`
plus the `20030222-1.c` shape — an `i64` tied group whose result is read back as
the low `int`, which is the case a reversed piece order would silently break —
checked at the IR-translator boundary and through full codegen with the verifier
at `-O0` and `-O2`; an AArch64 GlobalISel test with `-global-isel-abort=1` for
the same three forms on `i128`.

Validated on llvm-mos `742d554bf08042b8df93d791c335260fadd16643` plus the
indirect-output change, with assertions enabled:

- Both new tests fail on the unpatched `llc` at every RUN line and pass with the
  change.
- gcc C-torture `execute`, all 1,656 files, IR through `llc -O2` before and
  after: 2 newly succeed (`20030222-1`, `pr52286` — the two that asserted), none
  newly fails, and all 1,385 compilations that succeed on both sides produce
  byte-identical assembly. The 3 that fail on both sides are unrelated
  (`<4 x float>` legalization; a frame larger than 32 KiB).
- MOS CodeGen and MC suites: 144 pass, 1 unsupported, 0 fail.
- The complete `test/CodeGen/{X86,ARM,AArch64}` suites, since the change is in
  generic code: see the validation record.

Assisted-by: Claude Code CLI using Claude Opus 5 (1M context) (`claude-opus-5[1m]`,
`high` reasoning effort) for the diagnosis, implementation, tests, validation, and
PR drafting.
