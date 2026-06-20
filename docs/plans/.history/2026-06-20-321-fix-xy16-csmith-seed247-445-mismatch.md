| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/62aa64f) | #321 xy16: write fix plan for the Csmith seed 247/445 mismatches |

<!--history-meta v1
62aa64f	author	Will Norris
62aa64f	added	103
62aa64f	deleted	0
62aa64f	files	1
62aa64f	body	Plan to fix the two +mos-xy16-only runtime miscompiles (a16/default/bsnes all\nagree). Grounded in seed-445 LTO disasm: main brackets index ops (cpx/cpy/inx/\ndex, lda/sta abs,x/,y) with X-width rep/sep, so the divergence is an index op\nin the wrong X width — the requiredXWidth/MOSInsertREPSEP X-lattice class, same\nfamily as 55ec505. Plan: reproduce both seeds, root-cause via MIR after\nmos-insert-rep-sep, fix requiredXWidth/selectXY16 (HasIndex16-gated), guard with\nboth seeds + a 16-bit-index micro-test (LTO-narrowing caveat noted). Execute on\nwt/321-xy16; a16/default untouched.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
