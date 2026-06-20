| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/7c773da) | #321 xy16 fix plan: record 10-agent root-cause workflow result (synthesis refuted 3/3) |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/f29639c) | #321 xy16 fix plan: record Phase-1 root-cause findings (not yet isolated) |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/62aa64f) | #321 xy16: write fix plan for the Csmith seed 247/445 mismatches |

<!--history-meta v1
7c773da	author	Will Norris
7c773da	added	78
7c773da	deleted	40
7c773da	files	1
7c773da	body	Multi-agent static analysis (wf_826f3a8e-bff, 6 angles + synthesis + 3\nadversarial verifiers, a16 as oracle) reached a firm conclusion: the seed\n247/445 miscompile is NOT a static X-width bug.\n\n- Both seeds' codegen is X-width-correct AND value-correct at every indexed op\n  (4/6 angles "no defect"): every 8-bit-indexed block is X8-pinned by an\n  adjacent classified op; the genuine X=16 crc32_tab bf/9f long,X access is\n  correct, index in-range, bank 0.\n- The requiredXWidth 8-bit-indexed family gap (LDAAbsIdx/ST*Idx/*IndirIdx/\n  ALU-Idx -> XW_None) is a REAL latent defect — but does NOT fire in 247/445\n  (verified 3/3). Land it as hardening (Track A), not as this bug's fix.\n- The real cause is runtime (value bug in the long,X X=16 path, or a MAME\n  long,X-under-X16 behavior). Decisive next test: run xy16@bsnes-jg on both\n  seeds (the original differential never did) -> agrees = MAME artifact;\n  diverges = real bug -> fill-vs-read bisection.\n\nPlan restructured into Track A (hardening, ready) + Track B (runtime bisection,\nbsnes disambiguation first). TODO updated.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
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
