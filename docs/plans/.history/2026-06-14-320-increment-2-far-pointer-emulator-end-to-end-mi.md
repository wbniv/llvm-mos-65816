| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/a8dd8a5) | #320 Increment 2: far-pointer codegen executes in MAME (emulation mode) |

<!--history-meta v1
a8dd8a5	author	Will Norris
a8dd8a5	added	234
a8dd8a5	deleted	0
a8dd8a5	files	1
a8dd8a5	body	Prove the Increment-1 far-pointer codegen runs on emulated silicon, not just\ndisassembles. A -mcpu=mosw65816 program far-LOADs a ROM constant and far-STOREs\nthe result to WRAM; it boots headless in MAME on the existing single-bank,\nemulation-mode crt0 and the far-stored byte reads back 0xF3 (SMOKE: PASS).\nFirst real 65816 codegen executing end-to-end (ROADMAP step 3, execution half).\n\nRe-scope (research finding): absolute-long carries the full 24-bit address and\nignores the data bank register, so far accesses work in plain 6502-emulation\nmode. The TODO's "native-mode crt0 (XCE/DBR/reg widths)" is NOT required for far\npointers and moves to M2/#321; the multi-bank ROM far-read is split to a new\nIncrement 2b. Native mode / 16-bit registers only matter for #321.\n\n- examples/65816/far-run.c: far_src (const, ROM bank $00) ^ 0x5A -> corpus_result\n  (bss, WRAM). Far GLOBALS, 8-bit -> Increment-1 constant/global absolute-long\n  path; relocatable symbols stay absolute-long (never zero-bank-relaxed).\n- dev/far-run.sh + `dev/run.sh far-run`: compile -mcpu=mosw65816 --config\n  mos-snes.cfg, checksum, disasm gate (AF/8F + R_MOS_ADDR24), then run_assert via\n  the existing dev/_emu.sh + smoke.lua. No emulator/crt0/Lua changes.\n- WRAM $7E0xxx aliases low-RAM $000xxx, so the bank-$00 far store lands where the\n  harness samples ($7E0000 + VMA); no native mode / multi-bank needed.\n\nVerification (from-source toolchain, 2026-06-14): far-run 5/5 PASS\n(SMOKE: PASS got=0xF3 at $7E0200; disasm af/8f + ADDR24; negative control FAILs),\ncorpus still 7/7. ROADMAP step 3 + TODO re-scoped; native mode -> M2/#321.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
