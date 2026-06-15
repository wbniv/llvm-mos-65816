| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/cbfdefa) | bench: second-emulator fidelity cross-check via bsnes-jg (ROADMAP step 3) |

<!--history-meta v1
cbfdefa	author	Will Norris
cbfdefa	added	135
cbfdefa	deleted	0
cbfdefa	files	1
cbfdefa	body	Add an independent-emulator cross-check so the Increment-2b bank-$01 far read\n(`lda $018000`) is confirmed by a second emulator, not just MAME — closing\nROADMAP step 3's "both emulators" gate.\n\nbsnes-jg (cycle-accurate fork of bsnes) is the second emulator. Its C++ API\nexposes WRAM directly (Bsnes::getMemoryRaw(MainRAM)), so a small headless\nharness (dev/jgxcheck.cpp) reads corpus_result exactly like MAME's Lua read —\nno SDL, no X, no save-state parsing. The bsnes-jg core links without SDL or\njg.h, so it runs headless on the 26.04 base. dev/xcheck.sh fetches pinned\nbsnes-jg 2.1.0, builds the core + harness (cached), builds-if-missing the far\nROMs, and asserts each against MAME's expected value (offset from the .map via\nthe reused dev/_emu.sh _emu_map_lookup). New `dev/run.sh xcheck` target;\nDockerfile gains pkg-config + libsamplerate0-dev.\n\nMesen2 abandoned: its prebuilt aborts with `free(): invalid pointer` on the\n26.04 glibc-2.43 base (confirmed with the full dep set under xvfb — an ABI\nincompatibility, not a missing dep), and on 24.04 its headless --testrunner\nwon't execute the Lua script. Recorded in the plan's Pivot section so it isn't\nre-explored.\n\nVerification (2026-06-14): dev/run.sh xcheck -> hello 0x42, far-run (bank $00)\n0xF3, far-bank1 (bank $01) 0xF3 on bsnes-jg, all matching MAME; negative\ncontrol FAILs. MAME path structurally untouched (only an additive Dockerfile\nlayer + a new target).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
