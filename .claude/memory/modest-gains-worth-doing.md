---
name: modest-gains-worth-doing
description: "Modest optimization gains are worth doing on llvm-mos-65816 — it's a compiler/toolchain, so every win is amplified across thousands of developers and every program they compile"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f046a24a-e8c0-48d8-96c5-7ac7458cef9b
---

The user's explicit prioritization principle for llvm-mos-65816 (#321 native s16 codegen): **modest gains
are still worth doing — the work here is amplified thousands of times by developers all over the world.**
This is a compiler: a −3/−4-byte or few-cycle improvement is not "−4 bytes," it's −4 bytes × every
matching construct × every program × every developer who uses the toolchain. That multiplier makes small
per-site wins genuinely valuable.

**Why:** I had recommended *shelving* a gated native-s16-EQ-as-value optimization as "high-effort /
modest-gain (−3/−4 B on a sub-pattern)." The user corrected the framing — modest gains are worth the
effort here because of the amplification, and **"high-effort" is a scheduling input, not a veto.**

**How to apply:** When evaluating a codegen optimization, weight even small per-program gains heavily;
default toward implementing genuine wins rather than dismissing them as too modest. **Caveat — this is
about genuine gains, not regressions:** a *blanket* change that regresses common cases to win a sub-case
is still wrong (the byte-wise indirect load and the *blanket* native-EQ both regressed the common case —
correctly rejected). The right move is to **gate** the optimization so it fires only where it wins, then
ship that gated modest win. Companion measurement lesson: [[a16-codegen-mostly-16bit-mode]].
