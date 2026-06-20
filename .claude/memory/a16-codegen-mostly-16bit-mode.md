---
name: a16-codegen-mostly-16bit-mode
description: "Under +mos-a16, code is predominantly 16-bit (M=0), and going native 16-bit isn't automatically smaller — operand residency + schedule decide; measure in realistic context, then gate the native form to where it wins"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f046a24a-e8c0-48d8-96c5-7ac7458cef9b
---

Under `+mos-a16` (native 16-bit-accumulator codegen, issue #321), generated 65816 code runs
**predominantly in 16-bit accumulator mode (M=0, `rep #$20`)**, dropping to 8-bit (M=1, `sep #$20`)
mainly to touch hardware — and not always even then. Functions are entered/exited in 8-bit mode (the ABI
does calls/returns in M=1), but sustained compute holds M=0 (e.g. loop bodies keep one `rep` hoisted to
the preheader and one `sep` sunk to the exit, none in the body).

**Why:** I first measured the indirect-s16-load byte-wise optimization using isolated leaf functions,
which pinned the ambient at M=1 and so charged the full `rep`/`sep` mode-switch to the load under study.
The user flagged that this over-counts, because real `+mos-a16` code is mostly M=0.

**How to apply:** When measuring or reasoning about `+mos-a16` codegen cost — especially `rep`/`sep`
mode-switch overhead — never assume an 8-bit ambient. Build the pattern inside realistic 16-bit-heavy
context (or a loop body), dump the disasm, and check **empirically** whether a given `rep`/`sep` is
attributable to the op under study or to the surrounding mode. (Nuance found while checking exactly
this: byte-wise lowering of an s16 load whose every use is `G_UNMERGE` looked like a clean −6 B win in
isolated leaf functions, but in 16-bit-ambient code the result is **schedule-dependent** — it wins only
when the bytes flow straight into the consumer, and *regresses* (+2 B) when 16-bit work is scheduled
between the load and the byte-consumer, because byte-wise then carries two byte-spills across that region
vs the native form's one word-spill. The leaf measurement gave the wrong sign of the conclusion.)

**Generalized — confirmed twice** (the byte-wise indirect load above, and the native-EQ-as-value spike,
both net regressions on the *common* cases): "going native 16-bit" is **not automatically smaller**. A
native 16-bit op routes its operands through `Imag16` + a `rep`/`sep` bracket, so it loses to the tight
8-bit register/byte path whenever the operand is register-resident (params), a foldable global, or the
result is consumed as bytes — and wins only when the operand is *already* in `Imag16`/memory. Always
build the real shape and diff bytes; then **gate** the native form to fire only where it wins. A gated,
no-regression modest win **is** worth shipping (see [[modest-gains-worth-doing]]) — the measure-first
discipline is about finding the real win, not an excuse to skip it.
