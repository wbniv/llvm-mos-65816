| Date | Change |
|------|--------|
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/a295256) | docs(plan): clean-room test of the published SNES compiler |

<!--history-meta v1
a295256	author	Will Norris
a295256	added	124
a295256	deleted	0
a295256	files	1
a295256	body	Plan to verify the indri.studio-published toolchain from a consumer's view: in a\nthrowaway Docker container, fetch the compiler from the public endpoints (apt\ninstall from apt.indri.studio and/or the product-page tarball), compile a\nsound-free reference Mandelbrot (examples/65816/k_mandel.c, gate CRC 0x820B),\nand run it on bsnes-jg — whose SPC700 IPL is embedded in-core, so the test needs\nNO copyrighted BIOS and the program touches no APU — asserting the on-console\nresult equals the host oracle (mandel-render --gate), for both default-8bit and\n+mos-a16. Rig image (dev/Dockerfile.release-test: bsnes-jg + jgxcheck + oracle,\nno toolchain baked) + dev/test-release.sh + task release-test; optional periodic\nCI release-smoke. The compiler is the unit under test; the repo fixtures are the\nrig. + TODO entry under Distribution / Packaging.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01WouKS6ftBcHbHYViCJvT1S
-->
