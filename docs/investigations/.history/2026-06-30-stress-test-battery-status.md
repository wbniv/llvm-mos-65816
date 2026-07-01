| Date | Change |
|------|--------|
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/dd357cc) | fix(snesgfx): TITLE_RBUF_COLS guard + rdiff compact-struct fallback |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/66271bb) | docs(battery): add stress-test battery completion status report |

<!--history-meta v1
dd357cc	author	Will Norris
dd357cc	added	1
dd357cc	deleted	1
dd357cc	files	1
dd357cc	body	rdiff BSS is at capacity (7424/7680 B); the 64-word rbufs in TitleLayer\noverflowed it by 161 bytes. Add TITLE_RBUF_COLS (default TITLE_COLS*2=64)\nso tight-RAM demos can override to TITLE_COLS=32 before the include, getting\nthe compact 8×8-only row buffers. rdiff adds the override and reverts to\ntitle_begin (8×8); gate PASS 0x5555.\n\nAlso add docs/plans/2026-06-30-title-screen-upgrade.md — end-to-end record\nof the 16×16 rollout across all 35 demos.\n\nCo-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
66271bb	author	Will Norris
66271bb	added	80
66271bb	deleted	0
66271bb	files	1
66271bb	body	All 32 demos shipped + gate-verified + published. Consolidates the\ncompiler-correctness verdict (all corners green, bugs found were pre-existing\nand fixed in-flight), the Round-2 coverage table with gate CRCs, and the\n#25-FFT display-vs-codegen distinction. Linked from the demo-ideas tracker.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
