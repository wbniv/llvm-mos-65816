| Date | Change |
|------|--------|
| [2026-09-25](https://github.com/wbniv/llvm-mos-65816/commit/94d1e434) | todo: [far-scalar-split-measure] done (GO, gated); queue Phase 2 + near A:X store regression (unranked) |
| [2026-09-25](https://github.com/wbniv/llvm-mos-65816/commit/c1ebadd5) | docs(321): far 16-bit scalar byte-split Phase 1 measurement — GO (gated) |

<!--history-meta v1
94d1e434	author	Will Norris
94d1e434	added	193
94d1e434	deleted	2
94d1e434	files	1
94d1e434	body	Phase 1 of the far 16-bit scalar byte-split: root cause is legalizeLoadStore16's\n16-bit-pointer-only native arm plus the missing Ac16 long pseudos. Adds the\nunranked Phase 2 item (suggested T4) and a separate near-path finding: under\n+mos-a16 a setter `g = v` is 14 B vs 7 B by default (suggested T3). The doc gets\nthe raw verification record and drops a stale -save-temps caveat (0044 landed).\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_017sAprvTwtKFJHKgQmr1qgr
c1ebadd5	author	Will Norris
c1ebadd5	added	303
c1ebadd5	deleted	0
c1ebadd5	files	1
c1ebadd5	body	Root cause: legalizeLoadStore16 builds its native s16 arms only for a 16-bit\npointer; a p2 (far) pointer falls to narrowScalar(s8) and no Ac16 long pseudo\nexists. Census: 0 far-global i16 accesses, 11 i16 loads + 2 stores through\nruntime far pointers; 3 load sites (the far-source VRAM upload idiom) win.\nWin where the value has a 16-bit consumer: -10..-30 B on far globals, -14 B /\n-28 cy/iter on a far pointer walk (both scheduler modes). Loss vectors ungated:\nA:X return +3 B, A:X store +5 B. Bank seam: a single M=0 access carries into\nthe next bank exactly like the byte split (bsnes-jg + MAME probe).\n\nNo compiler change. Adds dev/measure-far-scalar-split.sh + dev/far-scalar-split/.\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_017sAprvTwtKFJHKgQmr1qgr
-->
