| Date | Change |
|------|--------|
| [2026-06-13](https://github.com/wbniv/llvm-mos-65816/commit/2fb154f) | Initial commit: llvm-mos 65816 effort + SNES platform (M0) |

<!--history-meta v1
2fb154f	author	Will Norris
2fb154f	added	68
2fb154f	deleted	0
2fb154f	files	1
2fb154f	body	Standalone home for bringing an optimizing open-source C compiler to the WDC\n65816 via llvm-mos, with SNES as the first platform.\n\n- platforms/snes/: SNES LoROM SDK platform (crt0, header, link.ld, snes.h,\n  clang.cfg) — builds a valid bootable 32 KiB .sfc from C on the existing 6502\n  backend (65816 boots in emulation mode). PR material for llvm-mos-sdk#415.\n- dev/: containerized build env (Ubuntu 26.04 + pinned llvm-mos toolchain);\n  build.sh vendors upstream llvm-mos-sdk and injects our platform(s), run.sh\n  drives it from the host. Host stays clean.\n- examples/snes/hello.c, tools/snes-checksum.py.\n- docs/ROADMAP.md (M0 SNES bench -> M1 #320 far pointers -> M2 #321 16-bit regs),\n  docs/INVESTIGATION.md (upstream status + contribution rationale).\n\nVerified: dev/run.sh build produces a structurally valid bootable ROM\n(reset $FFFC -> _start, boot path is the crt0, main() compiled, checksum ok).
-->
