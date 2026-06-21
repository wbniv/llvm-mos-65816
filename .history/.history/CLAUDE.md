| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/392030a) | #321 docs: add the feature-worktree howto (target of the agent-handoff + CLAUDE.md pointers) |
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/9148a7b) | docs: investigations go on throwaway worktrees, not main (standing convention) |
| [2026-06-17](https://github.com/wbniv/llvm-mos-65816/commit/6fff2f1) | #321 docs: wire awareness of the upstream-contribution-status queue into CLAUDE.md + TODO |

<!--history-meta v1
392030a	author	Will Norris
392030a	added	6
392030a	deleted	0
392030a	files	1
392030a	body	docs/howto-feature-worktree.md: the cp -al hardlink procedure to run dev/run.sh from a\nworktree without a 30-90 min toolchain rebuild (the CLAUDE.md env-override trick is\nhost-side only — it dangles inside dev/run.sh's single-root Docker mount). The pointer\nfrom agent-handoff.md landed via concurrent commit d26a5e6; this adds the file it and the\nCLAUDE.md caveat reference, plus the CLAUDE.md caveat itself.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
9148a7b	author	Will Norris
9148a7b	added	6
9148a7b	deleted	0
9148a7b	files	1
9148a7b	body	Per a standing user principle (2026-06-18): exploratory/measurement work\n(measurements, spikes, probes) runs on a throwaway/<slug> branch in its own\nworktree, never on main's working copy — a dead-end stays disposable and, on\nthis hot shared tree (concurrent agents leave vendor/, 0002, TODO.md dirty),\nthe worktree gives a clean checkout + clean commits. Keep -> merge durable\nartifacts back; dead-end -> worktree remove + branch -D.\n\nAdded to the project commit-discipline section; the cross-project rule + rationale\nis in ~/SRC/CLAUDE.md "Worktree-based feature workflow" (extended to investigations),\nand an auto-memory (investigations-on-throwaway-branches) mirrors it.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
6fff2f1	author	Will Norris
6fff2f1	added	11
6fff2f1	deleted	0
6fff2f1	files	1
6fff2f1	body	So the pending-to-post queue (docs/upstream-contribution-status.md) is kept current:\n\n- CLAUDE.md (auto-loaded every session) §Commit discipline: a standing rule — upstream\n  PRs/issues/notes are queued in that doc; posting is user-triggered; keep it current in\n  the same commit when you draft an artifact, push a PR branch, or post one.\n- TODO.md §Upstream / Contribution: a back-pointer to the doc as the live queue + exact\n  post commands, to keep in sync (drafted → ready-to-post → posted).\n\nThe status doc already points back to the TODO section, so discoverability is bidirectional.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
