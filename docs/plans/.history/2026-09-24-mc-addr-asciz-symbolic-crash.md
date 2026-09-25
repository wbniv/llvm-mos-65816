| Date | Change |
|------|--------|
| [2026-09-24](https://github.com/wbniv/llvm-mos-65816/commit/6eced8e4) | fix(mc): stop llvm-mc -show-encoding crashing on a symbolic .mos_addr_asciz |

<!--history-meta v1
6eced8e4	author	Will Norris
6eced8e4	added	228
6eced8e4	deleted	0
6eced8e4	files	1
6eced8e4	body	MCStreamer::emitValue's generic fallback can only print an unresolved\nsymbolic value at a power-of-two size (1/2/4/8 bytes); .mos_addr_asciz's\nCharCount+1 width ranges [2,9], so 5 of 8 widths hit "Don't know how to\nemit this value." Fixed by round-tripping the directive as raw text via\nemitRawText when hasRawTextSupport() is true (the same discriminator\nHexagon's AsmParser already uses for this), leaving object-file emission\nuntouched. Also: VK_ADDR_ASCIZ had no textual modifier spelling\n(MOSModifierNames.cpp returned nullptr for it), and evaluateAsInt64's\nVK_ADDR_ASCIZ case was llvm_unreachable -- live UB in a no-asserts build,\nnot dead code (confirmed: it silently produced garbage bytes pre-fix\nrather than crashing). Both fixed alongside the crash. Patch 0047,\npristine-upstream, not 24-bit-specific -- found incidentally during the\n2026-09-24 #320 completeness audit.\n\nVerified: dev/run.sh lit 159 tests, same 4 known-failing baseline,\naddr-asciz.s (with a new -show-encoding RUN line) passes; --filetype=obj\npath byte-identical before/after; manual pristine-worktree patch\nround-trip (0039+0047 apply cleanly, all 4 touched files identical to\nlive vendor/).\n\nTODO.md merged by hand from a stale agent snapshot: the fixing agent's\nworking copy predated both the roundtrip-gate agent's Done-transition\ncommit and this session's far-codegen-lit wip stamp, so a plain commit\nwould have silently reverted them. Rebuilt from HEAD + only this agent's\nintended delta (its own Open removal + Done addition) plus restoring the\nfar-codegen-lit stamp the roundtrip-gate agent's own stale-based merge\nhad already dropped.\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_017sAprvTwtKFJHKgQmr1qgr
-->
