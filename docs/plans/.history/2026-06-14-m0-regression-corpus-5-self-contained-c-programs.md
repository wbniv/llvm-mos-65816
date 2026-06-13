| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/c50a39c) | M0: regression corpus (6 programs) + generalized harness |

<!--history-meta v1
c50a39c	author	Will Norris
c50a39c	added	132
c50a39c	deleted	0
c50a39c	files	1
c50a39c	body	ROADMAP step 2. Turns the one-program liveness bench into a correctness\nbaseline: 6 self-contained C programs each compute a result the host checks\nagainst a manifest, exercising a distinct slice of codegen. This is the\nregression net for when M1/M2 rewrite codegen — same source, same bytes.\n\n- examples/snes/corpus/{arith,control,arrays,structs,funcs,globals}.c — ALU,\n  control flow, arrays+.rodata, structs+pointers, calls+recursion, and the\n  crt0 .data/.bss init. Inputs are volatile to defeat -Os constant-folding;\n  each writes volatile uint16_t corpus_result. expected.tsv is the manifest.\n- dev/_emu.sh: shared run_assert — derives a symbol's WRAM address AND byte\n  length from the linker map (Size column), boots MAME headless, asserts.\n- dev/smoke.lua: SMOKE_LEN — read N bytes little-endian (default 1).\n- dev/smoke.sh: refactored onto _emu.sh (identical behavior).\n- dev/corpus.sh + run.sh `corpus` target: assert every manifest row, N/N table.\n- dev/build.sh: build every examples/snes/**/*.c, not just hello.\n- dev/run.sh: forward SMOKE_WANT/SMOKE_SETTLE/SNES_ROMPATH into the container\n  (so the documented overrides + negative control work via the entrypoint).\n- repro.sh + smoke.yml: run corpus (subsumes the hello liveness row).\n\nVerification (2026-06-14): dev/run.sh corpus -> 7/7 PASS\n(arith 0xA9E9, control 0x1DFB, arrays 0x03E1, structs 0x0340, funcs 0x011E,\nglobals 0xAB55, hello 0x42 — every hand-computed expected matched). Negative\ncontrol (corrupt one expected) -> that row FAIL, 6/7, exit 1. repro + CI below.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
