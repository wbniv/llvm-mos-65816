| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/43f1d84) | #320 far-pointer integration plan — land 0004 + fold (a) recipes into 0001 |

<!--history-meta v1
43f1d84	author	Will Norris
43f1d84	added	69
43f1d84	deleted	0
43f1d84	files	1
43f1d84	body	Plan for the capstone integration the user opted into: express the entire #320\nfar-pointer line (currently gitignored vendor/ recipes on wt/320-far-followups)\nas source-of-truth patches on main —\n\n- the far function pointer (a) sub-project (backend Layers 1-3 + Gap A/B + the\n  __call_indir_far mechanism + clang F2 `far` attribute + typed far_fn_t variable\n  + sizeof(far*)==4 + the isFarSymbol far_indir fix) folded into 0001 (a16-free);\n- the far-pointer calling-convention winner (Imag32) landed as 0004.\n\nKey state discovered: NONE of the (a) work is in main's 0001 (0 hits for\nisFarSymbol/__call_indir_far/MOSFarCall); it's all on wt/320-far-followups, whose\n0001/0002 are byte-identical to main's, with 0003+0004 stacked + the (a) recipes\n-- and that combined tree was built + ran the whole far suite (12 ROMs) + corpus\n7/7 + csmith 0-mismatch green this session. So the integration is round-trip-\nverified PATCH SURGERY (reproduce that verified vendor/ as patches), not a\nrebuild. 0004 already apply-checks clean on main's base + re-verified (Imag32\nwins, 70 B/50441). Full mechanism + verification bar + risks in the plan.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
