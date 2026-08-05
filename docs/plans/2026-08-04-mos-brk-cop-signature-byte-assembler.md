# MOS assembler: `cop` mnemonic + optional BRK/COP signature byte

**Date:** 2026-08-04 · **Status:** ⚠️ SUPERSEDED same-day (implementation verified; packaging
overtaken by the split) · **Item:** TODO `[T5]` "COP-only upstream complement" · **Owner:** this
session (posting is user-triggered and **explicitly out of scope — do not post**)

> **Superseded 2026-08-04** by the
> [split-ownership plan](2026-08-04-split-brk-cop-patch-ownership.md): the BRK half was posted
> separately as [PR #586](https://github.com/llvm-mos/llvm-mos/pull/586) (fork patch `0024`), the
> Motorola side-finding as [PR #587](https://github.com/llvm-mos/llvm-mos/pull/587) (`0025`), and
> COP is fork-carried in `0002` with a **different design than this plan chose**: mandatory
> signature operand (no bare 1-byte `cop`), decoder-visible (`$02` disassembles as a 2-byte
> `cop #imm`), `InstUnconditionalBranch` — vs this plan's optional-operand / `isAsmParserOnly` /
> 1-byte-decode. **Decided 2026-08-04 (T5): MANDATORY wins** — bare `cop` is a footgun (the
> hardware always consumes the signature slot, so a 1-byte `cop` eats the next opcode; WDC
> requires the operand), the BRK 1-byte-decode compat argument doesn't apply to 65816-only `$02`
> (decoder-visible 2-byte `cop #imm` disassembly is a free improvement), the optional-BRK /
> mandatory-COP asymmetry is WDC's own and matches the `wdm` precedent, and strict→loose is the
> reversible direction. This plan's COP design section is therefore historical; the COP-only PR
> follows the `0002` shape (full spec in the
> [draft's banner](../upstream-cop-brk-signature-pr.md)).
>
> **Review corrections (2026-08-04):** Verification step 4's "pinned by a test" overstates —
> the 65EL02 `cop` rejection was verified manually only (`asm-errors.s` runs at `-mcpu=mos6502`),
> so no lit test guards `FeatureW65816` vs the shared predicate; add a 65el02 RUN line in the
> COP-only PR. The round-trip disassembly check (Tests item 4) was done manually, not landed as a
> lit test, and the promised `brk #$ea` line in `all-65816-opcodes.s` was not added (covered by
> `brk-cop-signature.s` instead).

**Visible surface:** none — assembler/MC layer and a lit test. No mockups.

## The gap (measured, not assumed)

Found while building the #140 BRK/COP software-vector demo, which had to hand-encode both traps as
`.byte $02,$5a` / `.byte $00,$42`. Confirmed against the current toolchain
(`build/upstream-llc/bin/llvm-mc -triple=mos -mcpu=mosw65816 -show-encoding`):

```
brk                 ; encoding: [0x00]          <- works, 1 byte
brk #$42            ; error: invalid instruction
cop #$5a            ; error: invalid instruction
wdm #$42            ; encoding: [0x42,A]        <- works, 2 bytes (the precedent)
```

So: **`cop` does not exist at any width**, and **`brk` accepts no signature operand**. This is a
stock-llvm-mos assembler/ISA-table gap, not a `+mos-a16` or fork issue.

## What the hardware and the official docs actually say

Researched rather than assumed (the user asked specifically what WDC specifies):

- **Hardware:** BRK, COP and WDM each advance the PC by **two** bytes, "even though the hardware
  does not make any direct use of the second 'operand' byte"
  ([SNESdev Wiki — Signature byte](https://snes.nesdev.org/wiki/Signature_byte)). The byte is
  skipped whether or not the assembler emits one; the handler may read it via the pushed return
  address (which is BRK/COP PC + 2).
- **WDC datasheet:** lists **both BRK and COP as two-byte instructions**, and the signature byte is
  **required by WDC's own assembly-language syntax for COP**. WDC recommends confining user
  signature bytes to `$00`–`$7F` because `$80`–`$FF` are marked reserved
  ([BCS Technology, *Investigating 65C816 Interrupts*](https://6502.org/tutorials/65c816interrupts.html)).
- **Vectors** (native mode): COP `$00FFE4`, BRK `$00FFE6` — COP is a genuinely separate software
  interrupt, not an alias of BRK.
- **There is no cross-assembler standard.** Per the SNESdev wiki:
  - **ca65** — optional signature for BRK and COP (either 1 or 2 bytes); WDM always requires it.
  - **wla-dx** — always 2 bytes for BRK/COP/WDM, signature defaults to `0`.
  - **asar** — always 2 bytes for BRK/COP/WDM, signature defaults to `0`.

So "is the operand optional?" has no single right answer at the ISA level: the *hardware* always
consumes the slot, the *WDC syntax* requires it for COP, and *assemblers disagree*.

## Design decision — follow ca65 (optional operand)

`brk` → `[0x00]`; `brk #imm` → `[0x00, imm]`; `cop` → `[0x02]`; `cop #imm` → `[0x02, imm]`.

Rationale, in priority order:

1. **Backward compatibility is non-negotiable.** llvm-mos already emits 1-byte `brk`, and it is a
   *compiler* toolchain — adopting the wla-dx/asar "always 2 bytes" rule would silently change the
   size and layout of every existing program containing `brk`, on every 65xx CPU, and would churn
   the existing `all-*-opcodes.s` tests. A gap-filling patch must not do that.
2. **It matches llvm-mos's own existing precedent.** `wdm` is already `Inst16<"wdm", Opcode<0x42>,
   Immediate>` with a mandatory operand — exactly ca65's rule for WDM. Making BRK/COP optional
   completes the same convention rather than inventing a new one.
3. **It is strictly additive.** Every input that assembles today assembles identically after the
   change; only previously-rejected input becomes valid.

`cop` bare (1 byte) is included for symmetry with `brk` and because ca65 allows it. Programs that
want WDC-strict behaviour simply always write the operand.

## Implementation

Target file: `llvm/lib/Target/MOS/MOSInstrInfo.td` (upstream tree — the PR is cut from
`~/llvm-mos`, the `wbniv/llvm-mos` clone, off upstream `main`).

1. **COP** — add under `let Predicates = [HasW65816]`, next to `WDM_Immediate`:
   - `def COP_Immediate : Inst16<"cop", Opcode<0x02>, Immediate>;` (2-byte form)
   - `def COP_Implied : Inst8<"cop", Opcode<0x02>>;` (1-byte form)

   **Predicate correctness (verified, not assumed):** COP must be `HasW65816`, **not**
   `HasW65816Or65EL02` — on the 65EL02 opcode `$02` is `nxt`
   (`llvm/test/MC/MOS/all-65el02-opcodes.s:35`, `; CHECK: encoding: [0x02]`). Using the shared
   predicate would collide with a real, tested instruction.

2. **BRK** — add the 2-byte form alongside the existing
   `def BRK_Implied: InstLow0<"brk", 0b0000>, InstUnconditionalBranch;`.

3. **Decoder-conflict handling.** Two instructions sharing one opcode need exactly one of them
   excluded from the disassembler tables. The 1-byte form stays the decoder's choice (preserving
   today's disassembly for every CPU); the 2-byte forms are marked assembler-only. Whether that is
   `isAsmParserOnly` or an explicit decoder exclusion is an **empirical question** — build TableGen
   and let it report conflicts rather than predicting (project lesson 1). If the mechanism proves
   ugly, the fallback is a single instruction with a genuinely optional operand
   (`AsmOperandClass` + custom parse method), which is more code but no decoder ambiguity.

**Disassembly is deliberately unchanged.** BRK/COP continue to decode as 1 byte, so a listing that
sweeps across a trap site still shows the signature byte as a separate (bogus) instruction. Making
the disassembler consume the signature byte is arguably more faithful to WDC, but it changes output
for every existing 6502 program and is a separate discussion — raised in the PR body, not bundled.

## Tests

`llvm/test/MC/MOS/` follows a per-CPU `all-<cpu>-opcodes.s` pattern (`llvm-mc -assemble
--print-imm-hex --show-encoding -triple mos --mcpu=<cpu>` + `FileCheck` on
`; CHECK: encoding: [...]`).

- Extend `all-65816-opcodes.s` with `cop #$ea` and `brk #$ea` (matching the file's `$ea` filler
  convention), plus the bare forms if not already covered.
- Add a focused `brk-cop-signature.s` covering all four forms and pinning that the bare forms stay
  1 byte (the backward-compatibility guarantee).
- Add a negative test: `cop` must be **rejected** on `-mcpu=mos65el02` and on plain 6502
  (`asm-errors.s` is the existing home for rejection tests).
- Round-trip: `llvm-mc` → `llvm-objdump -d --mcpu=mosw65816` on a `cop`/`brk` sequence, to record
  the (unchanged, 1-byte) disassembly behaviour explicitly rather than leaving it implicit.

## Verification

Implemented as commit `61c07100970c` on branch `mos-65816-cop-brk-signature` (cut from upstream
`main` `1f334fef02b5`), local to `~/llvm-mos` — **not pushed**.

1. TableGen + build clean in the upstream tree (`~/llvm-mos/build-pr`, MOS-only): `ninja llvm-mc
   llvm-objdump FileCheck not` with no decoder-conflict errors.

    ```
    [30/30] Linking CXX executable bin/llvm-objdump
    ```
    **PASS** — no decoder conflict. Resolution: the 1-byte form is the real instruction and the
    2-byte form carries `isAsmParserOnly`, for both BRK and COP. (First attempt marked the wrong
    COP form parser-only; TableGen accepted it but `cop #imm` then failed to match, so the two
    mnemonics are now symmetric.)

2. Red/green on the four new forms: each errors before the change, assembles to the expected bytes
   after.

    ```
    $ build-pr/bin/llvm-mc -assemble --print-imm-hex --show-encoding -triple mos \
        -motorola-integers --mcpu=mosw65816 t4.s
        brk                     ; encoding: [0x00]
        brk     #$ea            ; encoding: [0x00,0xea]
        cop                     ; encoding: [0x02]
        cop     #$5a            ; encoding: [0x02,0x5a]
        wdm     #$ea            ; encoding: [0x42,0xea]     (untouched, unchanged)
    ```
    Before the change the same input produced 3 `invalid instruction` errors. **PASS**

3. **No regression on the bare forms:** `brk` still `[0x00]` (above); full MC suite:

    ```
    $ build-pr/bin/llvm-lit -q llvm/test/MC/MOS/
    Total Discovered Tests: 40
      Failed: 1 (2.50%)      <- MC/MOS/addr-asciz.s
    ```
    [CORRECTED 2026-08-04, post-record: the 'single failure' was an exit-127 artifact — the
    minimal build lacked llvm-readelf, which addr-asciz.s RUNs; with it built the MC suite is
    fully green. 'Proven pre-existing' was vacuous (pristine also ran without the tool).]
    The single failure was proven **pre-existing**: `git stash` + rebuild + re-run on pristine
    upstream fails identically (`Failed: 1 (100.00%)` for that test alone). **PASS**

4. Predicate gate:

    ```
    $ ... --mcpu=mos6502   : error: instruction requires: FeatureW65816   (cop #$5a)
    $ ... --mcpu=mos65el02 : error: instruction requires: FeatureW65816   (cop #$5a)
                             nxt   ; encoding: [0x02]                     (still correct)
    ```
    **PASS** — the 65EL02 `NXT` collision is avoided and pinned by a test.

5. Round-trip disassembly recorded (behaviour deliberately unchanged):

    ```
    $ llvm-objdump -d --mcpu=mosw65816 rt.o
       0: 02        cop
       1: 5a        phy        <- COP's signature byte, swept as an instruction
       2: 00        brk
       3: 42 ea     wdm #$ea   <- BRK's signature byte + the next opcode
    ```
    Bytes are correct (`02 5a 00 42 ea`); the linear-sweep artifact is the pre-existing 1-byte
    decode, now improved only in that `$02` reads as `cop` instead of `<unknown>`. **PASS (as
    designed)**

## Side finding — `llvm-mc` clobbers the target's Motorola-integer default

Not a MOS bug and **not part of this PR** (kept separate rather than bundled). While writing tests,
`cop #$5a` was rejected under bare `llvm-mc` — but so is `wdm #$5a`, an instruction this patch never
touches, so it is not COP-specific. Root cause:

- `AsmLexer.cpp:115` initialises `LexMotorolaIntegers = MAI.shouldUseMotorolaIntegers()`, and
  `MOSMCAsmInfo.cpp:45` sets `UseMotorolaIntegers = true` — so `$`-hex **is** the MOS default.
- `llvm/tools/llvm-mc/llvm-mc.cpp:374` then unconditionally calls
  `setLexMotorolaIntegers(LexMotorolaIntegers)` from a `cl::opt` that defaults to **false**,
  overwriting the target's choice.
- Chronology: the override arrived with `4db18d62afa8` *[M68k] Add support for Motorola literal
  syntax* (2021-01-26), before MOS opted in via MCAsmInfo (`fe2a50e1656b`, llvm-mos #352). No
  GitHub issue exists for it in llvm-mos.
- Consequence: **35 of 39** MOS MC tests pass `-motorola-integers` explicitly to compensate. The
  real toolchain is unaffected — `mos-clang --target=mos -mcpu=mosw65816 -c` assembles
  `wdm #$5a` → `42 5a` with no flags.
- Standard fix: honour the flag only when given (`LexMotorolaIntegers.getNumOccurrences()`). It is
  posted independently as [llvm-mos PR #587](https://github.com/llvm-mos/llvm-mos/pull/587), with
  its own [plan](2026-08-04-llvm-mc-motorola-default.md) and fork patch
  `patches/llvm-mos/0025-llvm-mc-preserve-motorola-default.patch`.

## Upstream packaging (prepare only — DO NOT POST)

- Mint `wbniv:mos-65816-cop-brk-signature` off upstream `main` in `~/llvm-mos`, one commit.
- Draft the PR body as `docs/upstream-cop-brk-signature-pr.md` (house draft format: `# [DRAFT …]`
  preamble with the exact `gh pr create` command, body below the `---`), covering: the gap, what
  WDC/hardware actually specify, the cross-assembler survey, why ca65's optional rule was chosen,
  the 65EL02 `nxt` collision avoided, and the deliberately-unchanged disassembly with an offer to
  do it separately.
- Queue as a new row in [`docs/upstream-contribution-status.md`](../upstream-contribution-status.md)
  (**not posted**), and mirror the one-line pointer into TODO's *Upstream / Contribution* section.
- Related but separate: the `MVN`/`MVP` bank-order MC fix (patch `0020`, status-doc row 17) is the
  other 65816 MC-layer item awaiting submission polish. Both are MC/TableGen fixes found by demo
  work; consider posting them as siblings.

## Out of scope

- Carrying the fix as a fork patch for the #140 demo (the `.byte` workaround stands until upstream
  lands or a `0021` carry is decided) — separate decision, not blocking the PR.
- Changing BRK/COP **disassembly** length (see above).
- `wdm`'s mandatory operand — already matches ca65; untouched.
