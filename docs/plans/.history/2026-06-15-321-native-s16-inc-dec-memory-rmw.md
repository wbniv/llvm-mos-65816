| Date | Change |
|------|--------|
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/c069393) | #321 native s16: inc a/dec a for global g ± 1 (and reject the unsafe inc abs RMW) |

<!--history-meta v1
c069393	author	Will Norris
c069393	added	80
c069393	deleted	0
c069393	files	1
c069393	body	A 16-bit `g = g ± 1` on a global compiled to `clc; lda g; adc #$0001; sta g`\n(4 instrs). selectAlu16Abs now emits `lda g; inc/dec a; sta g` (3 instrs) for the\n±1 immediate G_ADD16_ABS — dropping the clc and shrinking adc #imm16 to a 1-byte\ninc a/dec a, reusing the existing INCAcc16/DECAcc16 (part 1) and the SAME 24-bit\nlong load/store addressing the compiler already uses for data. Only G_ADD16_ABS is\never the immediate form (G_SUB16_ABS is non-commutative, so `g - 1` canonicalizes\nto `g + 0xFFFF`).\n\nA single `inc abs`/`dec abs` memory-RMW (1 instr) was prototyped and REVERTED as\nunsafe: the 65816 has no `inc long`, and `inc abs` is DBR-relative. This platform's\ncrt0 leaves DBR=0 and the compiler addresses all data via 24-bit long (DBR-\nindependent) loads/stores — `inc abs` would be the only construct relying on DBR==0.\nIt only happens to work today because the linker confines all writable data to LoRAM\n(0x0200-0x1FFF, link.ld), which the SNES mirrors into bank 0; a global above 0x1FFF,\na non-zero DBR, or a memory-map change would silently miscompile. The accumulator\ninc/dec keeps the long addressing, so it is correct under any DBR / memory map. A note\nin MOSInstrLogical.td records the rejection.\n\nNew a16incabs (3 inc a + 1 dec a on globals, corpus_result==0x3502): disasm gate\nasserts inc a (1a)/dec a (3a), no adc #$0001, and no DBR-relative inc abs (ee)/dec\nabs (ce). MAME + bsnes-jg agree. Full a16 suite (28 tests) + corpus 7/7 green;\n-verify-machineinstrs clean; patch 0002 round-trips.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
