| Date | Change |
|------|--------|
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/238de65) | plan: pr15296 +mos-a16 link-time ZP overflow — gated narrow-fix spike |

<!--history-meta v1
238de65	author	Will Norris
238de65	added	170
238de65	deleted	0
238de65	files	1
238de65	body	Plan-first contract for the gated spike: attempt to clear the lone remaining\n+mos-a16 register-pressure XFAIL (a16-zp-pressure-overflow / pr15296) with a\nnarrow fix, not the deferred high-risk RA rework. Research reframed the root\ncause — the allocator has a hard 224-byte ZP cap (pristine-upstream\nMOSZeroPageAlloc.cpp), so the 1043-byte overflow is a containable accounting\ndefect, likely a generic upstream-worthy bug. Diagnose-then-gate; land only if\ndefault-8bit byte-identical + regression-clean, else re-affirm the deferral.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011tDRoGK3T4gSGAHGBXk88B
-->
