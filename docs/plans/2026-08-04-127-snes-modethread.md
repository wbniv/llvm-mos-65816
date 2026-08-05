# #127 — Threaded Mode Interpreter (`modethread`)

**Status:** DONE + PUBLISHED 2026-08-04 — clean positive. Round 7 compiler-probe ROM.

## Test and result

A GNU C labels-as-values dispatcher alternates byte add/xor handlers with native 16-bit
add/xor/rotate handlers. Every computed-goto dispatch is an indirect control-flow join where the
65816 M-width state must be conservative. Ninety-six seeded runs fold the interpreter output tape
into host oracle `0x0489`.

Disassembly contains a genuine indirect `jmp` plus `rep` and `sep`; the non-LTO object passes the
machine verifier. Host, default, a16, and xy16 all produce `0x0489` on MAME and bsnes-jg.

The upper visual tape colors A8 handlers blue and A16 handlers magenta, with a gold indirect-target
cursor. The output bytes from those handlers build the glyph below.

Run with `dev/run.sh modethread`.

## Publication

- [biohack.net](https://biohack.net/snes/modethread/) — `v1.0.379`, commit `d4a9c76`
- [indri.studio](https://indri.studio/apps/llvm-mos-65816/snes/modethread/) — `v0.1.148`, commit `2c18640`
- SHA-256: `5ca8f841faec8d779a092044682088fcb60e291f4f6f6ede28fd50f0b57e4b3e`

Both live pages, ROM downloads, and newest-first catalog cards passed paired verification.
