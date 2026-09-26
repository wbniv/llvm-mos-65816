# [MOS] Honour an explicit width modifier on a constant operand

`mos16(240)` selects `LDA zero page,X` (`B5 F0`), and `mos24($123456)` selects
`LDA zero page` (`A5 56`) with the address truncated to its low byte. Both
should select the encoding the modifier names:

```
$ llvm-mc -triple mos -mcpu=mosw65816 -show-encoding
        lda     mos16(240),x            ; encoding: [0xb5,0xf0]        expected [0xbd,0xf0,0x00]
        lda     mos16(4660),x           ; encoding: [0xb5,0x34]        expected [0xbd,0x34,0x12]
        lda     4660,x                  ; encoding: [0xbd,0x34,0x12]   (no modifier, correct)
        lda     mos24(1193046)          ; encoding: [0xa5,0x56]        expected [0xaf,0x56,0x34,0x12]
```

This is a wrong-code path, not a cosmetic one. `zero page,X` computes
`(base + X) & 0xFF` and wraps inside page zero; `absolute,X` carries into the
high byte, so the two differ for `X >= 0x10` at `base = $F0`.
`MOSMCInstLower::wrapAbsoluteIdxBase` exists to prevent exactly that, and says
so:

> Instructions with indexed addressing must have zero page-matching bases
> wrapped in `mos16`. Otherwise, if the assembly were later parsed, the zero
> page indexed addressing mode might be selected, which has different semantics
> when Base + Idx >= 256;

It emits `mos16(240)`, which the assembler then ignores, so the protection is a
no-op and the same source compiles differently depending on whether it passes
through `.s`:

```c
char f(char i) { return ((volatile char *)0xF0)[i]; }
```
```
clang --target=mos -Os -S       ->  lda mos16(240),x
clang --target=mos -Os -c       ->  1: bd f0 00   lda $f0,x      absolute,X
clang --target=mos -Os -S, then assembling the .s
                                ->  1: b5 f0      lda $f0,x      zero page,X
```

## Cause

`MOSOperand::isImmInRange<Low, High>` is the operand-class predicate the
AsmMatcher uses to ask whether a parsed operand can fill a candidate operand of
width `[Low, High]`. Its `MOSMCExpr` branch has two exits. The symbolic exit
compares the modifier's own fixup width against the candidate's width
(`MaxValue <= High`) and is correct. The constant exit never looks at `High` at
all:

```cpp
int64_t MaxValue = (1LL << Info.TargetSize) - 1;

int64_t Value;
if (ME->evaluateAsConstant(Value) && Value > 0)
  return Value <= MaxValue;      // High is not consulted

return MaxValue <= High;
```

`MOSMCExpr::evaluateAsConstant` has already masked the value to the modifier's
own width, so `Value <= MaxValue` is true for every positive constant and the
constant exit is effectively `return true`. A 16- or 24-bit modifier therefore
fills an 8-bit operand slot, and the code emitter truncates the value with no
fixup, no relaxation and no diagnostic.

The existing `FixupKind == MOS::Imm16 && High < 0xFFFF` special case above it
does not help: it covers only the immediate-context spelling `#mos16(…)`
(`VK_IMM16`). In an address context `mos16(…)` parses to `VK_ADDR16`, a
different fixup kind.

## Fix

Hoist the width relation so it guards both exits. The `Imm16` special case is
the `MaxValue == 0xFFFF` instance of the general rule (`MaxValue > High` is
exactly `High < 0xFFFF` there), so it is folded in rather than kept beside it.

```cpp
const MCFixupKindInfo &Info =
    MOSFixupKinds::getFixupKindInfo(ME->getFixupKind(), nullptr);
const int64_t MaxValue = (1LL << Info.TargetSize) - 1;

if (MaxValue > High)
  return false;

int64_t Value;
if (ME->evaluateAsConstant(Value) && Value > 0)
  return Value >= Low && Value <= MaxValue;

return true;
```

The change is strictly a narrowing: the only inputs whose result moves are
constants whose modifier is wider than the candidate operand, and they move from
`true` to `false`. Nothing that was refused becomes accepted, so a
misclassification can only ever produce a `no matching instruction` diagnostic,
never a silently narrower encoding. It is also not a new rule — it is the rule
the symbolic exit has always applied. `test/MC/MOS/modifiers.s` already pins it
there: `lda mos24segment(addr8)` assembles to `ad 00 00`, not `a5 00`, because a
16-bit modifier is refused for an 8-bit candidate. Constants now behave the same
way.

Where a wider candidate exists, the operand moves to it; where none does, the
instruction is rejected with the matcher's near-miss notes, which name the
widths that would fit:

```
$ llvm-mc -triple mos -mcpu=mos6502
lda mos24($123456)
<stdin>:1:1: error: invalid instruction, any one of the following would fix this:
<stdin>:1:5: note: operand must be an 8-bit address
<stdin>:1:5: note: operand must be a 16-bit address
```

## Tests

Three new files in `test/MC/MOS/`. All three fail before the change and pass
after it.

- `modifier-width.s` — 6502: `mos16()`/`mos24segment()` on constants select
  absolute (including `mos16(0)`, `mos16(-1)` and the `mos16(240),x` shape
  `wrapAbsoluteIdxBase` emits); `mos8()`, `mos16lo()`, `mos16hi()` and
  `mos24bank()` still select zero page; unmodified constants are unchanged.
- `modifier-width-65816.s` — with three widths in play: `mos24()` reaches
  absolute long, `mos16()` stops at absolute, `mos8()` still reaches the direct
  page and long-indirect forms.
- `modifier-width-errors.s` — the refusal path: a 24-bit modifier on a CPU
  without long addressing, and a wide modifier on a direct-page indirect base.

## Validation

Measured rather than predicted: a sweep of **12,045** probes — 8 CPUs
(`mos6502`, `mos65c02`, `mosw65816`, `mosspc700`, `moshuc6280`, `mos45gs02`,
`mos65ce02`, `mos65el02`) × 10 instruction shapes (3 for SPC700) × 11 modifiers
× 15 operands (13 constants straddling every width boundary, plus a defined and
an undefined symbol) — assembled with `-show-encoding` before and after the
change and diffed.

| | probes |
|---|---:|
| total | 12,045 |
| unchanged | 9,068 |
| widened to a larger encoding | 1,458 |
| accepted before, now refused | 1,519 |
| **narrowed to a smaller encoding** | **0** |
| **refused before, now accepted** | **0** |
| rows with no modifier that changed | 0 |
| rows with an unresolvable symbol that changed | 0 |

Every changed row carries `mos16`, `mos24`, `mos24segment` or `mos13` — the four
modifiers that can be wider than a candidate operand. The 1,519 refusals are a
24-bit modifier on a CPU with no long addressing, a wide modifier on a
direct-page indirect base, and a wide modifier on an 8-bit immediate; each of
those previously assembled with the address truncated to fit.

`#mos13()` and `#mos24segment()` now select the 65816 16-bit immediate, which is
the treatment `#mos16()` already received through the `Imm16` special case.

MOS lit suites: 157 tests, 151 pass, 2 unsupported, 4 fail — the same four that
fail without the change, with byte-identical output.

Assisted-by: Claude Code 2.1.278 using Claude Opus 5 (`claude-opus-5`), `high`
reasoning effort, as a subagent, for the fix, this draft, and its validation
record; commit `48595d47` credits the same work as "Claude Opus 5 (1M context)".
Verified from Claude Code session `65695418-7e9b-45bd-92e3-2ecfd88ecf0b` metadata.
