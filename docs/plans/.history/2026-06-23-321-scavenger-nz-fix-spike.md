| Date | Change |
|------|--------|
| [2026-06-23](https://github.com/wbniv/llvm-mos-65816/commit/538e7f2) | #321 scavenger N/Z: plan the fix spike (conservative canSaveScavengerRegister P gate) |

<!--history-meta v1
538e7f2	author	Will Norris
538e7f2	added	59
538e7f2	deleted	0
538e7f2	files	1
538e7f2	body	User asked to try a real fix despite the issue-only verdict — a tested patch is\nworth proposing even for shared scavenger code (maintainer reviews/refines).\nRoot cause confirmed deeper this spike: scavengeFrameVirtualRegs picks $p as\nscratch for a carry-class frame vreg, must spill P across an unbalanced range\nwhere N is live; canSaveScavengerRegister(P) checks pushPullBalanced but not\nN/Z liveness, green-lighting an illegal P spill. Hypothesis: add the N/Z check\nto the gate (conservative — can only miss a scavenge, never emit illegal code).\nSpike on wt/scavenger-nz; GO -> PR+fork patch+de-XFAIL, NO-GO -> keep issue-only.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
