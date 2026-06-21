# #320 — far-pointer calling convention: measured ABI evaluation (evidence note)

**Status:** drafted, ready to post (user-triggered). A follow-up to the
[#320 far-pointer design note](320-upstream-far-pointer-note.md): that one opens the five-address-space
ABI-blessing discussion; this one brings **implementation-backed CC evidence** for how a far (addrspace 2)
pointer should cross a call. Post to the llvm-mos Discord / issue #320 (@asiekierka / @mysterymath) once the
design note has opened the conversation.

## What was measured

A 32-bit far pointer could not cross a function boundary at all — passing/returning one crashed call
lowering (`CC_MOS` sized every pointer at 16 bits, so a 24-bit address `G_UNMERGE`d). Rather than guess a
convention, we built **all four** plausible ABIs behind off-by-default `+mos-farcc-*` features and measured
them on the same realistic round-trip (a far pointer returned from one `noinline` and passed into another,
dereferenced across a bank boundary), correctness-gated on MAME + bsnes-jg (`0xF3` round-trip):

| variant | where the 24-bit pointer rides | `.text` (round-trip) | round-trips / 120 frames |
|---|---|---:|---:|
| **(a) Imag32** | one 4-byte zero-page `Imag32` (RL) quad | **70 B** | **50441** |
| (b) Imag16+bank | 16-bit offset in an `RS#` pair + bank in an `RC#` | 86 B | 41385 |
| (c) A:X+Y | offset in `A:X`, bank in `Y` (hardware regs) | 102 B | 43572 |
| (d) soft-stack | the 4 bytes in one soft-stack slot | 174 B | 30626 |

(MAME 0.285's Lua exposes no `total_cycles()`, so throughput = round-trips completed in a fixed wall of
emulated frames — exact and deterministic.)

## Verdict

**(a) Imag32 wins on both axes, decisively** — smallest *and* fastest; every other variant is both bigger
and slower. It is the natural width-extension of how near pointers already pass (an `RS#` pair → an `RL`
quad), keeps the pointer register-resident (so fewest memory accesses → fewest cycles), and needs no custom
CC assigner. So far-pointer-across-call now ships **Imag32 by default** in this fork; the other three are
retained only as the measured spike.

The decomposed (b) and hardware-register (c) conventions cost more code for no speed win on realistic
traffic; the prior-art **hardware-stack** convention (push args, read via `,S`) was *recorded-and-dropped* —
its soft-stack form (d) is already the slowest/largest, and a true `,S` form is blocked on threading a
moving `SPAdj` through the call-frame pseudos (asserted zero today) plus adding 65816 `,S` opcodes, for a
result the frame-ABI study already measured at zero opportunity.

**Takeaway for upstream:** when the five-address-space model lands, the far-pointer (AS2) calling convention
should pass/return the whole 32-bit value in a single 4-byte imaginary-register unit (the Imag32/RL form),
not a decomposed or stack-based split — by measurement, not assertion.
