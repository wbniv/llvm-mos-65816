# [llvm-mc] Preserve target Motorola-integer defaults

<!-- POSTED: https://github.com/llvm-mos/llvm-mos/pull/587
     Branch: wbniv:llvm-mc-preserve-motorola-default
     Commit: 579bc0f087c1
     Fork carry: patches/llvm-mos/0025-llvm-mc-preserve-motorola-default.patch
-->

## Summary

Do not override an assembly target's Motorola-integer lexer setting unless the user explicitly
passes `-motorola-integers` or `-motorola-integers=false` to `llvm-mc`.

`AsmLexer` initializes this setting from `MCAsmInfo::shouldUseMotorolaIntegers()`. The MOS target
sets that default to true, but `llvm-mc` currently replaces it unconditionally with the default
value of its command-line option, which is false. As a result, the standalone tool does not honor
the target default:

```console
$ llvm-mc -triple mos -show-encoding
        lda #$ea
        lda #$ea ; encoding: [0xa9,A]
                  ; fixup A, value: $ea, kind: Imm8
```

Here `$ea` is treated as a symbol rather than the hexadecimal value `$EA`. The normal compiler
driver is unaffected because this override belongs specifically to the `llvm-mc` frontend.

## Regression history

The two halves arrived at different times:

- On **2021-01-26**, upstream LLVM commit
  [`4db18d62afa8`](https://github.com/llvm/llvm-project/commit/4db18d62afa8b17efec1c992fc10e9eafc1cefaf)
  ([Differential D98519](https://reviews.llvm.org/D98519)) added Motorola literal syntax for M68k.
  That change also added the `llvm-mc` command-line option and the unconditional
  `setLexMotorolaIntegers(LexMotorolaIntegers)` call. MOS did not yet request this target default,
  so the latent override caused no MOS regression then.
- On **2023-09-21**, llvm-mos
  [PR #352, “MOS: Use upstream Motorola-style integer support in
  AsmLexer”](https://github.com/llvm-mos/llvm-mos/pull/352) merged as
  [`fe2a50e1656b`](https://github.com/llvm-mos/llvm-mos/commit/fe2a50e1656b1e31862a3ad1a61d71a79690539b).
  It set `UseMotorolaIntegers = true` so MOS users could write dollar-prefixed hexadecimal and
  percent-prefixed binary literals through the upstream lexer.

That 2023 merge exposed the conflict: `AsmLexer` honored the new target default, then standalone
`llvm-mc` immediately reset it to the option's implicit false value. Thus bare `llvm-mc -triple
mos` has mishandled `$`/`%` literals for approximately **two years and ten months** (2023-09-21
through this fix on 2026-08-04). The compiler driver's integrated assembler continued to work,
which explains why normal application builds did not reveal it; explicit `-motorola-integers` in
most MOS MC tests masked it there as well.

## Fix

Guard the override with `LexMotorolaIntegers.getNumOccurrences()`. With no command-line setting,
the lexer retains the target's `MCAsmInfo` default. An explicitly supplied true or false value still
wins, preserving the option's intended override behavior.

```cpp
if (LexMotorolaIntegers.getNumOccurrences())
  Parser->getLexer().setLexMotorolaIntegers(LexMotorolaIntegers);
```

This is intentionally separate from [MOS BRK signature operand PR
#586](https://github.com/llvm-mos/llvm-mos/pull/586). That PR uses decimal `brk #66` in its bare
`llvm-mc` regression and has no dependency on this change.

## Tests

Add `llvm/test/MC/MOS/motorola-integers-default.s` with two invocations:

- Bare `llvm-mc -triple mos` honors the MOS target default and encodes `lda #$ea` as
  `[0xa9,0xea]`.
- Explicit `-motorola-integers=false` still overrides the target default, treating `$ea` as a
  symbol and producing the existing `[0xa9,A]` fixup form.

The focused test passes on the rebuilt local `llvm-mc`. The change is one guarded assignment plus
one five-line regression fixture.

## Context

MOS enabled Motorola integer syntax in its target assembly information, but most existing MOS MC
tests still pass `-motorola-integers` explicitly. This fix makes direct `llvm-mc` behavior agree
with the target configuration and removes the need for that workaround in new tests.
