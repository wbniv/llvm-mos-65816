# [MOS] Add the missing `AddrAsciz` row to `MOSFixupKinds.cpp`'s `Infos[]`

`MOSFixupKinds.h`'s `Fixups` enum declares 15 target fixup kinds (`Imm8` …
`PCRel16`, then `AddrAsciz`). `MOSFixupKinds.cpp`'s `Infos[MOS::NumTargetFixupKinds]`
array — documented immediately above as "must be in the same order as ...
`MOSFixupKinds.h`" — has only 14 brace-initialisers; the `AddrAsciz` row is
missing entirely. `getFixupKindInfo` indexes this array directly by
`Kind - FirstTargetFixupKind`, so a lookup for `MOS::AddrAsciz` reads past the
written initialisers into the array's value-initialised tail:
`MCFixupKindInfo{nullptr, 0, 0, 0}`.

## Why this is latent, not a live miscompile

`AddrAsciz` fixups are created only by `.mos_addr_asciz` (`MOSMCExpr.cpp`
sets `Kind = MOS::AddrAsciz`), and read back through exactly two paths:

- `MOSAsmBackend::fixupNeedsRelaxationAdvanced`: for an `MOSMCExpr`, the relax
  decision is `Info.TargetSize > (BankRelax ? 16 : 8)`. With the missing row
  read as `TargetSize == 0`, this is always `false` — "never relax" — which
  is also the *correct* answer here: `.mos_addr_asciz sym, N` is a
  variable-width decimal-ASCII data directive whose width `N` is supplied
  per call site (`MOSMCELFStreamer::emitMosAddrAsciz`), not a fixed-width
  instruction operand, so relaxation does not apply to it at all.
- `MOSAsmBackend::applyFixup`'s `case MOS::AddrAsciz:` branch writes the
  ASCII bytes directly and never touches `Info`.

So today nothing reads the zero-valued `Info.Name`/`TargetOffset`/`Flags`
this bug produces, and `MC/MOS/addr-asciz.s` (the one existing test for this
directive) already passes on both sides of this change. The defect is real —
the array's own documented invariant is silently violated, `Info.Name` is
`nullptr` for any future diagnostic/debug path that prints it, and the
*next* fixup kind appended after `AddrAsciz` would silently inherit the same
off-by-one — but it has no observable effect through any path that exists
today.

## The fix

Add the missing row, matching the existing rows' `{"Name", offset, bits,
flags}` convention (name = the bare enum-case string, as every other row
already does):

```cpp
{"AddrAsciz", 0, 0,
 0}, // Address encoded as a variable-width decimal ASCII string; the
     // width is supplied per-call-site (emitMosAddrAsciz), so this
     // fixup has no fixed TargetSize and must never be relaxed (see
     // fixupNeedsRelaxationAdvanced's Info.TargetSize > N check).
```

`TargetOffset = 0`, `TargetSize = 0`, `Flags = 0` are chosen deliberately —
matching today's accidental values, but now documented and intentional:
`TargetSize == 0` is exactly what keeps `fixupNeedsRelaxationAdvanced` from
ever relaxing this fixup, which is correct since the directive's width is
caller-supplied, not something the assembler can widen.

## Regression protection

Infer the array bound from the initializer and add
`static_assert(std::size(Infos) == MOS::NumTargetFixupKinds)`. With an explicitly
sized array, a missing final initializer is silently zero-filled; the inferred
bound makes an omitted row a compile-time error. This checks the row count;
review must still check the enum ordering.

The existing directive tests retain the same behavior. The initial
[pinned-base validation](pr-preparations/2026-09-25/0046-validation.md) is
supplemented by the [September 25 review](pr-preparations/2026-09-25/claude-batch-review.md),
which rebuilds the revised source and checks standalone applicability.

## Breaking commit

Introduced by
[`6cbcc49`](https://github.com/llvm-mos/llvm-mos/commit/6cbcc49db9b2903bf78d78d207da150d53e8cf39)
("`.mos_addr_asciz` target directive with `R_MOS_ADDR_ASCIZ`", 2022-01-17),
which added `AddrAsciz` to the `Fixups` enum in `MOSFixupKinds.h`:

```diff
   Addr13,              // A 13-bit SPC700 address.
   PCRel8,              // An 8-bit PC relative value.
+  AddrAsciz,           // Address encoded as a decimal ASCII string.
   LastTargetFixupKind,
   NumTargetFixupKinds = LastTargetFixupKind - FirstTargetFixupKind
```

but touched only `MOSFixupKinds.h`, not `MOSFixupKinds.cpp` — the commit's
file list has no `MOSFixupKinds.cpp` in it — so the `Infos[]` array was never
updated to match the new enum member it introduced.

Assisted-by: Claude Code CLI using Claude Sonnet 5 (`claude-sonnet-5`, `high`
reasoning effort) for investigation, patch validation against the pinned
upstream base, and PR drafting.

Assisted-by: OpenAI Codex for independent review, the compile-time table-length
check, and documentation updates. Claude’s original implementation and validation
credit above is retained.
