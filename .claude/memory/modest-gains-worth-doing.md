---
name: modest-gains-worth-doing
description: "ANY genuine gain is worth banking on llvm-mos-65816 — it's a compiler, so wins amplify across every program/developer. Modesty, rarity, and effort set PRIORITY (when/order), never go/no-go (whether). The only 'don't' is a measured net-negative."
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

**The sharpened rule (user, 2026-06-21): a gain is never a go/no-go decision — only a PRIORITY one.**
Modesty, rarity, AND effort are all *scheduling* inputs (when/in-what-order to do it), never vetoes
(whether to do it). "Small" → still do it. "Rare shape" → still do it. "High-effort" → still do it.
The single thing that flips a gain to "don't" is a **measured net-negative** (a real regression) —
that's the separate principle [[close-net-negative-findings-not-defer]].

**Why (two corrections):**
- I once recommended *shelving* a gated native-s16-EQ-as-value win as "high-effort / modest-gain" →
  corrected: **"high-effort" is a scheduling input, not a veto.**
- Then (the compare follow-ups) I parked a CLEAN ordering-as-value branchless win as "modest **and rare**
  (2/56 programs) → not worth it" → corrected: **rarity is also a scheduling input; any gain is a gain,
  it becomes a priority, not a go/no-go.** I had conflated "rare clean win" with "net-negative" — wrong:
  the regressing *naive* implementation was correctly closed (net-negative), but the CLEAN win (the
  mode-agnostic `rol` materialisation) was wrongly shelved.

**How to apply:** weight even small/rare per-program gains as worth banking; never dismiss a genuine win
as too modest/rare/hard — schedule it. **If a naive implementation REGRESSES, the move is not to shelve
the gain — it's to engineer the implementation that banks it cleanly** (e.g. the compare win needed a
mode-*agnostic* materialisation that never forces a `sep`, not a gate on the churning 8-bit form; couldn't
gate cleanly → build the right form instead). The only correct "reject" is a measured net-negative with
*no* clean form. Companion measurement lesson: [[a16-codegen-mostly-16bit-mode]].
