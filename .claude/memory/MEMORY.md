# Memory index

- [a16 code is mostly 16-bit mode](a16-codegen-mostly-16bit-mode.md) — native 16-bit isn't automatically smaller; measure in realistic context, then gate to where it wins
- [Modest gains are worth doing](modest-gains-worth-doing.md) — this is a compiler; every win is amplified across thousands of developers worldwide ("high-effort" is a scheduling input, not a veto)
- [audit-deferrals hook no longer absorbs TODO.md](audit-deferrals-hook-force-adds-todo.md) — it used to git-add the whole TODO.md into a plan commit (swept in unstaged edits); FIXED in python-tui-lib 4f88186 — now leaves the Inbox unstaged when TODO.md is dirty
- [Investigations on throwaway branches](investigations-on-throwaway-branches.md) — exploratory/measurement work runs on a disposable worktree, never on main's hot shared working copy (user principle, 2026-06-18)
- [No false-choice questions](no-false-choice-questions.md) — don't pose AskUserQuestion forks where every option collapses to the same next action or one is the obvious project default; just act and state it (user feedback, 2026-06-19)
- [Close net-negative findings, don't defer](close-net-negative-findings-not-defer.md) — a measured net-negative is an answer (don't do it), not a "needs a gate / future work" backlog item; close it, record the evidence (user feedback, 2026-06-20)
