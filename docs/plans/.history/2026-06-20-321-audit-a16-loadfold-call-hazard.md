| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/e4772aa) | #321 audit: promote the load-fold-hazard audit to a standalone plan doc |

<!--history-meta v1
e4772aa	author	Will Norris
e4772aa	added	75
e4772aa	deleted	0
e4772aa	files	1
e4772aa	body	Move the audit findings (table of every a16 fold site + its guard, and the\nrationale for not consolidating onto shouldFoldMemAccess due to its volatile\nbail) into a first-class plan:\n  docs/plans/2026-06-20-321-audit-a16-loadfold-call-hazard.md\n\nDe-duplicate the section previously appended to the fix plan (now a pointer),\nand link both fix + audit plans from the TODO done entry. Doc-only; conclusion\nunchanged: the two helpers fixed in 86c2602 were the only vulnerable sites, the\nbug class is closed, no code change.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
