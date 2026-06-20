| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/4d148dd) | #321 xy16: A' (pre-RA XH/YH clobber) implemented + REFUTED — wrong phase |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/8de0bd9) | #321 xy16: log native-16bit upstream entry; record approach-A phase-ordering wrinkle |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/4a7a46b) | #321 xy16 seed247/445 — root cause FOUND + verified; fix scoping doc (scope-first) |

<!--history-meta v1
4d148dd	author	Will Norris
4d148dd	added	40
4d148dd	deleted	1
4d148dd	files	1
4d148dd	body	Built the conservative pre-RA clobber pass (MOSIndexWidthClobber, HasIndex16-gated).\nIt does NOT fix the bug:\n 1. XH/YH are "not directly addressable" (MOSRegisterInfo.td:112) — implicit dead-defs\n    don't create RA interference, so the allocator doesn't spill the live Xc16 value.\n 2. Wrong phase: the buggy interleaving (g_21 in X across the 8-bit ldy) is created by\n    the machine scheduler + allocator that run AFTER the pass; at pass time the schedule\n    is still the good one (Xc16 immediately spilled to Imag16).\n 3. Clobbering full X16/Y16 (which ARE tracked) double-defs ops that define X/Y (ldy).\nAlso crashed on PHIs (loops, e.g. transparent_crc).\n\nPass unhooked; toolchain restored (seeds compile, minimal deterministic 0x0000); nothing\nlanded in 0002. Revised path: C (post-RA repair in MOSInsertREPSEP, where the conflict is\nvisible) or a scheduler/liveness constraint. Awaiting steer.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
8de0bd9	author	Will Norris
8de0bd9	added	39
8de0bd9	deleted	7
8de0bd9	files	1
8de0bd9	body	- upstream-contribution-status.md (Future/blocked): native-65816 16-bit codegen + the\n  index-width register model is M2 upstream material; the XH/YH clobber-on-narrowing\n  invariant must be carried into it (not bolted on as an xy16 special case).\n- investigation doc: implementing A revealed a phase-ordering wrinkle — the op that\n  triggers the high-byte clobber (a plain `load i8`) only becomes an 8-bit-index LDY\n  *after* register allocation, so a pre-RA "mark XW_X8 ops" pass can't precisely target\n  it. Refines the fix to A' (conservative reg-class clobber, leverages allocator spilling,\n  measurable over-spill) vs C (post-RA precise spill repair). Recommend A'; awaiting steer.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
4a7a46b	author	Will Norris
4a7a46b	added	157
4a7a46b	deleted	0
4a7a46b	files	1
4a7a46b	body	Reduced seed 445 (cvise, dev/reduce-xy16.sh) to an 8-line UB-free repro and root-caused\nthe +mos-xy16-only miscompile, verified twice on both emulators:\n\n  A 16-bit value (g_21, selected into the Xc16 index-register class) is left LIVE in X\n  across a `sep #$10` that MOSInsertREPSEP inserts for an unrelated 8-bit `ldy`. On the\n  65816, narrowing the shared index-width flag to 8-bit ZEROES XH/YH — destroying the\n  high byte. corpus_result: want 0x0002, got 0x0000 (g_21 itself: 0x0216 -> 0x0016).\n\nNOT the requiredXWidth tweak the plan assumed: XH/YH are modeled (MOSRegisterInfo.td:114)\nbut nothing models index-narrowing as clobbering them (SEP has no Defs; MOSInsertREPSEP is\npost-RA, its lattice is per-instruction). So regalloc kept a 16-bit index value live across\nan 8-bit-index op — impossible on hardware (X/Y share one width flag).\n\nPer the user's scope-first decision, NO codegen changed. docs/investigations/\n65816-xy16-index16-highbyte-clobber.md scopes three fixes and recommends approach A (a\npre-RA, HasIndex16-gated pass marking 8-bit-index ops as clobbering XH/YH so regalloc\nspills live 16-bit index values). Awaiting approval before implementing.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
