# Downstream MVN/MVP correction — 2026-09-20

The live fork source and `patches/llvm-mos/0020-mos-65816-block-move-bank-order.patch`
now include both the byte-order and symbolic-fixup corrections, plus the complete
48-line regression from the upstream preparation. The unrelated native/far changes
in the vendor checkout were preserved.

The patch was reverse-applied/reapplied in an isolated copy; the resulting instruction
format and test match the live files byte for byte. Patch comments and whitespace
checks pass.

Rebuilt downstream `llvm-mc`, `llvm-objdump`, `llvm-readobj`, `clang`, and `llc`
in the existing Release development-container build. Installed the rebuilt Clang,
assembler and object-inspection tools into `build/llvm-mos-install` using their CMake
install targets. The `mos-clang` alias resolves to the updated Clang.

Installed-tool checks: encoding, disassembly, fixups, ELF relocations, and resolved
constants all pass. An additional `clang -cc1as -triple mos -target-cpu mosw65816`
assembly check passes the same symbolic relocation expectations.
[Component output](mvn-downstream-components.txt).

The downstream MOS MC suite discovers 43 tests: **42 pass, one fails**.
The block-move regression passes. `addressing-modes-65816.s` fails at line 70:
`lda addr24` emits absolute `ad 00 00` / `R_MOS_ADDR16` where the test expects
long `af 00 00 00`. That test contains no MVN/MVP instructions; its address-selection
failure is outside this correction. No before-change downstream suite run was
captured in this step, so this does not establish when that failure was introduced.
[Full suite output](mvn-downstream-suite.txt).

The separate upstream candidate retains its previously verified clean result:
130 passes, one unsupported across MOS MC/CodeGen. Published as [compiler PR #604](https://github.com/llvm-mos/llvm-mos/pull/604).
