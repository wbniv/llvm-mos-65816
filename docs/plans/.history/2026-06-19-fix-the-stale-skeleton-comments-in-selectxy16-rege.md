| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/c2882b3) | #321 xy16: fix the stale `// skeleton`/`returns false` comments on selectXY16 |

<!--history-meta v1
c2882b3	author	Will Norris
c2882b3	added	51
c2882b3	deleted	0
c2882b3	files	1
c2882b3	body	selectXY16 is fully implemented (C1 direct load/store/inc/dec/compare + C2 abs,X16 /\n(zp),Y16 indexed; legalizer B1 allUsesAreXY16Compatible + B2 Use16BitIdx feed it), but\nthree comments in MOSInstructionSelector.cpp still called it an unimplemented stub that\n"returns false for everything" — actively misleading (it nearly led to re-implementing\ndone work). The function header even carried BOTH the stale preamble AND an accurate\n"Handles: C1/C2" block. Corrected all three (declaration, dispatch gate, function header)\nto describe the real behavior.\n\nComment-only: dev/regen-patch.sh regenerated 0002 (round-trip PASS); git diff confirms\nONLY the 3 comment hunks, foreign-symbol count unchanged (legalizeICmp|NativeS16Eq=9),\nno codegen change, no toolchain rebuild needed.\n\n- patches/llvm-mos/0002-321-accum16.patch    regenerated (3 comment hunks only)\n- docs/plans/2026-06-19-fix-the-stale-skeleton-comments-in-selectxy16-rege.md   plan\n- TODO.md                                    Done entry\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
