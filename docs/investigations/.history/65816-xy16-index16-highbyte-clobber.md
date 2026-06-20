| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/4a7a46b) | #321 xy16 seed247/445 — root cause FOUND + verified; fix scoping doc (scope-first) |

<!--history-meta v1
4a7a46b	author	Will Norris
4a7a46b	added	157
4a7a46b	deleted	0
4a7a46b	files	1
4a7a46b	body	Reduced seed 445 (cvise, dev/reduce-xy16.sh) to an 8-line UB-free repro and root-caused\nthe +mos-xy16-only miscompile, verified twice on both emulators:\n\n  A 16-bit value (g_21, selected into the Xc16 index-register class) is left LIVE in X\n  across a `sep #$10` that MOSInsertREPSEP inserts for an unrelated 8-bit `ldy`. On the\n  65816, narrowing the shared index-width flag to 8-bit ZEROES XH/YH — destroying the\n  high byte. corpus_result: want 0x0002, got 0x0000 (g_21 itself: 0x0216 -> 0x0016).\n\nNOT the requiredXWidth tweak the plan assumed: XH/YH are modeled (MOSRegisterInfo.td:114)\nbut nothing models index-narrowing as clobbering them (SEP has no Defs; MOSInsertREPSEP is\npost-RA, its lattice is per-instruction). So regalloc kept a 16-bit index value live across\nan 8-bit-index op — impossible on hardware (X/Y share one width flag).\n\nPer the user's scope-first decision, NO codegen changed. docs/investigations/\n65816-xy16-index16-highbyte-clobber.md scopes three fixes and recommends approach A (a\npre-RA, HasIndex16-gated pass marking 8-bit-index ops as clobbering XH/YH so regalloc\nspills live 16-bit index values). Awaiting approval before implementing.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
