| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/fdd1fd4) | #321 DWARF round-trip (step 6): drmon-first plan + Step-1 audit (CLEAN) |

<!--history-meta v1
fdd1fd4	author	Will Norris
fdd1fd4	added	380
fdd1fd4	deleted	0
fdd1fd4	files	1
fdd1fd4	body	Plan for ROADMAP step 6 (DWARF round-trip / drmon tie-in), sequenced to do all\ndrmon (drdevtools) work first, pause for review, then any vendor/llvm-mos edits.\n\nStep 1 (read-only llvm-dwarfdump audit) DONE and CLEAN — the DWARF *content* is\nalready correct, no emission fix needed:\n  - examples/65816/a16local.c -g -Os +mos-a16, --verify clean (exit 0)\n  - compile unit addr_size=0x04; main DW_AT_frame_base = DW_OP_regx RS0\n  - the 16-bit local `t` (the high-risk imaginary-register case) gets a correct\n    DW_AT_location loclist: [..): DW_OP_regx RS1\n  - line table maps every source line; line 13 -> $8031 in the linked ELF\n\nKEY FINDING (toolchain gap, not a codegen bug): the SNES build discards the\ndebug ELF — snes/lib/link.ld ends with OUTPUT_FORMAT { FULL(rom) }, so ld.lld\nwrites only the flat .sfc and the DWARF is never emitted to disk. Recovered by\nlinking with that block stripped (proven: ELF, debug_info, real $8000 addrs).\nSo step 6's remaining compiler-side work is a debug-ELF emission path (sdk-side)\nplus regression tests — folded into the plan's Step 5.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
