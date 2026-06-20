# #321 — calling-convention FRAME decision: RESOLVED (phased)

**Date:** 2026-06-18 · **Status:** **DECISION RECORD — frame sub-decision RESOLVED (phased).** No codegen
change; this records a steer and the trigger that would reopen it.
**Issue:** #321, ROADMAP M2 (the hardware-stack ABI / 16-bit calling convention).
**Required reading:** [CC analysis & recommendation](../investigations/65816-calling-convention-decision.md) ·
[WDC816CC / ORCA-C prior art](../320-321-65816-c-abi-prior-art.md) ·
[A/X-return convention (the one CC piece already landed)](2026-06-17-321-ax-return-convention.md).

## Context

The 65816 C calling convention is "one decision" that decomposes into **four sub-decisions**: return values,
argument passing, **frame layout**, and recursion. Three were cheap/settled; the **frame** was the one hard,
open fork — and it gated M2's last major piece (the hardware-stack ABI). It was deliberately held "until
xy16 + native-mode crt0 land and we can measure." Both have landed (native crt0 `05d98c6`; xy16 in flight),
so the decision went live and the project lead steered it on **2026-06-18: phase it.** This record captures
that steer so the analysis doc, `TODO.md`, and `ROADMAP.md` stop describing the frame as "open/hard."

## The decision: PHASE IT

**First-pass ABI keeps the soft static stack (c).** Defer the TCD direct-page window (a) behind a
zero-page-pressure measurement. Rule out the pure hardware-stack-relative frame (b) as dominated.

| frame candidate | speed | frame cap | build cost vs today | verdict |
|---|---|---|---|---|
| (a) TCD direct-page window (`tsc;phd;tcd`, 8-bit DP locals) | fastest (full DP instr coverage) | **256 B hard** | medium (~150–200 LOC; must model the **D** register) | **DEFERRED** behind the ZP measurement below |
| (b) HW-stack-relative (`offset,S`) | slowest (limited `,S` coverage → still loads via A) | none | medium-high (finish 65816 `,S` instr defs) | **RULED OUT** (dominated by (a)) |
| (c) Soft static stack (today; locals in fixed-ZP `__rc*` imaginary regs) | fast for non-recursive (llvm-mos's edge) | none (but ZP pressure) | **none (done)** | **CHOSEN for the first pass** |

**Why.** Ship a credible *first-pass demonstrator*, not the final ABI — upstream (@mysterymath) won't bless
an ABI ahead of a high-quality implementation, and (c) is llvm-mos's actual competitive advantage
(non-recursive code touches no hardware stack). The hardware stack is an *addition* (ZP relief + recursion),
never a rip-out. (a) is the *per-frame evolution* of llvm-mos's own fixed-ZP imaginary-register idea, so it
remains the natural growth path if/when ZP pressure justifies it. This is "open question 1" (goal) of the
analysis doc, answered: **first-pass demonstrator.**

## Already settled (the other three sub-decisions)

- **Return values — LOCKED (2026-06-17):** A (low) / X (high); regression-guarded (`dev/run.sh a16ret`); no
  codegen change. ([A/X plan](2026-06-17-321-ax-return-convention.md).)
- **Argument passing — adopted for the first pass:** keep imaginary-register passing (`CC_MOS`, existing,
  cheap). Hardware-stack arg-push is the commercial-ABI alternative, not adopted now (it pairs with a
  hardware-stack frame, which we deferred).
- **Recursion / reentrancy — solved:** the soft static stack is hardened (F3 + soft-stack P0–P2) and stays
  the fallback under *every* frame choice — including as the >256 B / recursion fallback if (a) is later built.

## Revival trigger (the swing vote — measure, don't guess)

The structural win of (a) is moving locals off the zero page, freeing the imaginary-register file. So (a) is
justified **iff the ZP is actually tight.** Reopen this decision when a measurement on real 16-bit-ambient
code (corpus + kernels at `+mos-a16 -Os`) shows the imaginary-register high-water mark (distinct
`Imag16`/`Imag8` simultaneously live; usable budget ≈ 14 sixteen-bit pairs: `RS1–RS7`, `RS9–RS15`)
**routinely approaching/exceeding the budget**. If real programs sit well under, (c) stands and (a) stays
shelved *with evidence*. (Measurement is host-only — safe on a busy box — and is intentionally **not built
here**; this record only names it as the trigger.)

**MEASURED 2026-06-18 — SLACK; (a) stays shelved, evidence-backed.** `dev/measure-zp-pressure.sh` (the
[ZP-pressure plan](2026-06-18-321-zp-pressure-measurement.md)) ran the baseline: across 13 real-code
functions (6 kernels + 5/6 corpus) the imaginary-register high-water mark is **10 / 28 bytes — ~5 of 14
pairs** (max, `k_bits:main`; mean ~2.8 pairs). Nothing approaches the budget, so the DP-window (a) would
relieve pressure that isn't there → **(c) stands; (a) deferred indefinitely.** (The scan also surfaced a
separate `+mos-a16 -Os` register-allocation *crash* on `globals.c` — a robustness bug, not a budget issue,
tracked independently.)

**SUPERSEDED 2026-06-20 — DIRECTLY MEASURED; (a) AND (b) CONFIRMED-shelved (NULL).** The above shelved (a)
on an *indirect* proxy (ZP slack). The frame-ABI head-to-head study
([plan](2026-06-20-321-frame-abi-build-all-three-and-measure.md)) then measured the frame-traffic
*opportunity* directly: A0 proved the DP↔`__rc` collision is *avoidable* (`0xBBAA` on MAME+bsnes), but the A0
census (`dev/frameabi-census.sh`) found **0/13 realistic functions** would profit from *either* (a) DP-window
or (b) stack-relative — locals are register-resident in `__rc` (and local aggregates go through a pointer in
`__rc`), so static-stack/spill traffic is ≈0 and a per-frame window only taxes the abundant `__rc` accesses.
**(c) the soft static stack is retained by measurement, not default.** The (a)/(b) codegen was not built (the
census short-circuited it); pure stack-relative's paper "dominated" ruling is now evidence-backed too.

## If revived: the (a) implementation path

Model the **D** (direct-page) register in `MOSRegisterInfo.td` — the one missing piece; `PHD/PLD/TCD/TCS`
already exist (`MOSInstrInfo.td:768–784`). Emit `tsc; [sbc #size; tcs;] phd; tcd` prologue + `pld` epilogue
in `MOSFrameLowering.cpp`; route local access to DP-offset addressing; add a linker/data-layout guard
against DP-window ↔ global-ZP collisions; keep the soft static stack as the >256 B / recursion fallback.
Verify differentially (host == default == `+mos-a16` on MAME + bsnes-jg) + a >256 B frame-overflow test +
corpus 7/7. This lands behind a dedicated implementation plan, not this record.

## Upstream

Open question 3 (upstream posture) stays open and **user-triggered**: whether to proactively post the
prior-art note + this first-pass CC to #321 (engage @asiekierka / @mysterymath), or keep implementing and
let the ABI emerge. Tracked in `docs/upstream-contribution-status.md` and the TODO Upstream section.
