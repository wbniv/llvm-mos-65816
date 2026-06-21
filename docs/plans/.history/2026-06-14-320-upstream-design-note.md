| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/3c20dbc) | docs: #320 upstream design note (running far-pointer slice) + plan |

<!--history-meta v1
3c20dbc	author	Will Norris
3c20dbc	added	112
3c20dbc	deleted	0
3c20dbc	files	1
3c20dbc	body	Draft a self-contained design note (docs/320-upstream-far-pointer-note.md) to\nanchor the llvm-mos #320 design discussion with the running, verified far-pointer\nslice (Increments 1/2/2b) — in the project's code-first spirit (@mysterymath\nwon't bless an ABI without a high-quality implementation behind it).\n\nThe note: leads with what's implemented + verified (addrspace 2 = far -> 65816\nabsolute-long via existing MC instrs, gated on W65816, 6502 untouched; disasm +\nMAME bank $00 + MAME cross-bank $01, by commit SHA); is explicit about scope\n(constant/global far addresses only, 8-bit regs, emulation mode, far data only);\nstates the address-space-numbering divergence (slice 2=far additive vs proposal\n0=far-default / 2=absolute) as a conscious Option-A->Option-B choice with a\nreconciliation path; lists the open ABI decisions (default pointer width, the\nfive-space layout, calling convention); and surfaces the documented WDC816CC/\nORCA-C prior art (folding in the second upstream TODO item). Posting upstream is\na separate, user-triggered step.\n\nAlso: docs/plans/2026-06-14-320-upstream-design-note.md (the plan) and TODO\nupdates pointing the upstream items at the note.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
