| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/025be2f) | M0: add clean-room repro gate; park CI to manual-only |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/18189b6) | docs: record M0 emulator-run PASS (MAME smoke) in ROADMAP + README |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/982b6f3) | M0: implement headless MAME smoke loop (dev/run.sh smoke) |
| [2026-06-13](https://github.com/wbniv/llvm-mos-65816/commit/2fb154f) | Initial commit: llvm-mos 65816 effort + SNES platform (M0) |

<!--history-meta v1
025be2f	author	Will Norris
025be2f	added	8
025be2f	deleted	1
025be2f	files	1
025be2f	body	For a solo private repo, the routine reproducibility gate is local, not\nGitHub minutes + a per-push ROM upload. CI's unique value (from-scratch\nreproducibility) isn't GitHub-specific — it's "fresh checkout, no machine\nstate", which a local script delivers.\n\n- dev/repro.sh (host-side): git archive HEAD -> temp dir (committed files\n  only, no build/ or caches), supply the gitignored SPC700 IPL, then\n  run.sh build + run.sh smoke there. Proven green: "repro OK".\n- dev/run.sh: route `repro` host-side (not an in-container target).\n- .github/workflows/smoke.yml: triggers -> workflow_dispatch only. Proven\n  green once on a clean GH runner (run 27475012894, smoke step executed\n  with BIOS from secret); re-enable push/pull_request when public/upstream\n  or collaborators arrive.\n- README/plan: document repro + the manual-CI decision. Plan verification\n  step 5 (reproducible from clean checkout) -> PASS (both CI + local).\n- TODO: smoke loop -> Done (all 5 steps green); section structure refresh.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
18189b6	author	Will Norris
18189b6	added	4
18189b6	deleted	1
18189b6	files	1
18189b6	body	The smoke loop is implemented and green locally, so the docs that still\ndescribed the emulator-run half as "pending" are now stale.\n\n- ROADMAP step 1: Emulator-run half PASS (2026-06-14, MAME 0.285) with the\n  SMOKE: PASS + negative-control evidence; only the CI run remains (BIOS\n  secret). Cross-links the smoke loop plan.\n- README Status: "And it runs" — dev/run.sh smoke boots the ROM in MAME and\n  reads sentinel==0x42 back from WRAM.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
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
