---
name: feedback-decisive-recommendations
description: "When a field/choice is free-form, give THE recommended value as the instruction — don't hedge with \"anything / whatever / it's free-form, e.g. X\""
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 702c76d4-01fe-4a4c-9c13-167b32be0466
---

When telling the user to fill in a free-form field or make an open choice (a token
name, a label, a filename, a branch name…), state **the single recommended value as
the instruction** — "Name it `indri-apt-upload`." Do **not** say "it's free-form / use
anything / call it whatever, e.g. `indri-apt-upload`". The user already knows it's
arbitrary; surfacing that is noise that pushes the decision back onto them.

**Why:** the user asked me to "tell me to put the recommended thing" after I wrote
"Token name: anything (e.g. indri-apt-upload)". They want a decision, not options +
a hedge. Hedging on trivial choices reads as not doing my job (2026-06-26).

**How to apply:** pick the best value (follow existing naming conventions — e.g.
`indri-apt-ci` → `indri-apt-upload`) and give it flat as the step. If it genuinely
must vary, still lead with the recommendation. Applies in scripts' on-screen
instructions too, not just chat. Related: [[feedback_prefer_proper_fix]] (lead with
the recommended option, don't front the weak one).
