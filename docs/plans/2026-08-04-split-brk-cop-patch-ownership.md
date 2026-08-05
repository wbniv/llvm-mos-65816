# Split BRK/COP patch ownership

**Date:** 2026-08-04  
**Status:** complete

## Decision

The `brkcop` demo found two assembler-model gaps and one SNES SDK vector defect. They belong to
three different ownership units and must not be shipped as one mixed patch:

1. **COP assembler support belongs to the 65816/a16 compiler body.** Add the W65816-only
   `cop #signature` instruction definition and its MC encoding regression to
   `0002-321-accum16.patch`. COP does not exist on the baseline 6502 target.
2. **BRK signature support is a standalone llvm-mos patch.** Preserve the existing operand-less
   baseline form and add `brk #signature` as an assembler-only encoding, preserving compatibility
   while exposing the architectural signature byte. Test it on the baseline MOS target. Carry this as
   `0024-mos-brk-signature-operand.patch` so it can be reviewed independently of a16.
3. **SNES vector wiring remains SDK platform source.** Weak `brk`/`cop` handlers in
   `platforms/snes/crt0.c` and the distinct linker vector slots in all five SNES platform variants
   remain tracked as complete platform trees. This repository does not currently maintain an
   `llvm-mos-sdk` patch series; `dev/build.sh` injects those trees into a clean SDK checkout.

## Implementation

- Define `COP_Immediate` as opcode `$02`, immediate signature byte, gated by `HasW65816`, and mark
  it as an unconditional control transfer.
- Keep baseline `BRK_Implied` and add assembler-only `BRK_Immediate` at opcode `$00` with an
  immediate signature byte and the same control-flow property.
- Update MC tests to require `cop #$5a -> 02 5a` and `brk #$42 -> 00 42`.
- Regenerate `0002` while excluding the standalone BRK delta from its mirror.
- Register `0024` in the clean toolchain apply order and the `0002` regeneration exclusion list.
- Replace the demo's raw `.byte` traps with natural `brk #imm` / `cop #imm` inline assembly after
  the assembler tests pass.

## Gates

1. Focused `llvm-mc` encode checks and linked-ROM `llvm-objdump` decode checks for both
   instructions.
2. Relevant MOS MC lit tests pass.
3. `0024` reverse-applies cleanly from the live tree and re-applies after the tracked stack.
4. `dev/regen-patch.sh` round-trips the regenerated `0002` without absorbing `0024`.
5. `dev/run.sh toolchain`, followed by `dev/run.sh brkcop`, passes using natural mnemonics.
6. `git diff --check` passes for authored source/script/plan changes. Generated patch files retain
   the upstream MC fixture's intentional leading-space-plus-tab formatting.

## Completion record

- `0002-321-accum16.patch`: 6,179 lines; owns W65816-only `COP_Immediate` and the
  `cop #$5a -> [0x02,0x5a]` MC case.
- `0024-mos-brk-signature-operand.patch`: 23 lines; preserves baseline `BRK_Implied`, adds the
  assembler-only `BRK_Immediate`, and owns the `brk #$42 -> [0x00,0x42]` MC case.
- `dev/regen-patch.sh`: PASS; regenerated `0002` and round-tripped its MOS sources plus focused
  tests while reversing `0024` and the other standalone patches.
- Focused MOS MC lit tests: 2/2 PASS. Direct encoding output is `00 42` for BRK and `02 5a` for
  COP. The linked demo disassembly decodes those byte pairs as `brk #$42` and `cop #$5a` at all
  four natural-mnemonic trap sites.
- Clean toolchain rebuild: PASS.
- `dev/run.sh brkcop`: PASS in default, a16, and xy16; host and all ROM modes produce `0xA34C`,
  with three deterministic a16 runs. Both native vector slots resolve to the C handlers.
- Scope correction: no SDK patch was created. The SNES vector fix remains in the five complete
  platform source trees, matching the repository's existing SDK customization model.
- BRK upstream submission: [llvm-mos PR #586](https://github.com/llvm-mos/llvm-mos/pull/586),
  branch `wbniv:mos-brk-signature-operand`, amended commit `064d33fc43ca`. Its focused test uses
  decimal `brk #66` under bare `llvm-mc`, leaving `$`-literal handling to standalone patch `0025`.
