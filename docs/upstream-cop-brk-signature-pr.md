# [MOS] Add the COP mnemonic and accept a BRK/COP signature byte

<!-- [DRAFT — PR body for llvm-mos/llvm-mos; strip the H1 and this comment when posting]
     Status: DRAFTED 2026-08-04, NOT POSTED, BRANCH NOT PUSHED (posting is user-triggered).
     Branch: mos-65816-cop-brk-signature, cut from upstream main 1f334fef02b5, one commit
     61c07100970c, living locally in ~/llvm-mos. Verified in ~/llvm-mos/build-pr (MOS-only,
     Release+asserts): MC suite 39/40, the single failure (addr-asciz.s) proven pre-existing by
     stashing the change and re-running on pristine upstream.
     Post commands (user-triggered):
       git -C ~/llvm-mos push origin mos-65816-cop-brk-signature
       gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-65816-cop-brk-signature --base main \
         --title "[MOS] Add the COP mnemonic and accept a BRK/COP signature byte" \
         --body-file <(sed '1,/^-->$/d' docs/upstream-cop-brk-signature-pr.md)
     Sibling MC-layer fix awaiting the same treatment: the MVN/MVP block-move bank-order patch
     (0020, status-doc row 17) — consider posting them together.
-->

## Summary

The MOS assembler has no `cop` mnemonic at all, and `brk` accepts no operand, so both 65816
software traps have to be hand-assembled as raw bytes:

```console
$ llvm-mc -triple mos --mcpu=mosw65816
        cop #$5a        ; error: invalid instruction
        brk #$42        ; error: invalid instruction
```

`cop` is missing at every width — `$02` is simply not in the 65816 instruction table — so a program
using the COP software interrupt must write `.byte $02,$5a`, which also defeats the disassembler
(`$02` renders as `<unknown>`).

## What the hardware and the data sheet say

BRK and COP each advance the PC by **two**, so the byte following the opcode is available to the
handler as a *signature* byte, reached via the pushed return address (BRK/COP PC + 2). The hardware
makes no direct use of that byte, but it is part of the instruction as far as the program counter is
concerned:

- The **W65C816S data sheet lists both BRK and COP as two-byte instructions**, and WDC's own
  assembly-language syntax **requires** the operand for COP. WDC recommends confining user signature
  bytes to `$00`–`$7F`, since `$80`–`$FF` are marked reserved.
- COP is a genuinely separate software interrupt, not a BRK alias — it has its own vector
  (`$00FFE4` native, versus BRK's `$00FFE6`).

## Why the operand is optional here

Assemblers disagree, and there is no cross-assembler standard:

| assembler | BRK | COP | WDM |
|---|---|---|---|
| ca65 | optional signature (1 or 2 bytes) | optional signature | operand required |
| wla-dx | always 2 bytes, signature defaults to 0 | always 2 bytes | always 2 bytes |
| asar | always 2 bytes, signature defaults to 0 | always 2 bytes | always 2 bytes |

This patch follows **ca65**: `brk` → `[0x00]`, `brk #imm` → `[0x00, imm]`, `cop` → `[0x02]`,
`cop #imm` → `[0x02, imm]`.

The deciding factor is that this keeps the change **strictly additive**. Adopting the wla-dx/asar
"always two bytes" rule would silently change the size and layout of every existing program
containing `brk`, on every 65xx CPU — not acceptable for a compiler toolchain, and it would churn
the existing `all-*-opcodes.s` expectations. Every input that assembles today assembles identically
after this patch; only previously-rejected input becomes valid. It also matches the target's own
existing precedent: `wdm` already requires its operand, exactly as ca65 specifies for WDM.

## Predicate

COP is gated on `FeatureW65816`, **not** the shared `FeatureW65816Or65EL02` used by its neighbours
in that block: on the 65EL02, opcode `$02` is `NXT` (`llvm/test/MC/MOS/all-65el02-opcodes.s`). The
tests pin both halves — `cop` is rejected for `-mcpu=mos65el02`, and `nxt` still encodes to `[0x02]`
there.

## Disassembly is deliberately unchanged

BRK and COP still decode as **one-byte** instructions, so a linear sweep across a trap site still
shows the signature byte as a separate (bogus) instruction:

```
0: 02           cop
1: 5a           phy      <- the signature byte of the COP above
2: 00           brk
3: 42 ea        wdm #$ea <- the signature byte of the BRK above, plus the next opcode
```

Decoding both as two bytes would be more faithful to the data sheet and would fix that, but it would
change disassembly output for every existing 6502 program (where one-byte BRK is the near-universal
convention), so it is left for a separate discussion. I'm happy to do it as a follow-up if you want
it. The one improvement here is that `$02` now disassembles as `cop` rather than `<unknown>`.

## Tests

- `llvm/test/MC/MOS/brk-cop-signature.s` (new) — all four forms, plus an expression-valued signature
  and a second RUN line proving `brk #imm` works on plain 6502. The bare-form checks are the
  backward-compatibility guarantee.
- `llvm/test/MC/MOS/all-65816-opcodes.s` — `cop` and `cop #$ea` added beside `wdm`.
- `llvm/test/MC/MOS/asm-errors.s` — `cop` and `cop #90` rejected without `FeatureW65816`.

Red/green: all four forms error before the patch and assemble to the expected bytes after. The
`llvm/test/MC/MOS/` suite is otherwise unchanged — 39/40, with the single failure (`addr-asciz.s`)
confirmed pre-existing by stashing this patch and re-running against pristine `main`.

## Real-world origin

Found while building a 65816 demo that splits the BRK and COP software vectors on the SNES and needs
to identify the trap from its signature byte. That demo currently emits `.byte $02,$5a` /
`.byte $00,$42` as a workaround.

---

**Aside, not part of this PR:** while writing the tests I noticed that `llvm-mc` unconditionally
overrides the target's Motorola-integer setting —
`llvm/tools/llvm-mc/llvm-mc.cpp` does
`Parser->getLexer().setLexMotorolaIntegers(LexMotorolaIntegers)` with a `cl::opt` that defaults to
false, clobbering `AsmLexer`'s initialization from `MCAsmInfo::shouldUseMotorolaIntegers()`. MOS sets
`UseMotorolaIntegers = true` in `MOSMCAsmInfo` (#352), so `$`-hex works everywhere in the real
toolchain but silently stops working under bare `llvm-mc` — which is why 35 of the 39 MOS MC tests
have to pass `-motorola-integers` explicitly. The usual fix is to honour the flag only when it was
actually given (`LexMotorolaIntegers.getNumOccurrences()`). Happy to send that separately if it'd be
welcome.
