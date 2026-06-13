| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/4057be1) | #320 step 1: declare 32-bit far address space (addrspace 2), non-breaking |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/7b01c2a) | docs: plan #320 Increment 1 (24-bit far-pointer codegen) + TODO |

<!--history-meta v1
4057be1	author	Will Norris
4057be1	added	24
4057be1	deleted	2
4057be1	files	1
4057be1	body	First backend change for far-pointer codegen, plus the reproducible-patch\nworkflow for editing the (gitignored) llvm-mos source.\n\n- patches/llvm-mos/0001-320-far-addrspace.patch: AS_Far=2 in the AddressSpace\n  enum + p2:32:8 in the data layout. 32-bit (not 24) because LLVM requires\n  power-of-two pointer sizes; only the low 24 bits are emitted as 65816\n  absolute-long. The data-layout string lives in THREE places that must stay\n  identical (backend MOSTargetMachine.cpp, clang Targets/MOS.cpp, TargetParser\n  TargetDataLayout.cpp) — all updated, else "backend data layout does not match\n  expected target description".\n- dev/toolchain.sh: apply patches/llvm-mos/*.patch after a fresh clone (the\n  patch IS the eventual upstream PR diff; vendor/ stays gitignored).\n\nVerified: patch applies cleanly to a pristine clone; clean toolchain rebuild +\ncorpus on the self-built compiler -> 7/7. The far address space is inert for\n6502 codegen — a non-breaking foundation. Next: legalize the 32-bit far pointer\nand route addrspace-2 loads/stores to LDA/STA AbsoluteLong.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
7b01c2a	author	Will Norris
7b01c2a	added	113
7b01c2a	deleted	0
7b01c2a	files	1
7b01c2a	body	The 65816 instruction set + addressing modes (LDA/STA AbsoluteLong, JSL/RTL,\n[dp], Addr24 fixups, zero-bank relaxation) already exist at the MC layer\ngated on FeatureW65816 — codegen just doesn't use them. Increment 1 wires\nGlobalISel to those instructions for an additive, non-breaking 24-bit far\naddress space (addrspace 2, W65816-gated, 6502 untouched), verified at the\ndisassembly level. Code-first: this running slice informs the upstream\nfive-space ABI design rather than designing in the abstract. M1 split into\n3 TODO increments (codegen / emulator run / full model + upstream PR).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
