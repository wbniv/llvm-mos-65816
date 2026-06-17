# #321 native s16 — close the soft-stack (reentrant) spill coverage gap

**Date:** 2026-06-16 · **Updated:** 2026-06-17 (P0 landed + folded in from the standalone P0 plan)
**Status:** **P0 IMPLEMENTED** (commit `0fe82ab`, 2026-06-16) — verification **PROVISIONAL**, a genuine
quiet-box differential re-run is pending (see *P0 verification status* under Verification). **P1/P2/P3 OPEN.**
**ROADMAP:** step 5 (M2) · **TODO:** M2 "soft-stack spill coverage" item
**Predecessor:** [F3 plan](2026-06-16-321-fix-cmp-value-selectimm.md) — the `Ac16` spill fix (static + soft)
this builds on · [Tier-1 fuzzer plan](2026-06-15-321-tier1-broaden-corpus.md) — the harness this extends.

## Why this exists (the gap the F3 fix exposed)

F3 fixed the `Ac16`-spilled-across-a-call crash on **both** stacks: static (`loadStoreRegStackSlot`,
direct `STAbs16`/`LDAbs16`) and soft/reentrant (`expandLDSTStk`, indirect `STAIndir16`/`LDAIndir16`).
But the **soft-stack** half was found and proven only by a **hand-written recursive reproducer**
(`examples/65816/a16spillr.c`), never by the differential fuzzer. The reason is structural and worth
stating precisely, because it is the whole motivation here:

- A function uses the **soft stack** iff it does **not** carry the `nonreentrant` IR attribute
  (`MOSFrameLowering::usesStaticStack`, `MOSFrameLowering.cpp:46` — `staticStack() && !optnone &&
  hasFnAttribute("nonreentrant")`).
- `MOSNonReentrant` stamps `nonreentrant` onto **every** function it can prove non-recursive
  (`MOSNonReentrant.cpp:127`: `if (F.doesNotRecurse() && !Reentrant.contains(...)) addFnAttr`). Its
  `Reentrant` escape set is seeded **only** from interrupt reachability and libcalls — never from any
  source attribute.
- `__attribute__((reentrant))` does **not** help: at the front end it emits no IR marker, only
  suppressing the global `-fnonreentrant` default (`CodeGenModule.cpp:2988`), and the pass overrides it
  regardless. So the **only** reliable soft-stack triggers are: genuine **recursion** (`callsSelf`,
  `MOSNonReentrant.cpp:154`), mutual recursion (multi-node SCC), reachability from an `interrupt`
  handler, or `optnone`/`-O0`.
- The fuzzer generates **none** of these. `tools/a16_fuzz.py::gen_funcs` (line 475) emits 1–2 functions
  whose bodies are `expr(pure=True)`, and `pure=True` **excludes the `call` leaf** (line 398–399). So
  generated callees are leaves; the call graph is `main → {f0,f1}`, strictly acyclic → every function is
  non-recursive → **all get static frames**. The soft-stack spill/reload paths (`expandLDSTStk`) receive
  **zero** differential coverage.

Net: the path that carried a real crash for the entire life of the `+mos-a16` work is the one path the
fuzzer cannot reach. This plan closes that.

## Goal

Give the soft-stack spill path the same differential guarantee the static path already enjoys —
`corpus_result` agreeing host == default(8-bit) == `+mos-a16` on **both** MAME and bsnes-jg, plus
`-verify-machineinstrs` — by making the fuzzer generate **recursive** functions; and turn the F3
discoveries into durable structure so the next soft-stack spill bug is caught at design time, not as a
register-scavenger crash in link-time codegen.

## Work items (priority order)

### P0 — Teach the fuzzer to emit recursion (the coverage fix) — **LANDED (commit `0fe82ab`, 2026-06-16)**

The centerpiece, now implemented + committed. `tools/a16_fuzz.py` mints genuinely **recursive** functions,
so generated programs land on the soft/reentrant stack and exercise `expandLDSTStk` under the differential
oracle. As-built (`RecFuncDef` + `gen_funcs`):

- **Generator** (`gen_funcs`): each generated function is recursive with probability `P_RECURSIVE = 0.5`.
  Body = base-case guard `if (p0 == 0) return <pure>;`, then `REC_LIVE ∈ [5,8]` values `vN` — **each
  anchored by a distinct volatile input** so the read can't sink past the call — then a non-tail
  `__attribute__((noinline))` self-call `r = fN((unsigned short)(p0 - 1u), …)`, then
  `return COMBINE(v0..v{k-1}, r)`. The `>4` values live across the call exhaust the 4 hard-stack CSR slots →
  the (reentrant) caller spills to its **soft** frame: `STStk`/`LDStk` → `expandLDSTStk` (the F3 `Ac16`
  path). `noinline` + non-tail keep `fN` recursive → reentrant → soft stack.
- **Bounded & sound:** the recursion-counter arg is a small constant `randint(2,4)` (`call_args`), depth
  ≤ 4; `MAX_EVAL_DEPTH = 64` guards the host oracle. `State.call` mirrors the base case + decrement so the
  Python evaluator predicts `corpus_result` exactly; `program()` guarantees every recursive `fN` is invoked
  and XOR-folded into `corpus_result` (no DCE; always under the oracle). UB-free + deterministic, same
  discipline as the existing generator.
- **Effect:** soft-stack spills of `Ac16` (indirect `STAIndir16`/`LDAIndir16`), `Imag16` (byte-pair split
  through the stack pointer), and 8-bit values across the recursive call now get **value-level**
  differential coverage on both emulators — catching wrong-value bugs, not just the already-fixed crash.
- **Byproduct — F4:** P0's first run surfaced a pre-existing **upstream** `mos-late-opt` crash (a
  `LDImm`→TYX/TXY rewrite that skipped dead/kill-flag cleanup → verifier "undefined physical register" on
  reentrant `+mos-a16` code), fixed as `patches/llvm-mos/0003-late-opt-txy-dead-flag.patch`. Tracked by the
  [F4 plan](2026-06-16-321-f4-late-opt-txy-dead-flag.md), not this one.

### P1 — Document & guard the `expandLDSTStk` spill contract (latent xy16 tripwire) — DONE (2026-06-17)

**DONE:** added the SPILL CONTRACT comment at the `expandLDSTStk` tail assert (`MOSRegisterInfo.cpp`,
above `assert(Loc == C || V || Anyi8…)`) and mirrored it at the single-byte fall-through `else` in the
static path (`MOSInstrInfo::loadStoreRegStackSlot`). Both state: every spillable ≥16-bit class needs its
own explicit case above (Ac16 → 16-bit indirect/`LDAbs16`-`STAbs16`; Imag16 → byte-pair split), the
fall-through is 8-bit-only, and `xy16` (native 16-bit index, the X-flag dimension) is the latent next one
that would hit the F3 crash class and must gain a case. Comment-only — codegen byte-identical; rebuild
clean, `0002` round-trips. The actual index-16 spill case stays deferred to the `xy16` increment.

`expandLDSTStk` (`MOSRegisterInfo.cpp:418`) handles exactly three spill classes — `Ac16` (indirect,
:479), `Imag16` (byte-pair split, :489), and `Anyi8`/`C`/`V` (generic indirect-indexed, :523) — and
**asserts** at :528 that anything reaching the tail is one of `C`/`V`/`Anyi8`. **Any other ≥16-bit
register class spilled here crashes.** Today nothing else is spillable, so it is latent — but the moment
native 16-bit **index** (`xy16` / the X-flag dimension, TODO M2 "re-evaluate the X-flag mode dimension")
lands, a 16-bit X/Y value live across a call hits :528 as a scavenger crash, the exact shape of F3.

- Cheap, now: add a contract comment at `MOSRegisterInfo.cpp:528` — "every spillable ≥16-bit reg class
  needs an explicit case **above** this assert; `xy16` index-16 is the next one" — and mirror it in the
  static path (`MOSInstrInfo.cpp::loadStoreRegStackSlot`, where the `Imag16`/`Ac16` cases live). No
  behaviour change; this is a design-time tripwire + cross-link so the `xy16` increment picks it up.
- Defer the actual index-16 spill case to the `xy16` increment (it cannot be built or tested until
  `xy16` exists).

### P2 — Hermetic `.ll` regression for the soft-stack `Ac16` spill (durability)

The current soft-stack regression (`examples/65816/a16spillr.c`) is excellent for the runtime
differential check but depends on the front end + optimizer continuing to (a) keep the recursion and
(b) place the value in `Ac16` across the call. Add a minimal **`llc`-level `.ll`** lit test — a function
**without** `nonreentrant`, an `Ac16` value live across a call, under `-verify-machineinstrs` — as a
hermetic crash-regression immune to front-end/optimizer drift. Complements, does not replace, the C
test. (Same rationale the F3 plan used to keep both a compile-gate and the fuzzer value-check.)

### P3 — Upstream note: `reentrant` cannot force the soft stack (optional, low priority, not #321) — **DRAFTED 2026-06-17**

**Issue draft written + verified against the current vendor source (all four pivot points quoted from real
code): [`docs/321-upstream-reentrant-soft-stack-issue.md`](../321-upstream-reentrant-soft-stack-issue.md).
Filing is user-triggered; no fork patch (issue only).** The forward note (now superseded by that draft):

Record the finding for upstream llvm-mos: `__attribute__((reentrant))` emits no IR marker
(`CodeGenModule.cpp:2988` only suppresses the `-fnonreentrant` global default) and `MOSNonReentrant`
re-derives `norecurse` and stamps `nonreentrant` regardless (`:127`), so the attribute **cannot** force
the soft stack for an ordinary non-recursive function. This is not a miscompile for ordinary C (a
provably single-activation function is safe with a static frame), but it is a **latent footgun** for
code that is reentrant only via a mechanism the IR call graph cannot see — an **inline-asm-installed
ISR** or **manual coroutine / stack switching** — which would silently get a static frame that gets
clobbered. If ever needed, the fix is small and localized: seed the pass's `Reentrant` set from a
positive `"reentrant"` IR attr (emitted by clang from `ReentrantAttr`) at the top of `run()`. **Action:
file an upstream issue**, do not carry a fork patch. Out of scope for #321; tracked here so it is not
re-discovered from scratch.

## Verification (the spec — run, paste raw output under each step, mark PASS/FAIL)

**P0 verification status (2026-06-17) — steps 1–2 PASS (fresh, no-box); steps 3–4 PROVISIONAL, pending a
genuine quiet-box re-run.** A first quiet-box run was launched but **aborted** when a concurrent toolchain
build made the box non-quiet (concurrent MAME load flakes the settle window → false failures; abort-early).
What we have so far:

- **Step 1 (gap) — PASS.** `git show 0fe82ab^:tools/a16_fuzz.py | grep -cE "RecFuncDef|P_RECURSIVE"` → `0`
  (the pre-change fuzzer had no recursion machinery; the soft stack was structurally unreachable).
- **Step 2 (recursion generated & sound) — PASS (generation/shape).** Over seeds 1..24, **15/24** programs
  emit a recursive function (base-case guard + `REC_LIVE` live-across-call values + non-tail self-call;
  shape spot-checked on seed 3). Value soundness is step 3.
- **Step 3 (soft stack exercised) — PROVISIONAL.** The aborted run reached `fuzz 50 1` **seed 10/50, all
  "all agree"** before kill; commit `0fe82ab` claims the full `fuzz 50 1 → 50/50`
  (host==default==+mos-a16 on MAME + bsnes-jg) with the `Ac16` soft-spill exercised. **TODO: re-run
  `dev/run.sh fuzz 50 1` + a second seed on a quiet box, spot-check a recursive program's a16 disasm for the
  soft-stack indirect spill, and paste here.**
- **Step 4 (non-breaking) — PENDING.** Commit `0fe82ab` claims corpus 7/7 + a16spill/a16spillr green +
  `0001+0002+0003` round-trip. **TODO: re-run the a16 suite + `dev/run.sh corpus` on a quiet box and paste
  here.** (No backend delta in P0 — the patch round-trip is inherited from `0fe82ab`.)

Steps 5–6 below are P1/P2 and are not yet started. The original spec follows verbatim:

1. **Establish the gap (pre-change).** Generate a batch and confirm the current fuzzer emits **no**
   recursion: `python3 tools/a16_fuzz.py` over ~200 seeds, assert no generated function body contains a
   call to itself or another `fN` (grep the emitted C / inspect the AST). Expect: 0 recursive programs.
2. **Recursion is generated & sound (post-change).** Over a fresh seed sweep, confirm a meaningful
   fraction of programs contain a recursive function, **each still compiles** DEFAULT + `+mos-a16`, and
   the **host evaluator agrees** with both builds (no UB, no divergence, no Python-side runaway).
3. **Soft stack is actually exercised.** `dev/run.sh fuzz 50 1` (and a second fresh seed) → all PASS, 0
   mismatch / 0 new-crash / 0 error; **spot-check a triaged recursive program's `+mos-a16` disasm shows a
   real soft-stack spill** — `STAIndir16`/`LDAIndir16` (Ac16) or the byte-pair via the stack pointer
   (Imag16) — i.e. proof the reentrant path ran, not just that the suite is green.
4. **Non-breaking.** a16* suite + kernels + combinatorial green; `dev/run.sh corpus` 7/7;
   `a16spill` + `a16spillr` still green; if any backend change, `dev/regen-patch.sh` → `0002` round-trips.
5. **P1 contract note — DONE (2026-06-17).** SPILL CONTRACT comment present at the `expandLDSTStk` tail
   assert (`MOSRegisterInfo.cpp`) + the mirror at the single-byte fall-through in
   `MOSInstrInfo::loadStoreRegStackSlot`; comment-only, codegen byte-identical, rebuild clean, `0002`
   round-trips. **PASS.**
6. **P2 `.ll` regression** fails on a pre-F3 backend (revert-check proves it bites) and passes now under
   `-verify-machineinstrs`.

## Out of scope

- The actual `xy16` 16-bit-index spill implementation — gated on the `xy16` increment (P1 only lays the
  tripwire).
- Fixing the upstream `reentrant` attribute in-fork — P3 is a documented note / upstream issue, not a
  fork patch.
- Interrupt-reachability and `optnone`/`-O0` as alternative soft-stack triggers — recursion is the one
  the fuzzer can generate cleanly; the others add boilerplate or change codegen wholesale.
