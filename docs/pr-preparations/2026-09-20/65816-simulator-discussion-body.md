I'd like to establish a repeatable upstream path for executing 65816 regression tests. We already run SNES programs under MAME and bsnes-jg downstream; the question is which setup and conventions would fit llvm-mos. This is a separate testing-infrastructure proposal, independent of individual encoding fixes.

## Existing work

- [Compiler #26](https://github.com/llvm-mos/llvm-mos/issues/26#issuecomment-806318107) proposed an LLVM-integrated emulator whose output could be checked by lit/FileCheck, with the 65xx family, including 65816, in scope.
- [Compiler #5](https://github.com/llvm-mos/llvm-mos/issues/5#issuecomment-843313465) established the separate end-to-end suite using the SDK simulator. Its [current README](https://github.com/llvm-mos/llvm-test-suite) documents `TEST_SUITE_RUN_UNDER`, including `mos-sim --cmos`. The current SDK simulator supports 6502/65C02, not 65816.
- [SDK #241](https://github.com/llvm-mos/llvm-mos-sdk/pull/241) added Emutest/Libretro tests with RAM pass/fail signatures and optional framebuffer CRC checks. [SDK #268](https://github.com/llvm-mos/llvm-mos-sdk/issues/268) remains open, proposing a simpler C/C++ Libretro runner after Atari800/Emutest reliability problems.
- In [February 2026](https://discourse.llvm.org/t/tablegen-backend-for-emulator-core/57874/7), John Byrd reported a working LLVM-integrated MOS 6502 emulation layer using TableGen/SAIL, with CI execution testing among its intended uses. The post does not establish 65816 support or an available upstream CI runner.

I haven't found a public decision choosing a 65816 runner. If this has already been settled on Discord or elsewhere, a pointer would help.

## Proposed first test

Start with a small assembly program using synthetic data and no external media assets. Initialize two distinct banks, execute MVN forward and MVP backward with immediate and symbolic bank operands, and check destination bytes, unchanged source data, and guard regions. Assemble and link with the tools under test so the execution checks exercise their emitted bytes and relocations.

Report success/failure through a defined RAM signature or runner exit status, with a bounded execution limit and useful failure output. Keep byte/relocation tests alongside execution coverage. A flat-memory CPU simulator could run this without a console; a SNES core would need a minimal cartridge/startup wrapper with explicit register-width and memory-map assumptions.

## Decisions to agree

1. **Runner:** Is extending the LLVM-integrated emulator the preferred direction? Would an existing SNES Libretro core be a useful first step, given the SDK runner concerns in #268?
2. **Test location:** Should CPU instruction regressions live with compiler lit tests, in the separate end-to-end suite, or in SDK platform tests? How should CPU-level tests be distinguished from SNES runtime tests?
3. **Setup:** Which emulator/core revision should be pinned, and should CI build it from source or use a versioned artifact? Which hosts must initially be supported?
4. **Conventions:** What load address, CPU mode, bank layout, result protocol, execution limit, and failure diagnostics should tests use? Should missing local emulator dependencies explicitly skip tests while the dedicated CI job requires them?
5. **Initial CI scope:** Would a single required 65816 configuration be appropriate before broadening the matrix? [#339](https://github.com/llvm-mos/llvm-mos/issues/339) already discusses keeping CPU/optimization combinations manageable.

We can contribute the minimal bank-copy test and adapt our downstream runner experience to the agreed approach. No new execution harness is implemented in this proposal yet.
