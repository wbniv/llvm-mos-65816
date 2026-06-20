# #320 Inc 4 Ph2 A3 — far-pointer CC variant (d): stack passing (+ the build-vs-drop decision)

**Date:** 2026-06-21 · **Status:** PLANNED (not started) · **Scope:** the 4th and final far-pointer CC
variant on `wt/320-far-cc` — pass/return a 32-bit far pointer (`p2`) **in memory (on a stack)** rather than
in registers. **Builds on:** [the build-all-variants plan](2026-06-20-320-far-pointer-cc-build-all-variants.md)
(P0 + A0 Imag32 + A1 Imag16+bank + A2 A:X+Y all landed & two-emulator-verified). **Prior art / precedent:**
[the 321 frame-ABI study](2026-06-20-321-frame-abi-build-all-three-and-measure.md) (stack-relative frames:
measured 0/13 opportunity, **shelved**).

## TL;DR — the recommendation up front

Variant (d) exists to answer one measurement question: **what does passing a far pointer in *memory* cost
vs. in *registers*** (variants a/c)? There are two ways to realize "in memory," and they differ ~50× in
effort:

- **(d-soft) — the soft static stack** (RS0-relative). The backend **already** lowers stack/memory args
  (`assignValueToAddress` + `getStackAddress` + `CCAssignToStack`, the path varargs use). A far-ptr
  stack variant here is **~40–50 lines**, sidesteps every hardware-stack hazard, and **fully answers the
  measurement question**. ✅ **Recommended — build this.**
- **(d-hard) — the 65816 *hardware* stack** (`,S` addressing, the literal "pushed on the 65816 stack /
  WDC816CC" wording in the original matrix). This is a **multi-day lift** blocked on two hard problems
  (missing 65816 `,S` opcodes **and** `eliminateFrameIndex` asserting `SPAdj == 0`), and the frame-ABI study
  already measured the same machinery at **zero opportunity**. ⛔ **Record-and-drop** unless the census +
  (d-soft) numbers show a real, multi-program win that only hardware-S could capture.

**So A3 = build (d-soft) cheaply, census the opportunity, then at D decide whether (d-hard) is ever worth
its lift.** This is exactly the "measure the opportunity first; a variant materially harder than (a) for no
plausible win may be recorded-and-dropped" gate the parent plan pre-registered.

## Why the fork exists — soft stack vs hardware stack on this backend

This backend does **not** use the 65816 hardware stack (the `S` register) for C data. `S` holds only call
return frames (JSR/RTS; **JSL/RTL push a 3-byte PBR:PC**) and interrupt state; `crt0` sets `S=$01FF` and
leaves it to the runtime. C locals/spills/over-flow args live on a **soft static stack** addressed via the
`RS0` imaginary pointer (zero page), not `,S`. So on this target, **"the stack" that the CC actually uses
is the soft stack** — the hardware stack is an *additional*, unwired mechanism.

That reframes the original matrix's "(d) hardware stack … needs `,S` addressing": the *essential* property of
variant (d) — **memory-resident, scales past the one-far-ptr limit of (c), per-access load/store cost** — is
delivered by the soft-stack route **without** any `,S` wiring. The hardware-`,S` convention is a *different,
heavier* thing whose only marginal benefit over (d-soft) would be using `S` the way WDC816CC/ORCA-C did — and
the frame study already found that benefit empirically absent on realistic code.

## What exists vs. what (d-soft) needs

**Already in place (reuse — verified by source audit):**

| Piece | Location | Note |
|---|---|---|
| Inert feature + predicate + enum | `MOSFeatures.td` (`FeatureFarCCStack`), `MOSCallingConv.cpp:38` (`MOSFarCCStack()`), `MOSSubtarget.h:128` (`FarPtrCC::Stack`) | The P0 stub — ready to gate a rule on. |
| Outgoing memory store | `MOSCallLowering.cpp` `MOSOutgoingValueHandler::assignValueToAddress` (~`:96`) | `buildStore` + `MachineMemOperand`. Proven (varargs). |
| Incoming memory load | `MOSCallLowering.cpp` `MOSIncomingArgsHandler::assignValueToAddress` (~`:283`) | `buildLoad` (invariant). |
| Stack-address computation | `getStackAddress` — outgoing RS0+offset (~`:161`), incoming `CreateFixedObject`+`buildFrameIndex` (~`:273`) | Soft-stack, **no `,S`, no `SPAdj`**. |
| Stack-assign CC primitive | `MOSCallingConv.td` `CCAssignToStack<0,1>` (catch-all; `CC_MOS_VarArgs` uses it, ~`:112`) | The mem-loc producer. |
| Custom-assigner dispatch | `MOSCallLowering.cpp` `assignCustomValue` (the b/c path) | Extend to a mem-loc branch. |

**To build (the ~40–50 lines):**

1. **CC rule** — in `MOSCallingConv.td`, gated **before** `CCIfPtr`, mirroring (a)/(b)/(c):
   `CCIfPtrAddrSpace<2, CCIf<"MOSFarCCStack(State)", CCCustom<"CC_MOS_FarPtrStack">>>,`
2. **`CC_MOS_FarPtrStack`** (`MOSCallingConv.cpp`) — allocate one 4-byte slot
   (`State.AllocateStack(4, Align(1))`), push a single `CCValAssign::getCustomMem(...)`. (Replaces the
   current `CC_MOS_FarPtrSplit` "MVP has no stack fallback" rejection for the Stack feature.)
3. **`assignCustomValue` mem-loc branch** (`MOSCallLowering.cpp`) — when `VAs.size()==1 && VAs[0].isMemLoc()`:
   outgoing = `getStackAddress` + `assignValueToAddress` (store the 4 bytes); incoming = `getStackAddress`
   + `assignValueToAddress` (load) → `inttoptr`. Symmetric with the register branches; reuses the existing
   helpers, so it's wiring, not new machine IR.
4. **Return** — the far-ptr *return* lands the natural mirror: a returned `p2` goes to the soft-stack slot
   too (or, if the existing return path can't take a mem-loc cleanly, fall back to the (a) `RL` return for
   the Stack variant — decide during impl; document which).

> Crucial gate (same as every variant): **default codegen byte-identical.** The rule is gated on
> `MOSFarCCStack()` (false unless `+mos-farcc-stack`), so no-flag builds are provably untouched.

## Phased, gated sequence

| Phase | Deliverable | Gate to proceed |
|---|---|---|
| **A3a** *(build d-soft)* | The CC rule + `CC_MOS_FarPtrStack` + the `assignCustomValue` mem-loc branch + `dev/farcc_stack.sh` (+ `dev/xcheck.sh` + `dev/run.sh` wiring), behind `+mos-farcc-stack`. | A far ptr passed **and** returned across a real call round-trips `0xF3` on **MAME + bsnes-jg**; `-verify-machineinstrs` clean; negative control; **default byte-identical (corpus 7/7)**. Then `dev/regen-patch-0004.sh` captures it; commit as A3 mirroring `02953e7`. |
| **Census** *(the opportunity)* | Extend the workload/measurement to count how often far pointers actually cross calls in realistic SNES code, and whether a *memory* convention could ever beat the register poles (a)/(c) — which are already cheap and proven. | A short table: far-ptr-call frequency + a per-program (a)/(c)/(d-soft) bytes(+cycles) comparison on the inner loop and whole call. |
| **D (decision)** | Apply the parent plan's go/no-go. Land the winner (still expected to be **(a) Imag32**) in `0001`; keep the rest as the measured `0004` spike. **Record-and-drop (d-hard)** with the cost documented, OR — only if the data demands it — open a separate plan to build hardware-`,S`. | Differential-clean; `0004`/`0001` patch hygiene per the parent plan's verification §5. |

This intentionally does **not** pre-commit to building (d-hard). (d-soft) + census is enough to make the D
decision; (d-hard) is gated behind a positive surprise.

## (d-hard) — why it's record-and-drop, costed honestly (NON-GOAL for A3)

If anyone later argues for the literal hardware-`,S` convention, here is the bill, so the drop is a measured
decision, not an omission:

- **Missing 65816 `,S` instructions.** Only `(d,S),Y` exists, and only under `Has65CE02`
  (`MOSInstrInfo.td:~509`, `Predicates=[Has65CE02]`). The real WDC 65816 opcodes —
  `LDA d,S` `$A3` / `STA d,S` `$83` / `LDA (d,S),Y` `$B3` / `STA (d,S),Y` `$93` — are **not defined**; they'd
  need new `Inst16` defs under `HasW65816` (`PEA/PEI/PER`, `PHB/PHD/PHK` already exist there).
- **The `SPAdj == 0` blocker.** `,S` offsets are measured from a pointer that *moves* with every push/pull,
  so `eliminateFrameIndex` must thread `SPAdj` through the call-frame pseudos — but it currently **hard-asserts
  `!SPAdj`** (`MOSRegisterInfo.cpp:278`). This is the same blocker the frame study flagged (`:160-164`); it's
  a real, cross-cutting change, not a local one.
- **JSL/RTL coexistence.** Args pushed on `S` sit **above** the 3-byte PBR:PC that JSL pushes, so every
  callee `,S` offset must account for the long-return frame — extra correctness surface.
- **Empirical precedent.** The frame-ABI study built the feasibility + census for hardware-stack-relative
  frames and got **0/13 functions profit → shelved (NULL)**. Different use (args vs locals), same machinery
  and same "locals/values live in `__rc`, not on a stack" reality. Strong prior that (d-hard) is dominated.

Net: (d-hard) is "materially harder than (a) for no plausible win" — the textbook record-and-drop case.

## Workload & gate

- Reuse the **shared variant-agnostic source** `examples/65816/farcc_imag32.c` (a `p2` returned from
  `make_far_ptr()` **and** passed into `deref_far()` across `noinline` calls) — the variant is selected by the
  build flag alone, exactly as (a)/(b)/(c) do.
- `dev/farcc_stack.sh` mirrors `dev/farcc_axy.sh`: negative control (no flag ⇒ does not compile), build
  `+mos-a16 +mos-farcc-stack` `-verify-machineinstrs` clean, size (64 KiB), placement (bank-1 sentinel in
  `$01`), disasm gate (far deref `lda [dp]` a7 + real calls present), MAME exec `corpus_result == 0xF3`; then
  `dev/run.sh xcheck` for the bsnes-jg leg. The disasm gate additionally expects **soft-stack store/load**
  (an RS0-relative or absolute 4-byte spill of the pointer), *not* `,S`.
- For the census: a small multi-far-ptr / many-arg kernel (where a memory convention would plausibly differ
  most from the register poles), measured with the byte harness now and the cycle harness when M builds it.

## Critical files

- `vendor/.../MOS/MOSCallingConv.td` — add the `MOSFarCCStack` CC rule before `CCIfPtr`.
- `vendor/.../MOS/MOSCallingConv.cpp` — `CC_MOS_FarPtrStack` (AllocateStack + one custom mem-loc).
- `vendor/.../MOS/MOSCallLowering.cpp` — the `assignCustomValue` mem-loc branch (reuse `getStackAddress` +
  `assignValueToAddress`, both directions); decide/document the return path.
- `dev/farcc_stack.sh` (new, model on `dev/farcc_axy.sh`), `dev/xcheck.sh` + `dev/run.sh` (+1 variant each),
  `patches/llvm-mos/0004-320-far-cc.patch` (via `dev/regen-patch-0004.sh`).
- **Reference, do not touch for A3:** `MOSInstrInfo.td`/`MOSInstrFormats.td` (the `,S` defs) and
  `MOSRegisterInfo.cpp:278` (`SPAdj`) — only relevant if (d-hard) is ever greenlit.

## Verification

The project **differential** (host == default == variant on MAME + bsnes-jg, `-verify-machineinstrs` clean):

1. **Byte-identical default.** corpus+kernels at `-Os` default & `+mos-a16` unchanged by the A3 add (no
   `+mos-farcc-stack`). PASS = no default regression. (`dev/run.sh corpus` → 7/7; reuse
   `dev/frameabi-byte-identical.sh`.)
2. **Variant correctness.** `dev/run.sh farcc_stack` + `dev/run.sh xcheck`: host == `+mos-farcc-stack` on both
   emulators, including the pass **and** return cases; verify-machineinstrs clean; negative control compiles-fail.
3. **Census table.** far-ptr-call frequency + (a)/(c)/(d-soft) bytes(+cycles) on inner-loop & whole-call.
4. **Patch hygiene.** `dev/regen-patch-0004.sh` round-trips; staged set is exactly the authored files (never
   `vendor/`, `docs/transcripts/`, a foreign patch); `0001` stays a16-free.
5. **Fuzz non-regression.** `dev/run.sh fuzz` clean under the variant (feature off-by-default, so default
   fuzzing is unaffected; a flagged pass is a bonus).

## Out of scope / non-goals

- **(d-hard) the hardware-`,S` convention** — explicitly deferred/record-and-drop (cost documented above);
  needs a separate plan only if the census surprises.
- **No new 65816 `,S` opcodes, no `SPAdj` threading** — both belong to (d-hard).
- **Not** promoting any winner to `0001` here (that's the parent plan's D step) and **not** building the M
  cycle harness here (still net-new; tracked in the parent plan).
- **Not** changing near-ptr/scalar passing or the A/X scalar return (LOCKED).
