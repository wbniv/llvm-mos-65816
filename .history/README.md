| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/982b6f3) | M0: implement headless MAME smoke loop (dev/run.sh smoke) |
| [2026-06-13](https://github.com/wbniv/llvm-mos-65816/commit/2fb154f) | Initial commit: llvm-mos 65816 effort + SNES platform (M0) |

<!--history-meta v1
982b6f3	author	Will Norris
982b6f3	added	12
982b6f3	deleted	0
982b6f3	files	1
982b6f3	body	Boots build/hello.sfc in MAME's snes driver headless and asserts the\nsentinel==0x42 byte in WRAM ($7E0020), closing the run-half of ROADMAP\nverification step 1. Same emulation core drmon debugs against.\n\n- dev/Dockerfile: add mame (own layer after the toolchain so a version\n  bump never re-downloads the toolchain); PATH += /usr/games (Debian\n  installs the binary there, off the default non-login PATH).\n- dev/smoke.lua: clean-room autoboot script (no GPL drmon code) — counts\n  frames, reads the WRAM byte via maincpu program space, prints SMOKE:\n  PASS/FAIL, exits. Verdict travels on stdout (MAME can't set exit code).\n- dev/smoke.sh: BIOS preflight (exit 2 if missing), derive sentinel addr\n  from hello.map, run MAME headless with -rompath/-skip_gameinfo, exit 0\n  iff SMOKE: PASS.\n- .github/workflows/smoke.yml: build + smoke; materializes the SPC700 IPL\n  from the SNES_SPC700_ROM_B64 secret, gates the smoke step on it.\n- .gitignore: /dev/roms/ — the SPC700 IPL is Nintendo content, supplied\n  out-of-band, never committed (mirrors drdevtools' roms/ pattern).\n\nVerification (2026-06-14): MAME 0.285; clean dev/run.sh smoke -> SMOKE:\nPASS exit 0; negative control (SMOKE_WANT=0x99) -> SMOKE: FAIL exit 1;\nmame -verifyroms snes -> "romset snes is good". CI (step 5) pending the\nrepo secret + push. Evidence pasted into the plan.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
2fb154f	author	Will Norris
2fb154f	added	68
2fb154f	deleted	0
2fb154f	files	1
2fb154f	body	Standalone home for bringing an optimizing open-source C compiler to the WDC\n65816 via llvm-mos, with SNES as the first platform.\n\n- platforms/snes/: SNES LoROM SDK platform (crt0, header, link.ld, snes.h,\n  clang.cfg) — builds a valid bootable 32 KiB .sfc from C on the existing 6502\n  backend (65816 boots in emulation mode). PR material for llvm-mos-sdk#415.\n- dev/: containerized build env (Ubuntu 26.04 + pinned llvm-mos toolchain);\n  build.sh vendors upstream llvm-mos-sdk and injects our platform(s), run.sh\n  drives it from the host. Host stays clean.\n- examples/snes/hello.c, tools/snes-checksum.py.\n- docs/ROADMAP.md (M0 SNES bench -> M1 #320 far pointers -> M2 #321 16-bit regs),\n  docs/INVESTIGATION.md (upstream status + contribution rationale).\n\nVerified: dev/run.sh build produces a structurally valid bootable ROM\n(reset $FFFC -> _start, boot path is the crt0, main() compiled, checksum ok).
-->
