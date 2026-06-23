| Date | Change |
|------|--------|
| [2026-06-23](https://github.com/wbniv/llvm-mos-65816/commit/906b7c5) | #321 scavenger N/Z fix spike: NO-GO — conservative gate dead-ends; issue stays issue-only (now better-evidenced) |
| [2026-06-23](https://github.com/wbniv/llvm-mos-65816/commit/538e7f2) | #321 scavenger N/Z: plan the fix spike (conservative canSaveScavengerRegister P gate) |

<!--history-meta v1
906b7c5	author	Will Norris
906b7c5	added	42
906b7c5	deleted	3
906b7c5	files	1
906b7c5	body	Tried the safest local fix (gate canSaveScavengerRegister(P) on N/Z-dead too).\nResult: the illegal `STImag8 $p` goes away but the scavenger then falls through\nto report_fatal_error("Scavenger spill for register not yet implemented") on a\nnameless flag/carry-class pseudo — at the failing site EVERY candidate the\nscavenger can pick is unsaveable. So the fix can't live in the gate; it needs a\ncore MOS change (flag-preserving P save across an unbalanced range, or changing\nhow the %N.subcarry vreg comes to need frame-scavenging in a flag-live context)\n— the regression-sensitive shared-scavenger territory the 2026-06-19 verdict\nnamed. Spike CONFIRMS that verdict with a concrete tested negative.\n\n- plan: full root cause (scavenger trace), step-1 FAIL, NO-GO outcome.\n- scavenger issue draft: added "a tested approach that does not work" so the\n  maintainer can skip the dead-end gate; offer the -debug-only trace.\n- TODO: triaged the auto-captured [verify] Inbox bullet (verification IS\n  recorded — it's a NO-GO, not pending).\n- in-worktree gate edit NOT landed (doesn't fix it); wt/scavenger-nz = dead-end\n  spike, torn down next. 8 fuzz seeds stay XFAIL'd + XPASS-guarded, unchanged.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
538e7f2	author	Will Norris
538e7f2	added	59
538e7f2	deleted	0
538e7f2	files	1
538e7f2	body	User asked to try a real fix despite the issue-only verdict — a tested patch is\nworth proposing even for shared scavenger code (maintainer reviews/refines).\nRoot cause confirmed deeper this spike: scavengeFrameVirtualRegs picks $p as\nscratch for a carry-class frame vreg, must spill P across an unbalanced range\nwhere N is live; canSaveScavengerRegister(P) checks pushPullBalanced but not\nN/Z liveness, green-lighting an illegal P spill. Hypothesis: add the N/Z check\nto the gate (conservative — can only miss a scavenge, never emit illegal code).\nSpike on wt/scavenger-nz; GO -> PR+fork patch+de-XFAIL, NO-GO -> keep issue-only.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
