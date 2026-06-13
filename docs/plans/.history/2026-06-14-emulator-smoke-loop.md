| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/be5f443) | docs: plan M0 emulator smoke loop on MAME; add TODO |

<!--history-meta v1
be5f443	author	Will Norris
be5f443	added	161
be5f443	deleted	0
be5f443	files	1
be5f443	body	Settle the M0 emulator choice on MAME's snes driver so the CI smoke bench\nshares drdevtools drmon's emulation backend (green-in-CI == attachable-in-\ndrmon). Add docs/plans/2026-06-14-emulator-smoke-loop.md (clean-room Lua\nassert on sentinel==0x42 in WRAM, headless via -autoboot_script, GPL\nboundary respected — harness in dev/, not the Apache platforms/snes/),\ncreate TODO.md, and update ROADMAP step 1 + the M0 sub-step to MAME.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
