# #125 — Inline-Asm Island (`asmisland`)

**Status:** DONE + PUBLISHED 2026-08-03 — clean positive, no compiler defect found. Round 7 compiler-probe ROM.

## Question and shape

Can native-width C keep live values correct across opaque inline assembly that changes M, clobbers A
and flags, and uses width-sensitive immediate encodings? Each of 160 iterations performs native C
arithmetic, crosses an inline-asm island, then consumes values kept live across that island.

The island saves P, enters A8, writes an explicitly encoded one-byte immediate, enters A16, uses an
explicitly encoded two-byte immediate, then restores P. Clobbers are `a`, `cc`, and `memory`.

## Gates and result

- Raw object bytes contain `SEP #$20; LDA #$5A` as `e2 20 a9 5a`.
- Raw object bytes contain `REP #$20; LDA #$00FF` as `c2 20 a9 ff 00`.
- Machine code after `PLP` re-establishes M16 before native C operations.
- Host/default/a16/xy16 all return `0x260B` under `-verify-machineinstrs`.

The raw-byte checks are intentional: the width-unaware disassembler renders the A8 immediate as if
the following store opcode were its high byte. Runtime decoding follows M correctly. No compiler
fix was needed.

Run with `dev/run.sh asmisland`.

The visual frames the opaque asm island in yellow, with a live-value packet entering from the left,
changing lanes while hidden inside the magenta block, and exiting on the right. The cyan background
stream makes the boundary crossing visible rather than leaving the ROM as a text-only diagnostic.

## Publication

- [biohack.net demo](https://biohack.net/snes/asmisland/) — visual release `v1.0.368`, commit `6f05515`
- [indri.studio demo](https://indri.studio/apps/llvm-mos-65816/snes/asmisland/) — visual release `v0.1.138`, commit `061b749`
- Published ROM: `build/asmisland-a16.sfc`
- SHA-256: `744e3c3b46668e02b5211ba8efeb8e64644eee31782eec2820b6230ca3998edb`

Both live pages returned HTTP 200 and both live ROM downloads matched the local SHA-256.
