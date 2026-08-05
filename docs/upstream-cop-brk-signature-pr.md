# [MOS] Add the COP mnemonic with a mandatory signature operand

<!-- [DRAFT — PR body for llvm-mos/llvm-mos; strip the H1 and this comment when posting]
     COP-only complement to PR #586 (BRK's optional signature operand). Cut independently from
     upstream main so its history stays clean -- it does NOT build on #586's branch, it cites it.
     The old BRK+COP combined preview branch (`mos-65816-cop-brk-signature`, superseded 2026-08-04)
     stays untouched as reference only; this branch replaces it for the COP portion.

     DESIGN (2026-08-04 T5 call): MANDATORY operand -- the fork's `0002` shape (decoder-visible,
     2-byte decode). Bare `cop` is rejected; `cop #imm` is required. This retires the combined
     draft's optional-operand / isAsmParserOnly / 1-byte-decode COP. Rationale: (1) bare `cop` is a
     footgun -- hardware always consumes the signature slot, so a 1-byte `cop` silently eats the next
     opcode; WDC's own syntax requires the operand for COP; (2) the BRK 1-byte-decode compatibility
     argument does not apply to COP ($02 is 65816-only, currently `<unknown>`), so decoder-visible
     `cop #imm` gives faithful 2-byte disassembly at zero cost; (3) the optional-BRK(#586) /
     mandatory-COP asymmetry is WDC's own, and matches the `wdm` mandatory precedent already
     upstream; (4) strict -> loose is the reversible direction; (5) the fork ships exactly this
     shape, validated by the #140 brkcop demo gates. Full ruling history: git blame ceead8d on this
     file, and docs/plans/2026-08-04-split-brk-cop-patch-ownership.md.

     Status: ✅ POSTED 2026-08-04 as https://github.com/llvm-mos/llvm-mos/pull/588 (user-triggered
     "publish the PR"; branch pushed + PR created same session; body below is the as-posted text,
     including the de-forked a16/xy16 soak-coverage wording, cb87da8).
     Branch: mos-65816-cop-mnemonic, cut from upstream main 1f334fef02b5, one commit
     3ac109760642, living locally in ~/llvm-mos. Verified in ~/llvm-mos/build-pr (MOS-only,
     Release+asserts): TableGen/build clean (no decoder conflict -- $02 has exactly one
     decoder-visible def per predicate), all new/changed tests proven red-before/green-after, MC
     suite fully green (40/40) once llvm-readelf is built. [CORRECTED 2026-08-04: the earlier '5 pre-existing failures on pristine tip' / '39/40 lone failure' claims were exit-127 tool-missing artifacts of the minimal build-pr tool set (opt, llvm-readelf absent); with the tools built the suites are fully green — CodeGen 79 pass + getchar-regression.ll upstream-disabled (UNSUPPORTED: target), 0 failures; MC 39/39 (+ the branch's own new tests). Rule: build the tools the suite RUNs before quoting numbers; exit-127 in a lit log is an environment defect.]
     PRE-FLIGHT resolved 2026-08-04: the user pushed this repo's main, and the "(source)" link
     verified HTTP 200 before posting. Both links live.
     Post commands (as executed):
       git -C ~/llvm-mos push origin mos-65816-cop-mnemonic
       gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-65816-cop-mnemonic --base main \
         --title "[MOS] Add the COP mnemonic with a mandatory signature operand" \
         --body-file <(sed '1,/^-->$/d' docs/upstream-cop-brk-signature-pr.md)
-->

## Summary

The MOS assembler has no `cop` mnemonic at all -- `$02` is simply not in the 65816 instruction
table -- so a program using the COP software interrupt has to hand-assemble it as a raw byte pair:

```console
$ llvm-mc -triple mos --mcpu=mosw65816
        cop #$5a        ; error: invalid instruction
```

That also defeats the disassembler: `$02` renders as `<unknown>` rather than as an instruction.

## What the hardware and the data sheet say

COP advances the PC by **two**, so the byte following the opcode is available to the handler as a
*signature* byte, reached via the pushed return address (COP PC + 2). The hardware makes no direct
use of that byte, but it is part of the instruction as far as the program counter is concerned:

- The **W65C816S data sheet lists COP as a two-byte instruction**, and **WDC's own
  assembly-language syntax requires the operand** -- unlike BRK, which WDC's syntax leaves bare.
  WDC recommends confining user signature bytes to `$00`-`$7F`, since `$80`-`$FF` are marked
  reserved.
- COP is a genuinely separate software interrupt, not a BRK alias -- it has its own vector
  (`$00FFE4` native, versus BRK's `$00FFE6`).

Cross-assembler behavior varies on whether the signature byte is optional:

| assembler | BRK | COP | WDM |
|---|---|---|---|
| ca65 | optional signature (1 or 2 bytes) | optional signature | operand required |
| wla-dx | always 2 bytes, signature defaults to 0 | always 2 bytes | always 2 bytes |
| asar | always 2 bytes, signature defaults to 0 | always 2 bytes | always 2 bytes |

## Design: the operand is mandatory

This PR requires the signature operand for `cop`: `cop #$5a` assembles, bare `cop` is rejected.

That is a deliberate asymmetry with BRK, whose optional-signature form landed separately in #586.
The asymmetry is WDC's own, not invented here -- WDC's syntax already requires COP's operand while
leaving BRK's optional, and the target's existing `wdm` (also W65816-only, also a software trap with
a mandatory immediate byte) already requires its operand upstream. Making bare `cop` an error rather
than accepting it and silently emitting `[0x02]` avoids a real footgun: the hardware always consumes
the byte after `$02` as part of the instruction, so a 1-byte `cop` in source would misassemble any
program that (correctly, per the data sheet) expected the next byte to be data, not the following
opcode. Strict-to-loose is the reversible direction if a real-world program is ever found wanting the
bare form; loose-to-strict is not.

## Predicate

COP is gated on `FeatureW65816`, **not** the shared `FeatureW65816Or65EL02` used by its neighbours
in that block: on the 65EL02, opcode `$02` is `NXT` (`llvm/test/MC/MOS/all-65el02-opcodes.s`), a
different instruction that happens to share the encoding. `llvm/test/MC/MOS/cop-signature.s` pins
this directly with a `-mcpu=mos65el02` negative `RUN` line -- previously **nothing** guarded this
choice: `llvm/test/MC/MOS/asm-errors.s` runs only at `-mcpu=mos6502`, so a refactor onto the shared
predicate would have passed the whole existing suite while silently breaking 65EL02's `nxt`.

## Disassembly is faithful, not merely unchanged

Because the operand is mandatory and decoder-visible, `cop #imm` disassembles as a proper two-byte
instruction rather than as two separate bogus one-byte instructions:

```console
$ llvm-mc -triple mos -mcpu=mosw65816 -filetype=obj -o=t.o t.s   # t.s: cop #$5a
$ llvm-objdump -d --mcpu=mosw65816 t.o
       0: 02 5a           cop     #$5a
```

Before this patch, the same two bytes disassembled as `<unknown>` at offset 0 followed by a bogus
one-byte instruction at offset 1 (whatever opcode `$5a` happens to be). This is possible precisely
*because* COP is 65816-only: unlike BRK, where a 2-byte decode would change disassembly output for
every existing 6502 program using the near-universal 1-byte `brk` convention, there is no installed
base of 1-byte `cop` disassembly to preserve -- `$02` was never previously a valid 65816 instruction
at all.

## Tests

- `llvm/test/MC/MOS/all-65816-opcodes.s` -- `cop #$ea` added beside `wdm #$ea`.
- `llvm/test/MC/MOS/asm-errors.s` -- both `cop #90` and bare `cop` rejected at `-mcpu=mos6502`:
  the former with `instruction requires: FeatureW65816` (the immediate form exists but the feature
  is off), the latter with `invalid instruction` (no zero-operand `cop` form exists at all outside
  `FeatureW65816`, so the bare mnemonic doesn't match any variant).
- `llvm/test/MC/MOS/cop-signature.s` (new) -- an expression-valued signature (`sig = $5a; cop #sig`)
  and the `$7f` WDC-recommended boundary, both checked through a positive `llvm-mc` |
  `llvm-objdump -d` round trip pinning `02 5a -> cop #$5a` and `02 7f -> cop #$7f`; plus the
  `-mcpu=mos65el02` negative `RUN` line described above.

Red/green: all four new/changed tests were confirmed to fail without the `COP_Immediate` definition
(reverted via `git stash`) and pass with it. The `llvm/test/MC/MOS/` suite is otherwise unchanged --
and fully green (40/40).

*Correction (same day, mirrored from the live PR):* an earlier revision reported 39/40 with
`addr-asciz.s` as a "pre-existing failure" — an exit-127 artifact of the reporter's minimal build
lacking `llvm-readelf`; with the tool present the test passes on both trees.

## Real-world origin

Found while building a 65816 demo that splits the BRK and COP software vectors on the SNES and needs
to identify the trap from its signature byte: the playable
[Software Vectors SNES demo](https://biohack.net/snes/brkcop/)
([source](https://github.com/wbniv/llvm-mos-65816/blob/main/examples/snes/brkcop.c)). The demo
previously emitted `.byte $02,$5a` as a workaround because `cop` didn't exist as a mnemonic at all;
it now uses `cop #$5a` directly. BRK's half of the same demo motivated #586, posted separately since
BRK is baseline-MOS and COP is W65816-only.

The published ROM passes its emulator differential, interrupt-envelope, signature-return, and
hardware-vector gates — both with the stock 8-bit-register code generation and in our 65816
development fork's opt-in 16-bit-accumulator/index modes (fork-only features, mentioned here only
as extra soak coverage; nothing in this PR depends on them).
