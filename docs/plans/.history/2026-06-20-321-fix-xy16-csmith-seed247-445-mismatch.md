| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/f29639c) | #321 xy16 fix plan: record Phase-1 root-cause findings (not yet isolated) |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/62aa64f) | #321 xy16: write fix plan for the Csmith seed 247/445 mismatches |

<!--history-meta v1
f29639c	author	Will Norris
f29639c	added	23
f29639c	deleted	0
f29639c	files	1
f29639c	body	Attempted root-cause of the seed 247/445 xy16 mismatches; checkpointing at the\n3-hypothesis debugging cap:\n- pulled main's MIR after mos-insert-rep-sep from the REAL LTO link (the\n  whole-module replay crashes on __adddf3 s64 under +mos-xy16);\n- linear X-width trace inconclusive — the only genuine X=16 region is the\n  crc32_tab fill loop; all 8-bit-index ops are correctly at X=8. Points away\n  from a flat requiredXWidth gap (H1) toward a CFG/loop-edge subtlety (H2) or\n  an unzeroed 16-bit-index high byte;\n- NEGATIVE: a minimal tab[1024] 16-bit-index fill+sum repro PASSES (all agree),\n  so plain 16-bit table indexing is correct — the bug needs the specific\n  seed-445 shape (delta-reduction is the reliable next step).\n\nNo code change. Throwaway probe removed (passed, not a useful guard).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
62aa64f	author	Will Norris
62aa64f	added	103
62aa64f	deleted	0
62aa64f	files	1
62aa64f	body	Plan to fix the two +mos-xy16-only runtime miscompiles (a16/default/bsnes all\nagree). Grounded in seed-445 LTO disasm: main brackets index ops (cpx/cpy/inx/\ndex, lda/sta abs,x/,y) with X-width rep/sep, so the divergence is an index op\nin the wrong X width — the requiredXWidth/MOSInsertREPSEP X-lattice class, same\nfamily as 55ec505. Plan: reproduce both seeds, root-cause via MIR after\nmos-insert-rep-sep, fix requiredXWidth/selectXY16 (HasIndex16-gated), guard with\nboth seeds + a 16-bit-index micro-test (LTO-narrowing caveat noted). Execute on\nwt/321-xy16; a16/default untouched.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
