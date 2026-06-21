| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/6efabde) | #320 (a) far fn pointers fully done — sync status docs (impl-status, ROADMAP, README, plans) |

<!--history-meta v1
6efabde	author	Will Norris
6efabde	added	200
6efabde	deleted	0
6efabde	files	1
6efabde	body	Bring the tracking docs current now that #320 (a) far function pointers is fully\nclosed (backend + clang F2 `far`/`long_call` attribute + typed `far_fn_t`\nvariable + sizeof(far*)==4, + a pre-existing far_indir crash fix; verified both\nemulators, pushed origin/wt/320-far-followups):\n\n- implementation-status.md: TL;DR, the far-fn-ptr table row, the M1 verdict, the\n  pending-codegen row, and What's-next #2 all flipped from "BACKEND DONE / only\n  F2 remains" to DONE.\n- ROADMAP.md: mixed-banking + far function pointers marked DONE; only the\n  far-pointer calling convention (0004) remains.\n- README.md: M1 far-pointers line updated (was "far calls deferred pending ABI\n  blessing" — stale; far calls + far fn pointers are done).\n- 2026-06-21-320-far-calls-followups.md: §7 resume + §9 commit trail updated;\n  struck the §0 historical "ONLY remaining piece is F2".\n- Co-located the typed-far_fn_t-variable + far-pointer-sizeof plans on main (they\n  were committed on wt/320-far-followups) so the status-doc cross-links resolve.\n\nAdversarial staleness audit (3-agent workflow) drove these fixes — final grep\nclean, all plan links resolve.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
