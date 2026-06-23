| Date | Change |
|------|--------|
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/405c147) | #320 packed-24 residuals: measure-and-close Task B + Task C — thread CLOSED |

<!--history-meta v1
405c147	author	Will Norris
405c147	added	133
405c147	deleted	0
405c147	files	1
405c147	body	Disposes of the last two packed-24 productionization residuals; neither needs\npacked-24-specific codegen. Mirrors the zero-bank (AS4) measure-and-close.\n\n- Task B (byte-2 absolute-long access cost) = built as 0007. The cost is\n  general, not packed-specific — only the A-register byte 2 bloated to\n  absolute-long (8f/af); STX/STY have no long form so bytes 0,1 were already\n  abs. So it's the near-abs bank-relaxation (0007, MOSAsmBackend.cpp:\n  8f/af->8d/ad for ALL near pointers), whose plan is literally "the\n  realization of Task B" (-2 B on packed byte-2, verified 0001-0007 both\n  emulators). A packed-local fix would duplicate 0007's DBR=0 logic and risk a\n  DBR!=0 miscompile -> don't.\n- Task C (__far_packed ergonomic spelling) closed — precondition unmet: no AS2\n  spelling exists to mirror (far/dp/packed are all per-file local #defines, no\n  __far keyword / <mos.h> typedef / MOS address-space attribute), so building\n  one alone is the forbidden one-off. Revive only via a shared <mos.h> covering\n  all spaces (an SDK concern).\n\nTask A is already done + verified (realistic measurement: packed wins at every\nN, break-even N>=1; static-init reloc bug surfaced + fixed in 0006). With A/B/C\ndisposed the productionization thread is complete. Worktree wt/320-packed24-incB\ntorn down (f168003); all work on main.\n\nNew: docs/plans/2026-06-22-320-packed24-residuals-close.md (the close-out\nrecord + reproduced evidence). Updated: TODO.md M2 item (strike B+C, note\nthread closed + worktree teardown), the productionization handoff (stale\nbanner), the five-space plan (follow-ups resolved). No vendor/ or patch edits.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
