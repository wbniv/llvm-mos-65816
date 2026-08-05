# #128 — 64K Bank-Boundary Walk (`bankwalk`)

**Status:** DONE + PUBLISHED 2026-08-04 — clean positive. Round 7 compiler-probe HiROM.

A generated far table begins at C1:0000. Starting at offset FFF0, the probe reads 64 bytes across
C1:FFFF into C2:0000 via forward pointer increments, runtime indexed offsets, and reverse pointer
decrements. The value formula includes the bank ordinal, preventing a lost carry from aliasing the
expected byte. Host, a16, and xy16 agree at `0x4ED7` on MAME and bsnes-jg; non-LTO disassembly
contains `lda [dp]` far loads and the machine verifier passes.

Blue and magenta sampled-bit trails approach the gold bank seam in opposite directions, with the
two live cursors derived from the tested walkers. Run with `dev/run.sh bankwalk`.

## Publication

- [biohack.net](https://biohack.net/snes/bankwalk/) — `v1.0.380`, commit `9fce787`
- [indri.studio](https://indri.studio/apps/llvm-mos-65816/snes/bankwalk/) — `v0.1.149`, commit `daa2568`
- SHA-256: `842198fe0106746687cfc5b426932a1e9291d492cc2c442428ab6e7c7778846b`

Both live downloads and newest-first catalog cards passed paired verification.
