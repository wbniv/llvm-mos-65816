| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/bd508c3) | #320 Inc 4 Ph2 P0+A0: record far-ptr CC progress (variant a Imag32 verified) |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/03a6dfe) | #320 Inc 4 Phase 2: detailed plan — far-pointer CC, build all variants & measure |

<!--history-meta v1
bd508c3	author	Will Norris
bd508c3	added	16
bd508c3	deleted	6
bd508c3	files	1
bd508c3	body	Docs for the far-pointer calling-convention work landed on wt/320-far-cc (10a5fc0):\n- plan: P0 + A0 marked DONE with evidence; note the far-CC delta lives in a stacked\n  0004-320-far-cc.patch (not 0001) because the A0 fix shares the AnyRegBank/Ac16\n  line with 0002 — the diff-reapply split can't separate it; stacking after 0002 is\n  the clean home, 0001 stays a16-free.\n- agent-handoff: register wt/320-far-cc; P0+A0 done & two-emulator verified.\n- howto-feature-worktree: add the §compiler-changing variant (cp -a warm build)\n  that CLAUDE.md and the plan already reference but the doc was missing, incl. the\n  mkdir-vendor-first and confirm-clang-23-mtime gotchas.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01LNqksvWfK38piTuGXz8y5W
03a6dfe	author	Will Norris
03a6dfe	added	175
03a6dfe	deleted	0
03a6dfe	files	1
03a6dfe	body	Flesh out Phase 2 (the far-pointer calling convention) into its own executable\nplan, modeled on the 321 frame-ABI three-way study:\n\n- The break: CC_MOS assigns every pointer to a 16-bit RS# pair (no size rule), so\n  a 32-bit p2 mis-sizes across a call. The far-ptr rule must fire ONLY for p2\n  (gated before CCIfPtr) so near/scalar codegen stays byte-identical.\n- Variant matrix: (a) Imag32 quad, (b) Imag16+bank byte, (c) A:X+Y, (d) hw stack;\n  (a)/(c) the primary poles, (b)/(d) controls.\n- Selection: one off-by-default feature per variant (mirrors FeatureAccum16) →\n  default byte-identical; A-B harness via -Xclang +mos-farcc-XXX.\n- Phased: P0 (features + shared 4-byte plumbing, byte-identical gate) -> A0\n  (variant a end-to-end + feasibility gate) -> A1-A3 (b/c/d) -> M (bytes+cycles,\n  build the probe-cycles.lua harness the frame study specced) -> D (ship winner).\n- KEY difference from the frame study: this MUST ship one variant — a tie resolves\n  to the simplest (Imag32), never "change nothing". Pre-registered go/no-go picks\n  WHICH, not whether.\n- Runs on a wt/320-far-cc feature worktree; winner lands in 0001; rest stay a\n  measured spike. Durable artifacts (workload, measurement driver) merge regardless.\n\nDocs point to the new plan (Inc 4 plan Phase 2 section, TODO, implementation-status).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
