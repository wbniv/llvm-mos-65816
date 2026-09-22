# SNES #415 reconciliation inventory

Updated 2026-09-20. This is a source inventory and preparation baseline, not a
validated platform patch. Dispositions below are proposals; provenance approval
and compiler ABI acceptance remain open.

- [x] Fetch SDK main `3f6968bbc156ff9a63102a8e158db868819bd61c` and #415 head
  `e6a5c17cab52026cb66924a8e2bf5fab870536f2`.
- [x] Create isolated checkout `/tmp/sdk-snes-reconcile`, branch
  `snes-415-reconciliation`, based on that SDK main.
- [x] Populate the 16 files touched by #415 with their exact PR-head contents.
  `/tmp/snes-415-original.patch` records this snapshot against main. Shared
  integration files therefore still need a selective forward port; this is not
  a rebased or build-tested candidate. The inherited patch has whitespace warnings.
- [x] Record initial file dispositions and compiler dependencies below.
- [ ] Complete source/license provenance checks before reusing third-party material.
- [ ] Produce and validate the reconciled implementation.

All #415 paths below are relative to the SDK root. Downstream equivalents are
relative to this repository. See the [main plan](415-snes-target-reconciliation.md)
for linked upstream review comments and acceptance requirements.

| #415 file | Disposition and concrete work | Depends on unfinished compiler work? |
|---|---|---|
| `README.md` | Adapt only SNES additions onto current main; fix malformed link and console name. | No |
| `examples/CMakeLists.txt` | Adapt registration so exact platform `snes` selects its examples. Preserve current main entries. | No |
| `examples/snes/CMakeLists.txt` | Retain integration, fix `cgramtest.c.c` filename; check installed-library linkage. | No |
| `examples/snes/cgramtest.c` | Retain as author example subject to provenance/API review; use a separate asset-free startup diagnostic for runtime evidence. | ABI affects execution |
| `mos-platform/CMakeLists.txt` | Forward-port only SNES registration. | No |
| `mos-platform/snes/CMakeLists.txt` | Adapt to SDK startup object/library conventions and installed headers. Keep far thunks and `mem-far.c` outside the basic bundle. | Basic configuration can proceed now |
| `mos-platform/snes/clang.cfg` | Add CPU selection; document near-model assumptions and consistent flags for runtime objects. | CPU selection alone is insufficient for merge |
| `mos-platform/snes/link.ld` | Reconcile mapping explicitly. Audit `__stack = 0x0200`, custom bank sections after `c.ld`, and repeated fixed-bank output. Compare downstream bounded 32-KiB LoROM layout; do not silently replace multi-bank behavior. | Far C access/calls need agreed compiler support |
| `mos-platform/snes/putchar_stub.c` | Check common SDK stub conventions and actual stdio dependency; retain or use common equivalent. | No |
| `mos-platform/snes/snesxc/CMakeLists.txt` | Keep library separable; verify installed includes and consumer linkage. | No for build integration |
| `mos-platform/snes/snesxc/int_snes_xc.h` | Audit cross-compiler types/macros and provenance; adapt only the LLVM-MOS contract. | Type/ABI decisions |
| `mos-platform/snes/snesxc/snes_regs_xc.h` | Audit register types and access widths; resolve questioned declarations without replacing the entire API by assumption. | Check generated MMIO accesses |
| `mos-platform/snes/snesxc/snesxc.c` | Audit provenance, bank-selection state, pointer conversion and interrupt helpers. Keep compatibility-library decisions separate from essential startup. | Banked-memory and interrupt contract |
| `mos-platform/snes/snesxc/snesxc.h` | Resolve automatic 16-bit-pointer mode and public bank-copy API against the proposed ABI. | Pointer representation |
| `mos-platform/snes/startup.s` | Independently implement linker-ordered native startup using documented downstream invariants; avoid manual initialization calls. | Correct width handling and native runtime |
| `mos-platform/snes/vectors.s` | Independently replace flagged WDC-derived implementation; C handlers use interrupt attributes, with minimal vector/default-handler glue. | Native interrupt save/restore contract |

## Downstream pieces to evaluate

| Downstream file(s) | Initial disposition |
|---|---|
| `platforms/snes/crt0.c` | Adapt native reset sequence; explicitly establish DP/DBR and stack contract. Rewrite historical comments. |
| `platforms/snes/header.s`, `link.ld` | Candidate header/vector/near-layout implementation; integrate checksum generation and decide mapping with #415 author. Audit provenance before reuse. |
| `platforms/snes/setjmp.S` | Include a coherent native context implementation; decide page-1 stack limit, verify assembly on declared compiler, and incorporate #450 zero normalization. |
| `platforms/snes/snes.h`, `snes_mmio.h`, `snes_ppu.h`, `snes_dma.h`, `snes_cpu.h`, `snes_joypad.h`, `snes_apu.h`, `snes_wram.h` | Compare public APIs/register coverage with snesxc; preserve compatible functionality and install every transitive header. |
| `platforms/snes/call-near-from-far.s`, `call-indir-far.s`, `mem-far.c` | Defer from basic startup bundle unless required by agreed ABI. Far runtime currently requires fork features, including `+mos-a16`. |
| `platforms/snes/CMakeLists.txt`, `clang.cfg` | Extract basic configuration; do not copy combined near/far runtime settings wholesale. |
| `platforms/snes-far`, `snes-hirom`, `snes-exhirom` | Follow-on mapping/runtime contributions after initial contract is agreed. |

## Work that can proceed alongside compiler development

- [ ] Forward-port registration, example selection, filename and installed-header fixes.
- [ ] Resolve provenance and produce independent startup/vector glue.
- [ ] Specify ROM layout, checksum generation, stack reservation and overflow checks.
- [ ] Prepare asset-free startup, initialized-data/BSS and interrupt diagnostics using
  existing local execution tools; record exact compiler dependencies as they appear.
- [ ] Exercise native setjmp/longjmp independently of #450's common-6502 tests.
- [ ] Prepare the collaboration note and review-resolution diff for Will to review.

The maintainer's proper-65816-support requirement remains the merge gate. SDK
preparation can proceed now. A new upstream emulator CI framework remains a
separate discussion; it is not a prerequisite added by this inventory.
