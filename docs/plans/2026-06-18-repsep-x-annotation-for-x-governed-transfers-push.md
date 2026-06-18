# Plan: REPSEP X-annotation for X-governed transfers/push-pull (unblock seed-31)

**Date:** 2026-06-18 · **Issue:** #321, ROADMAP M2 · **Files:** `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInsertREPSEP.cpp` (only)

## Context

The hang fix (`8961afb`) took the xy16 differential fuzzer to 49/50. The lone residual, **seed-31**,
is a `MOSInsertREPSEP` critical-edge bug: the pass bails the whole function to `placeLegacy` on a true
critical edge, and `placeLegacy` forces X=8 at every block terminator, truncating a 16-bit `$x16` that
is live across `bb.0→bb.1` → wrong branch → wrong value.

The fix for seed-31 — replace the bail with a single `B.begin()` entry-switch — was implemented and
**verified to fix seed-31 (fuzz 50/50)**, but a wider `fuzz 200` sweep exposed a **regression at
seed-160**, so it was **reverted** (vendor + `0002` are byte-identical to `8961afb` today). Root cause
(`docs/plans/2026-06-18-321-repsep-critical-edge-x16-liveness.md`, §Why this is blocked): the
`B.begin()` change is correct in isolation, but by removing the bail it makes critical-edge functions
use the cross-block dataflow's **loop-mode-holding** (hold X=16 across the back-edge) instead of
`placeLegacy`'s per-iteration 8-bit anchoring. That exposes a **pre-existing latent bug**: the
**X-governed register transfers** are not modelled in `requiredXWidth`.

On the 65816 the transfer width of **TAX/TAY/TXY/TYX** is governed by the **X flag** (TXA/TYA by the M
flag). In seed-160's loop, with X held at 16 and M=8, `TA`(TAY) does a 16-bit A→Y that drags the hidden
B-accumulator high byte into `Y.high`, and a following `TX`(TYX) propagates it into X → the loop
counter/index is corrupted → wrong `corpus_result`. The bug stayed hidden because `requiredWidth` (M)
defaults to `MW_M8`, so transfers were *already* bracketed to M8 — but `requiredXWidth` (X) defaults to
`XW_None`, so the X-governed transfers slipped through unbracketed. **PHX/PLX/PHY/PLY** (push/pull of an
index register, also X-governed) are the same latent class, masked today only by the bail.

**Intended outcome:** annotate the X-governed index ops so the lattice keeps them honest, which makes
the dataflow path correct and **unblocks re-landing the `B.begin()` fix** → seed-31 fixed with **no
seed-160 regression**.

## Fix — Commit A: annotate X-governed index ops in `requiredXWidth`

In `MOSInsertREPSEP.cpp`, inside the existing `switch (MI.getOpcode())` in `requiredXWidth` (the block
that already handles `LDAbs`/`LDImag8`/`LDImm`/`STAbs`/`STImag8`/`LDXIdx`/`LDYIdx`), add:

```cpp
    // TA = TAX/TAY, TX = TXY/TYX — index-register transfers whose width is
    // governed by the X flag. The 8-bit pseudos are always 8-bit-intent (16-bit
    // transfers use the dedicated TAX16/TAY16/TXA16/TYA16, XLow=1). Unconditional X8.
    case MOS::TA:
    case MOS::TX:
      return XW_X8;
    // PH/PL of an index register (PHX/PLX/PHY/PLY) push/pull 2 bytes when X=16;
    // the 8-bit pseudo is 1-byte-intent. Operand 0 is the GPR.
    case MOS::PH:
    case MOS::PL:
      if (MI.getOperand(0).isReg() && isXY(MI.getOperand(0).getReg()))
        return XW_X8;
      break;
```

Also add a one-line comment near the switch noting **`T_A` (TXA/TYA) is intentionally omitted**: its
width is M-governed and its result `A` is X-independent (the `MW_M8` default in `requiredWidth` already
brackets it; forcing X8 would be wasteful, omitting it is correct).

**Why correct / sufficient** (confirmed by exploration + red-team):
- The plain `TA`/`TX`/`PH`/`PL` pseudos are created only by `copyPhysRegImpl`, `expandLDIdx`,
  `MOSLateOptimization` (combineLdImm/lowerCmpZero) — all on **8-bit GPR** operands. `selectXY16` never
  emits them; 16-bit transfers always use the `*16` pseudos (XLow=1 → already `XW_X16`). So forcing X8
  is never wrong.
- The opcode `MOS::TA` auto-covers the `expandLDIdx` creator (same opcode).
- `XW_X8` is monotone-conservative: it can only *add* a `sep #$10` relative to `XW_None`, never remove
  one — so it cannot regress correctness on either path (same argument the hang-fix used).
- Ordering is safe: `MOSLateOptimization` (pos 325, the last TA/TX creator) runs before `MOSInsertREPSEP`
  (pos 334); no pass after REPSEP creates transfers.
- **In-impl checks:** confirm no 16-bit push/pull pseudo exists (so `PH`/`PL` with $x/$y is always
  8-bit-intent), and confirm `PH`/`PL` operand-0 is the register (per `MOSMCInstLower.cpp` PH/PL → PHX/
  PLX/PHY/PLY lowering). `TSX`/`TXS` are **out of scope** (no compiler-pseudo path; crt0 stack init is
  hand-written asm).

Regenerate `patches/llvm-mos/0002-321-accum16.patch` with `dev/regen-patch.sh`.

## Fix — Commit B: re-apply the reverted `B.begin()` critical-edge change

Re-apply the change documented in `docs/plans/2026-06-18-321-repsep-critical-edge-x16-liveness.md`
(§Fix). In `MOSInsertREPSEP.cpp` Step 3a of `runOnMachineFunction`, replace the bail-on-critical-edge
block with the `B.begin()` entry-switch placement (verbatim, as previously implemented and reverted):

```cpp
    bool AnyMDiff = false, AnyXDiff = false, CriticalEdge = false;
    for (MachineBasicBlock *P : B.predecessors()) {
      bool M_diff = resolveIsM16(Out[P]) != NeedM16;
      bool X_diff = HasIndex16 && (resolveIsX16(XOut[P]) != NeedX16);
      if (!M_diff && !X_diff) continue;
      AnyMDiff |= M_diff; AnyXDiff |= X_diff;
      if (P->succ_size() != 1 && B.pred_size() != 1) CriticalEdge = true;
    }
    if (CriticalEdge) {
      // Unsafe only when forcing X8 onto an X-passthrough target (its X8 came
      // from a conflicting-pred meet, so an X16 value may be live-through).
      if (AnyXDiff && !NeedX16 && isPassthroughX(&B)) { Bail = true; break; }
      Placements.push_back({&B, /*AtEnd=*/false, AnyMDiff, NeedM16, AnyXDiff, NeedX16});
      continue;
    }
    // else: per-edge placement (single-succ pred → P end; else B.pred==1 → B.begin)
```

(Update the Step 3a header comment + the file-top "v1 is conservative…" comment to describe `B.begin()`
placement, as in the critical-edge plan. Keep the `Bail`/`placeLegacy` machinery as the residual
fallback for the X-passthrough-conflict corner.) Regenerate `0002` again.

## Verification

Run on a **quiet box** (concurrent MAME load flakes the settle window). Rebuild after each vendor edit
with `dev/run.sh toolchain`; confirm `clang-23` mtime advanced (stale-symlink gotcha). Paste raw output
under each step into this plan and mark PASS/FAIL.

**Commit A (annotation fix) — prove non-regression (it fixes nothing visible yet; seed-160 already
passes via `placeLegacy`):**
1. `dev/run.sh corpus` → 7/7; `dev/run.sh xy16basic && … xy16spill && … xy16spillr && … xy16ops` → all PASS.
2. Wide sweep `dev/run.sh fuzz 500 1` → **no seed flips PASS→FAIL** vs the `8961afb` baseline (expect the
   same residual set: 31, 157, 169, 173, 196). seed-160 stays PASS.
3. MIR spot-check (seed-160, `+mos-xy16`, `-print-after-all`): the new `sep #$10` appears before a
   `TA`/`TX`/`PHX` **only** in an X16 context, and is inert where X is already 8 (guards the size cost).
4. `dev/regen-patch.sh` round-trips; foreign-hunk count unchanged (`grep -c 'legalizeICmp\b\|addSub16Native\b'` = 5).

> **Commit A RESULTS (2026-06-18) — PASS, and a bonus fix.**
> 1. **PASS** — corpus 7/7; xy16basic/spill/spillr/ops all PASS.
> 2. **PASS — strict improvement.** `fuzz 500` → 491/500 (1 mismatch, 8 crash). **No PASS→FAIL flip.**
>    Decisively: **seed-157 now PASSES** (`0xD00D` all agree — was a mismatch on `8961afb`; it was a
>    *second* transfer-in-held-X16 bug on the dataflow path, fixed by this annotation), and **seed-160
>    stays PASS**. The lone remaining mismatch is **seed-31** (the critical-edge bug — needs Commit B).
>    The 8 crashes are all the pre-existing `+mos-a16` `$p`-spill bug: 3 known (169/173/196) + 5 newly
>    surfaced by the wider sweep (268/271/272/306/420) — **all pre-REPSEP** (0 `REP`/`SEP` in the dumped
>    MIR; `PH $p`/"undefined physical register"), so provably independent of this post-RA change.
> 3. **PASS** — every `TX`/`TAY` in seed-160's MIR is now preceded by an X-clearing `sep` (`#$30` before
>    `TX`, `#$10` before `TAY`); a `TAX` in an already-X8 block gets no extra `sep` (inert, as designed).
> 4. **PASS** — `0002` round-trips; foreign-hunk count = 5.

**Commit B (re-land `B.begin()`) — prove the payoff:**
5. `dev/run.sh fuzz 1 31` → PASS (`0x0B1F`, all agree); `dev/run.sh fuzz 1 160` → PASS (`0x1381`, all agree).
6. Wide sweep `dev/run.sh fuzz 500 1` (≥500; 1000 if box time allows) → **seed-31 AND seed-160 both pass**;
   the only residuals are 157 + 169/173/196 (the out-of-scope pre-existing bugs); **no new PASS→FAIL**.
7. **Bisect re-run** (the decisive evidence): rebuild once with the Step-3a `B.begin()` reverted (bail)
   and once with it applied; confirm seed-160 is PASS in *both* (the Commit-A annotation made the bail
   path and the dataflow path agree) and seed-31 flips FAIL→PASS only with `B.begin()`.
8. `-verify-machineinstrs` clean on seeds 31/160; `0002` round-trips, diff confined to `MOSInsertREPSEP.cpp`.

> **Commit B RESULTS (2026-06-18) — PASS, payoff delivered.**
> 5. **PASS** — `fuzz 1 31` → `0x0B1F`, `fuzz 1 160` → `0x1381`, `fuzz 1 157` → `0xD00D`, all agree.
> 6. **PASS** — `fuzz 500` → **492/500, 0 mismatch**, 8 crash. Zero value mismatches across all 1–500
>    (seed-31 fixed; seed-157 + seed-160 pass). The 8 residuals are exactly the pre-existing `$p`-spill
>    crashes (169/173/196/268/271/272/306/420), out of scope.
> 7. **PASS (bisect, decisive).** Commit A (bail + transfer fix) `fuzz 500` = 491/500 → failures {seed-31
>    mismatch} + 8 crashes; Commit B (B.begin + transfer fix) `fuzz 500` = 492/500 → {8 crashes} only.
>    The ONLY delta is **seed-31 FAIL→PASS**; **seed-160 PASS on both** paths (the Commit-A annotation made
>    bail and dataflow agree) and **no new PASS→FAIL** — i.e. the seed-160 regression is gone.
> 8. **PASS** — `-verify-machineinstrs` clean on 31 + 160; `0002` round-trips, foreign-hunks = 5, diff
>    confined to `MOSInsertREPSEP.cpp` (Step 3a `B.begin()`).
>
> **Micro-test:** deferred — the fuzzer (pinned seeds 31/160/157) is the authoritative guard, as planned.
> A dedicated `xy16xfer.c` was judged not worth the RA/dataflow-contingent fragility (the bug needs the
> dataflow to hold X=16 across a transfer, which is exactly the RA-dependent shape that drifts).

**Regression guard:** the fuzzer is authoritative — pin `dev/run.sh fuzz 1 31` and `fuzz 1 160` as the
guards. *Best-effort companion:* attempt `examples/65816/xy16xfer.c` + frozen `.ll` (model the reduced
`build/fuzz-triage/seed-00160.c`: a single straight loop — **no critical edge** — whose counter
round-trips through `TAY`/`TYX` while the body does a 16-bit `arr[i]` access so the dataflow holds X=16;
value-differential gate host==default==xy16 on MAME + bsnes-jg, wired into `dev/run.sh`). If it proves
too RA/dataflow-contingent to reliably fail pre-fix, ship the `.c` as a documented illustrative example
and rely on seed-160.

## Out of scope (separate pre-existing bugs — keep as their own open TODO items)
- **seed-157** — a distinct `+mos-xy16` value mismatch (fails on both bail and `B.begin()` toolchains).
- **seed-169 / 173 / 196** — `+mos-a16` compiler crash in `-verify-machineinstrs` ("`$p` is not a GPR
  register" on `PH $p`/`STImag8 $p`), a `$p`-spill bug that crashes **pre-REPSEP** — unrelated to this work.
- **TSX/TXS** — no compiler-pseudo path; would only matter for a future native-hardware-stack frame.

## Files modified
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInsertREPSEP.cpp` — Commit A (`requiredXWidth`: TA/TX/PH/PL),
  Commit B (Step 3a `B.begin()` placement).
- `patches/llvm-mos/0002-321-accum16.patch` — regen after each.
- `docs/plans/2026-06-18-321-repsep-critical-edge-x16-liveness.md` — flip STATUS from BLOCKED to landed;
  fill verification. `TODO.md` — move seed-31 + transfer items to Done; keep 157 + 169/173/196 open.
- (optional) `examples/65816/xy16xfer.c` + `.ll` + `dev/xy16xfer.sh` + `dev/run.sh` wiring.
