| Date | Change |
|------|--------|
| [2026-06-17](https://github.com/wbniv/llvm-mos-65816/commit/bf5271f) | #321 soft-stack P2: hermetic .ll crash-regression for the soft-stack Ac16 spill |

<!--history-meta v1
bf5271f	author	Will Norris
bf5271f	added	114
bf5271f	deleted	0
bf5271f	files	1
bf5271f	body	Adds a drift-immune companion to the runtime test examples/65816/a16spillr.c +\ndev/a16spillr.sh. That C test guards the F3 soft-stack Ac16-spill bug end-to-end\nbut only as long as the front end + optimizer keep (a) the recursion (-> soft\nstack) and (b) a 16-bit value resident in Ac16 across the recursive call. P2 pins\nthat IR so the regression survives front-end/optimizer drift -- only the backend\ncodegen path under test can change it.\n\n- examples/65816/a16spillir.ll: the frozen LLVM IR of a16spillr.c (emit-llvm\n  +mos-a16 -Os; +mos-a16 pinned in the function attributes), with a header\n  documenting what/why/how-to-regenerate.\n- dev/a16spillir.sh: drives build-tree llc (pure codegen; llc isn't in the install\n  dir) as a compile-time gate -- (1) -verify-machineinstrs clean (was the\n  "SelectImm $a16" segfault), (2) STStk/LDStk $a16 still present so the soft-stack\n  Ac16 spill path is actually exercised (mirrors a16spillr.sh's MIR gate). No\n  emulator.\n- dev/run.sh: usage entry for a16spillir.\n\nLives in the project repo, not the vendor lit suite: dev/regen-patch.sh mirrors\nonly llvm/lib/Target/MOS, so a vendor test file would be gitignored + lost. A real\nupstream llvm/test/CodeGen/MOS lit test is deferred to the #321 upstreaming work.\n\nTest-only -- no vendor/codegen edit, so 0002 is untouched and no rebuild/regen.\nVerified: dev/run.sh a16spillir -> PASS (clean + 1 STStk/LDStk $a16); spot-check\ndev/run.sh a16spill -> PASS (unaffected sibling).\n\nPlan: docs/plans/2026-06-17-p2-hermetic-ll-crash-regression-for-the-soft-stack.md\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
