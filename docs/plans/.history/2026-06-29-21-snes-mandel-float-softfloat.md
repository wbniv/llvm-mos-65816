| Date | Change |
|------|--------|
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/cd3663a) | feat(snes): #21 Soft-Float Mandelbrot — IEEE-754 single-precision escape-time / soft-float libcall stress demo |

<!--history-meta v1
cd3663a	author	Will Norris
cd3663a	added	170
cd3663a	deleted	0
cd3663a	files	1
cd3663a	body	First Round-2 (new-codegen-corner) demo of the compiler stress-test battery. Renders the\nMandelbrot set in IEEE-754 single-precision float, so on the FPU-less 65816 every op is a\nsoft-float libcall (__mulsf3/__addsf3/__subsf3/__divsf3/__gtsf2/__floatsisf) — the library\nno Round-1 demo touches.\n\nBit-exact differential: single precision is fully specified (correctly-rounded), so host\nx86 single == target soft-float bit-for-bit. FMA contraction (the one divergence risk) is\nforbidden by construction — every op is its own statement, no a*b±c to fuse. Verified\nhost == default-8bit == +mos-a16 == +mos-xy16 == 0x4169 on bsnes-jg; disasm __mulsf3=8,\n__add/subsf3=12, rep/sep=35. No compiler bug found — soft-float codegen is correct in all\nmodes. 16x14 grid 4x-upscaled into the $7E2000 far framebuffer, Mode-7 zoom, progressive\nboot-paint. Published biohack.net/snes/mandel-float/.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
