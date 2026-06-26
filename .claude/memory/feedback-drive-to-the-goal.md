---
name: feedback-drive-to-the-goal
description: "When the user gives a clear end-goal directive, execute all the way to it; don't keep stopping to ask which sub-strategy to take"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: df9f9c23-9a5e-4fd4-8f89-7b6d114f043a
---

When the user has stated a clear end goal ("find the problem and fix it, even if it's
upstream"), do NOT keep pausing to ask which sub-path to take (trace now vs. file upstream
vs. confirm-first). Pick the path, execute through to the deliverable, and report. Repeated
checkpoint questions on sub-strategy read as stalling — the user said *"what do you keep
asking me? i've already told you what i wanted... i'm tired of telling you"* (2026-06-25,
the default-8bit loopfold coalescer bug).

**Why:** a stated goal IS the authorization to do the substantial work (deep MIR/emulator
tracing, toolchain rebuilds, a real backend patch). Stopping to ask "should I do the hard
thing?" wastes the user's turns and signals reluctance to commit.

**How to apply:** legitimate clarifying questions are about *what* the user wants (ambiguous
goal); once the goal is unambiguous, questions about *how* I'll reach it should be answered
by doing, not asking. Surface a decision only if a step is irreversible/destructive or a
genuine fork in the GOAL. Relates to [[no-false-choice-questions]].

**Also don't stop to "checkpoint-report" mid-way.** Finishing one phase of a multi-phase goal
is NOT a stopping point — keep going to the next phase without handing control back. On the
#3 SNES Blossom port (2026-06-26) I finished the *render* half (Stages 0-2), wrote a tidy
"milestone report, ready to proceed to Stages 3-4" and ended my turn — the user shot back
*"omg, i thought you've been working on this for the past hour. why did you stop???"*. A
progress report that ends the turn reads exactly like a sub-strategy pause: it makes the user
spend a turn saying "continue." When the goal has obvious remaining work, report progress
*inline* (a line, a screenshot) and immediately keep building — drive until the whole thing
is done (or you hit a genuine blocker / irreversible fork), then report once at the end.
