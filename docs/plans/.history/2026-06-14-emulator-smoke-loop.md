| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/982b6f3) | M0: implement headless MAME smoke loop (dev/run.sh smoke) |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/be5f443) | docs: plan M0 emulator smoke loop on MAME; add TODO |

<!--history-meta v1
982b6f3	author	Will Norris
982b6f3	added	88
982b6f3	deleted	39
982b6f3	files	1
982b6f3	body	Boots build/hello.sfc in MAME's snes driver headless and asserts the\nsentinel==0x42 byte in WRAM ($7E0020), closing the run-half of ROADMAP\nverification step 1. Same emulation core drmon debugs against.\n\n- dev/Dockerfile: add mame (own layer after the toolchain so a version\n  bump never re-downloads the toolchain); PATH += /usr/games (Debian\n  installs the binary there, off the default non-login PATH).\n- dev/smoke.lua: clean-room autoboot script (no GPL drmon code) — counts\n  frames, reads the WRAM byte via maincpu program space, prints SMOKE:\n  PASS/FAIL, exits. Verdict travels on stdout (MAME can't set exit code).\n- dev/smoke.sh: BIOS preflight (exit 2 if missing), derive sentinel addr\n  from hello.map, run MAME headless with -rompath/-skip_gameinfo, exit 0\n  iff SMOKE: PASS.\n- .github/workflows/smoke.yml: build + smoke; materializes the SPC700 IPL\n  from the SNES_SPC700_ROM_B64 secret, gates the smoke step on it.\n- .gitignore: /dev/roms/ — the SPC700 IPL is Nintendo content, supplied\n  out-of-band, never committed (mirrors drdevtools' roms/ pattern).\n\nVerification (2026-06-14): MAME 0.285; clean dev/run.sh smoke -> SMOKE:\nPASS exit 0; negative control (SMOKE_WANT=0x99) -> SMOKE: FAIL exit 1;\nmame -verifyroms snes -> "romset snes is good". CI (step 5) pending the\nrepo secret + push. Evidence pasted into the plan.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
be5f443	author	Will Norris
be5f443	added	161
be5f443	deleted	0
be5f443	files	1
be5f443	body	Settle the M0 emulator choice on MAME's snes driver so the CI smoke bench\nshares drdevtools drmon's emulation backend (green-in-CI == attachable-in-\ndrmon). Add docs/plans/2026-06-14-emulator-smoke-loop.md (clean-room Lua\nassert on sentinel==0x42 in WRAM, headless via -autoboot_script, GPL\nboundary respected — harness in dev/, not the Apache platforms/snes/),\ncreate TODO.md, and update ROADMAP step 1 + the M0 sub-step to MAME.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
