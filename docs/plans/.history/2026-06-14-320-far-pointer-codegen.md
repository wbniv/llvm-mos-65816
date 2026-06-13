| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/7b01c2a) | docs: plan #320 Increment 1 (24-bit far-pointer codegen) + TODO |

<!--history-meta v1
7b01c2a	author	Will Norris
7b01c2a	added	113
7b01c2a	deleted	0
7b01c2a	files	1
7b01c2a	body	The 65816 instruction set + addressing modes (LDA/STA AbsoluteLong, JSL/RTL,\n[dp], Addr24 fixups, zero-bank relaxation) already exist at the MC layer\ngated on FeatureW65816 — codegen just doesn't use them. Increment 1 wires\nGlobalISel to those instructions for an additive, non-breaking 24-bit far\naddress space (addrspace 2, W65816-gated, 6502 untouched), verified at the\ndisassembly level. Code-first: this running slice informs the upstream\nfive-space ABI design rather than designing in the abstract. M1 split into\n3 TODO increments (codegen / emulator run / full model + upstream PR).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
