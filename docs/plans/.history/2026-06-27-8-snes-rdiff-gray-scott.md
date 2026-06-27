| Date | Change |
|------|--------|
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/3fcbb63) | feat(snes): #8 Gray-Scott reaction-diffusion demo (examples/snes/rdiff.c) |

<!--history-meta v1
3fcbb63	author	Will Norris
3fcbb63	added	260
3fcbb63	deleted	0
3fcbb63	files	1
3fcbb63	body	Algorithm header examples/65816/rdiff.h: gs_step() hot loop with ≥4 __mulsi3\nper cell (u*v and uv*v reaction terms + DU*laplacian, DV*laplacian diffusion),\nand rdiff_gate_crc() cumulative rotating-XOR CRC over GS_GATE_STEPS=50 steps\non an 8×8 sub-grid (captures the full transient, not just the final state).\n\nParameters: DU=102/DV=10 (ratio ≈10 triggers Turing instability on the discrete\ngrid), F=14, K=16 — produces five expanding wave-fronts that merge into Turing\nstripes visible over ~150 frames at 2 steps/frame.\n\nSNES ROM: BG1 4bpp, 16 solid-colour tiles (navy→white palette), half-tilemap DMA\nalternating top/bottom halves (896 bytes each, < 1536 B V-blank budget). Five 2×2\nseed spots in gs_init(); double-buffered simulation grids (4 × 896 int16_t = 7 KB).\n\nGate: host oracle prints 0x6969; corpus slice added to expected.tsv.\nGate script dev/rdiff.sh: host oracle → ROM build → disasm (__mulsi3≥2, rep/sep≥1)\n→ bsnes-jg → MAME under Xvfb. 5-way bar (no far pointers; all grids in bank-0 WRAM).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
