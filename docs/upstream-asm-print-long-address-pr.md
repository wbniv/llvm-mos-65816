> **Superseded 2026-09-26** by the combined draft [`pr-preparations/2026-09-26/0044-pr-body.md`](pr-preparations/2026-09-26/0044-pr-body.md), which adds this draft's breaking commit, before/after bytes and measured 0044-without-0039 result to the Codex packet draft (newer base, extra MIR test). Post that one, not this.

# [MOS] Print an explicit width on 24-bit address operands

The 65816 assembler picks an operand's addressing mode from the text it reads, not from
what produced that text. A bare 24-bit (absolute-long) operand — `lda far_sym`,
`jmp far_sym` — is textually indistinguishable from its 16-bit absolute sibling, so
reading the printed assembly back in (exactly what `-S`/`-save-temps` does) selects the
**narrower** instruction instead of the one that was actually encoded:

```
$ llvm-mc -triple mos -mcpu=mosw65816 -disassemble <<< '0xaf,0xf0,0x00,0x00'
	lda	240                    ; reassembles as: a5 f0     (was: af f0 00 00)
$ llvm-mc -triple mos -mcpu=mosw65816 -disassemble <<< '0x5c,0xf0,0x00,0x00'
	jmp	240                    ; reassembles as: 4c f0 00  (was: 5c f0 00 00)
```

The far load loses its bank byte and becomes DBR-relative (`af`→`a5`, a direct-page
read of an unrelated address); the far tail jump becomes a bank-local one (`5c`→`4c`),
landing in the *current* ROM bank instead of the one the operand named. Branch
displacements are then recomputed over the now-shrunken code, so the result is
self-consistent and silently wrong rather than an assembler error.

## Fix

Give the `addr24` operand class a `PrintMethod` that emits an explicit `mos24(...)`
wrapper whenever the bare text could re-parse narrower, and leaves it bare otherwise:

| operand | printed | why |
|---|---|---|
| symbol / any expression | `mos24(sym)` | a bare symbol always matches the narrowest candidate |
| constant ≤ `0xFFFF` | `mos24($abcd)` | would otherwise re-parse as absolute (or zero page) |
| constant > `0xFFFF` | `$eaeaea` | already unambiguous — cannot fit a 16-bit operand |
| expression already carrying a MOS modifier | unchanged | prints its own modifier; wrapping again would give `mos24(mos24(x))` |

Only `AbsoluteLong` and `AbsoluteXLong` use the `addr24` operand class (`IndirectLong`
is `addr8` and is syntactically unambiguous via its brackets), so the change is confined
to the 65816 long forms; nothing else changes shape or width. `JMP_AbsoluteLong`
(`$5C`) and `JSL_AbsoluteLong` (`$22`) print through the same operand, so both close
without adding a new mnemonic — `jmp mos24(sym)` already reaches `$5C` once the operand
states its own width, so `$5C` needs no `jml`-style spelling of its own.

The rule is symmetric with `MOSMCInstLower::wrapAbsoluteIdxBase`, which already forces
a small constant to print with an explicit modifier so it can't collapse into
zero-page,X — "print the width only when the bare text would otherwise lie."

## Test

New `llvm/test/MC/MOS/long-address-roundtrip-65816.s`: disassembles a fixed set of
65816 long-form encodings (`lda`/`sta`/`lda ,x`/`jmp`/`jsl` on a small, 16-bit-range
address, plus a `> 0xFFFF` constant) and checks both (a) the printed text and (b) that
feeding that text straight back into the assembler reproduces the identical bytes. It
also pins that an already-unambiguous constant (`> 0xFFFF`) stays bare and that the
modifier does not double up on re-print. The test fails before this change (the
low-valued cases reassemble to the narrower opcodes shown above) and passes after.

## Scope and a stacked dependency

This patch touches only `llvm/lib/Target/MOS/MCTargetDesc/MOSInstPrinter.{h,cpp}` and
one `let PrintMethod = ...` line in `MOSInstrFormats.td`'s `addr24at<>` class — it adds
no parser surface and no new mnemonic. It applies standalone against pristine upstream
and needs no other patch to apply.

**Its round-trip *test*, however, depends on a second, separately-submitted patch** —
"[MOS] Honour an explicit width modifier on a constant operand" (`mos16(240)`,
`mos24($123456)` must not select a narrower addressing mode). **Confirmed by an isolated
build, not inferred from source reading:** with this patch applied *alone* against the
pristine pin, the disassembly-print half of the new test already passes (`lda
mos24(240)`, etc. — the printer works standalone), but the round-trip half still fails,
and fails *worse* than the original bug: re-parsing `lda mos24(240)` yields `[0xa5,0xf0]`
— **zero page**, not merely absolute — and `lda mos24(43981),x` truncates its address to
one byte (`[0xb5,0xcd]`). Only `jsl` (which has no narrower encoding to fall into) and
constants `> 0xFFFF` (already unambiguous) round-trip correctly without the other patch.
Applying that patch on top makes every case round-trip correctly. The full comparison
(before / 0044-alone / 0044+0039, byte-for-byte) is in
[the validation doc](pr-preparations/2026-09-26/0044-validation.md) §4-5. The two patches
fix opposite ends of the same round trip (this one makes the printer *say* `mos24(...)`;
the other makes the parser *honour* it for small values) and this PR should be reviewed
and merged either alongside, or after, that one.

## Breaking commit

`AbsoluteLong`/`AbsoluteXLong` and the `addr24` operand class were introduced by
[19ea9eab486f7bd784f2c4b80cba759044ca5740](https://github.com/llvm-mos/llvm-mos/commit/19ea9eab486f7bd784f2c4b80cba759044ca5740)
("Add MC instructions, relocations, and disassembler support for 65816.", Jack
Andersen, 2022-02-10). It added the long addressing modes, the long jump/call
instructions, and 10 lines to `MOSInstPrinter.cpp` for the new modes — but gave `addr24`
no `PrintMethod`, so the gap has existed since 65816 long addressing itself was added;
this is not a regression introduced by a later change.

## Validation

Pinned-base isolated validation (apply-check, fail-before/pass-after on the new test,
full MOS lit suites, and the 0039 stacked-dependency check) is recorded in
[pr-preparations validation](pr-preparations/2026-09-26/0044-validation.md).

This is independent of the SNES platform and native-width (`+mos-a16`) compiler
submissions; it is stock 65816 and does not touch any `+mos-a16` code.

Assisted-by: Claude Code CLI using Claude Sonnet 5 (`claude-sonnet-5`, `high` reasoning
effort), for pinned-base validation and this PR draft.
