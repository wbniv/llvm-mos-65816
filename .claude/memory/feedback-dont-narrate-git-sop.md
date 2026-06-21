---
name: feedback-dont-narrate-git-sop
description: "Don't report the commit/push SOP every round — committing-but-not-pushing, \"origin is N behind\", \"say the word and I'll push\" is known boilerplate the user finds annoying"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ab95a260-47dd-41ee-b4f4-de47dbb5670b
---

The user knows the git SOP (commit at natural checkpoints; push only when explicitly asked; `main` is a hot shared tree carrying concurrent agents' unpushed commits). Stop telling them about it practically every round — no "Not pushed, you didn't ask"; no "origin/main is N commits behind"; no "say the word and I'll fast-forward push" sign-off.

**Why:** It's standard operating procedure they already understand, AND their status bar already shows it live — `(main) ±7 ↑3` means 7 dirty files / 3 commits ahead of origin. Restating dirty-count or ahead-count is doubly redundant (explicit annoyance, 2026-06-21).

**How to apply:** Just commit as a checkpoint and stay silent about push state. Push when asked, nothing to announce beyond that it's done. Keep turn summaries about the actual work (what changed, verification results), not git-state narration. Related: [[feedback_commit_scope]] (stage only the enumerated files).
