# [MOS] Accept an optional BRK signature operand

<!-- POSTED: https://github.com/llvm-mos/llvm-mos/pull/586
     Branch: wbniv:mos-brk-signature-operand
     Commit: 064d33fc43ca
     Fork carry: patches/llvm-mos/0024-mos-brk-signature-operand.patch
-->

## Summary

Accept an immediate signature operand on `brk` while preserving the existing operand-less form:

```asm
brk          ; 00
brk #66      ; 00 42
```

The 6502-family hardware advances the saved program counter past the byte following the BRK opcode.
That byte is conventionally available to software as a signature, but llvm-mos currently rejects
source that spells it as an operand. Programs must therefore emit the signature byte separately
after an assembled `brk` (or encode the complete instruction manually).

## Compatibility

This is strictly additive. The existing `BRK_Implied` definition and its one-byte encoding remain
unchanged. `BRK_Immediate` is assembler-only so the decoder continues selecting the established
one-byte BRK representation; this PR does not change existing binaries or disassembly behavior.

## Implementation

Add an assembler-only `BRK_Immediate` instruction using opcode `$00` and the existing 8-bit
`Immediate` operand class. Both BRK forms retain `InstUnconditionalBranch`.

COP support is intentionally excluded. Although the same demo exposed the missing 65816 COP
mnemonic, COP is target-specific and is being handled independently; this patch is a baseline MOS
BRK parser/encoding correction.

## Tests

Add `llvm/test/MC/MOS/brk-signature.s` to pin both compatibility and the new encoding. It uses a
decimal signature deliberately, so this PR does not depend on the separate `llvm-mc` bug that
overrides the MOS target's Motorola-integer default:

```asm
brk          ; encoding: [0x00]
brk #66      ; encoding: [0x00,0x42]
```

The focused MC test passes, and the standalone patch applies cleanly to the pinned pristine
llvm-mos base. The downstream SNES integration demo uses `brk #$42` directly and passes its
hardware-vector, interrupt-return, and emulator differential gates.

## Origin

Found while replacing raw instruction bytes in the playable
[Software Vectors SNES demo](https://biohack.net/snes/brkcop/)
([source](https://github.com/wbniv/llvm-mos-65816/blob/main/examples/snes/brkcop.c)).
The demo needs the signature byte to identify the trap and previously used `.byte $00,$42` because
`brk` with a signature operand was rejected; equivalently, it could have assembled `brk` followed
by a separate signature byte.

The published ROM passes its emulator differential, interrupt-envelope, signature-return, and
hardware-vector gates in default, a16, and xy16 configurations.
