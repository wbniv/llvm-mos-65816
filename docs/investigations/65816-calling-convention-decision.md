# 65816 C calling-convention decision — analysis & recommendation (#320/#321)

*The **decision-framing / analysis** layer for the calling-convention question the
[ROADMAP](../ROADMAP.md) flags as "open, blocks the ABI". The **facts** layer — the documented WDC816CC /
ORCA-C prior art, read from primary sources — is [`docs/320-321-65816-c-abi-prior-art.md`](../320-321-65816-c-abi-prior-art.md);
the upstream framing (@asiekierka's three pillars) is in [`docs/INVESTIGATION.md`](../INVESTIGATION.md)
§"The third pillar — the hardware stack". This note works the decision through and lands a recommendation.*

## TL;DR

- The "one decision" is really **four sub-decisions**. Three are cheap / high-consensus; **only the frame
  is hard.**
- **Return values = A (low) / X (high)** is the easy win: it is *already what llvm-mos emits* (verified
  below), it's the WDC + ORCA prior art, and it aligns with #321's `A16`. **Adopt + lock it now** — the one
  CC piece with a dedicated plan: [`docs/plans/2026-06-17-321-ax-return-convention.md`](../plans/2026-06-17-321-ax-return-convention.md).
- The decision **does not block** the next M2 work (xy16 + native-mode crt0) — those are register-mode +
  boot concerns, not the call boundary.
- Upstream **won't bless an ABI ahead of a high-quality implementation** (@mysterymath), and the CC is
  *explicitly still open* upstream. So our job is a credible **first-pass** CC, not the final ABI.
- **Recommendation: phase it.** Cheap path now (A/X return + keep imaginary-register args + native crt0);
  defer the frame fork until xy16 lands and we can measure; lean **TCD direct-page window layered over the
  existing static stack**, never a rip-out.

## What llvm-mos does today (the baseline we'd depart from)

`CC_MOS` (`MOSCallingConv.td`) — the inherited 6502 model:

- **Pointers** → zero-page imaginary registers `RS1–RS7` (`RS0` is the soft-stack pointer).
- **8-bit values** → **A, then X**, then `RC2–RC15`.
- **Overflow** → on the stack (`CCAssignToStack`).
- **Callee-saved** → the imaginary registers (`RC20–RC31`).
- **Crucially: non-recursive code touches no hardware stack at all.** That static-stack model is a big
  reason llvm-mos beats other 6502 compilers — and it's exactly what a hardware-stack ABI would trade away.

**Returns reuse `CC_MOS`** (there is no separate `RetCC_MOS`), so the return placement is *emergent* from
the byte-splitting rule. Verified codegen (`+mos-a16`, `-Os`, 2026-06-17):

```asm
; unsigned short add16(unsigned short a, unsigned short b){ return a+b; }
add16:
        sta __rc4 / stx __rc5      ; stash b
        rep #32
        lda __rc2 / adc __rc4      ; a + b  in the 16-bit accumulator
        sta __rc2
        sep #32
        ldx __rc3                  ; X = HIGH byte of result
        lda __rc2                  ; A = LOW  byte of result
        rts
; unsigned char add8(...) -> result in A
```

So **i8 → A; i16 → A (low) : X (high)** — already the prior-art convention. (Note the minor `+mos-a16`
round-trip: the value is in `A16`, gets stored to the `__rc2:__rc3` pair, then the low byte is reloaded into
A — an `A16`-aware return could keep it in A and lift the high byte via `XBA`→X. That's an
A16-threading-adjacent *optimization*, not the convention.)

## The decision decomposes

| Sub-decision | Difficulty | Read |
|---|---|---|
| **Return values** | trivial | **A (low) / X (high)** — prior art (WDC p.21 + ORCA `A_X`) *and* already emergent (above). Adopt + lock. |
| **Argument passing** | medium | Keep **imaginary-register** passing (`CC_MOS`, composes with the backend + #321) or push on the **hardware stack** (prior art; uncaps arg count; slower per call). |
| **Local / frame storage** | **hard** | ZP imaginary regs (today) vs. **TCD direct-page window** (prior art; fast; 256 B cap) vs. **pure stack-relative** (`,S`; no cap; slow). |
| **Recursion / reentrancy** | mostly solved | The soft static stack we just hardened (F3 / soft-stack P0–P2). The hardware stack *augments* it, not replaces. |

## The reframe that shrinks the hard one

**llvm-mos is already a direct-page window** — its imaginary registers are a *global, fixed* ZP block. The
prior-art `tsc / phd / tcd` frame is the **same idea made per-frame**. So the DP-window option is the
*evolution* of llvm-mos's own design, not a departure from it. That recasts the frame fork:

- **(a) TCD direct-page window** — fast locals (8-bit DP offset, full instruction coverage), proven in
  shipping commercial code, A/X-return-aligned. Cost: hard **256-byte frame cap**, `tsc/phd/tcd` prologue,
  requires native mode (the crt0 #321 is already building).
- **(b) Pure stack-relative** (`,S`, `(,S),Y`) — no frame cap, clean recursion. **But the 65816's
  stack-relative addressing has limited instruction coverage**, so the compiler keeps loading into A/DP
  first anyway → slower in practice. The weakest option.
- **(c) Keep the soft static stack** — reuses all backend machinery, genuinely *fast* for non-recursive
  code, no native-mode dependency for the frame. Cost: doesn't exploit the hardware stack; **keeps
  zero-page pressure high** — the real downside on the SNES.

**The swing vote is zero-page pressure.** The hardware-stack frame's structural win is moving locals off the
ZP, freeing the imaginary-register file. If the target programs are ZP-tight, that argues for (a); if not,
(c)'s speed is hard to beat for a first pass.

## What forces the decision — and what doesn't

- **It does not block the next M2 work.** xy16 + native-mode crt0 are register-mode + boot concerns; they
  proceed regardless. The CC only couples to xy16 through the A/X return (a 32-bit result's high word in a
  16-bit X), which the A/X convention already anticipates.
- **Upstream is implementation-first.** @mysterymath won't bless an ABI ahead of a high-quality
  implementation, and the CC is *explicitly still open* upstream (johnwbyrd, Dec 2025: "regardless of
  whatever convoluted calling convention we come up with…"). So the move is not to *pick the final ABI* —
  it's to ship a credible **first-pass** CC that demonstrates value and gives the maintainers something
  concrete to bless.

## Recommendation — phase it

1. **Now (cheap, high-consensus):** A (low) / X (high) return + keep imaginary-register arg passing +
   native-mode crt0 with `SP=$01FF`. This is @asiekierka's documented "cheap intermediate path"; it unblocks
   everything and commits nothing controversial. (The return piece has its own plan.)
2. **Defer the frame fork** until xy16 + crt0 land and we can **measure** on real 16-bit-ambient code; then
   lean **TCD DP-window layered over the static stack** — per-frame ZP window for hot/small frames, static /
   soft stack as the fallback for >256 B and recursion.
3. **Never remove the soft static stack.** The hardware stack is an *addition* (ZP relief + recursion), not
   a replacement — keep llvm-mos's actual strength.

## Open questions (the steer needed before committing the frame)

1. **Goal:** a *first-pass demonstrator* (→ minimal departure, the lean above) or *match the proven
   commercial ABI* for interop (→ full stack-push + DP-window now)?
2. **How tight is the zero page** in the SNES programs we care about? The swing vote between (a) and (c).
3. **Upstream posture:** proactively drive it (post the prior-art note + a proposed first-pass CC to #321 to
   engage @asiekierka / @mysterymath) or keep implementing and let the ABI emerge from working code?

## References

- Prior art (facts): [`docs/320-321-65816-c-abi-prior-art.md`](../320-321-65816-c-abi-prior-art.md) — WDC816CC manual pp.21–26, ORCA/C `Gen.pas`.
- ROADMAP: [`docs/ROADMAP.md`](../ROADMAP.md) §"M2 — the optimizing payoff" + §"Calling-convention decision (open, blocks the ABI)".
- Upstream framing: [`docs/INVESTIGATION.md`](../INVESTIGATION.md) §"The third pillar — the hardware stack".
- Current convention: `vendor/llvm-mos/llvm/lib/Target/MOS/MOSCallingConv.td` (`CC_MOS`), `MOSCallLowering.cpp`.
- The one landed-able piece: [`docs/plans/2026-06-17-321-ax-return-convention.md`](../plans/2026-06-17-321-ax-return-convention.md).
