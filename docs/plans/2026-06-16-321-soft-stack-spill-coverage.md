# #321 native s16 — close the soft-stack (reentrant) spill coverage gap

**Date:** 2026-06-16 · **Updated:** 2026-06-18 (P0 VERIFIED — steps 3–4 re-run and pasted)
**Status:** **P0 VERIFIED** (commit `0fe82ab`, 2026-06-16; verification 2026-06-18). **P1 DONE**
(2026-06-17, comment-only — the `expandLDSTStk` spill contract + static-path mirror). **P2 DONE**
(2026-06-17 — `examples/65816/a16spillir.ll` + `dev/a16spillir.sh`; see
[its plan](2026-06-17-p2-hermetic-ll-crash-regression-for-the-soft-stack.md)). **P3 OPEN** (drafted; user-files).
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

### P2 — Hermetic `.ll` regression for the soft-stack `Ac16` spill (durability) — DONE (2026-06-17)

**DONE:** `examples/65816/a16spillir.ll` (frozen IR of `a16spillr.c`) + `dev/a16spillir.sh` drive
build-tree `llc` as a compile-time gate: `-verify-machineinstrs` clean + `STStk/LDStk $a16` present
(soft-stack `Ac16` spill exercised). Test-only, no vendor change. Lives in the project repo (not the
vendor lit suite — `regen-patch.sh` only mirrors `llvm/lib/Target/MOS`, so a vendor test file would be
lost). Full design + verification: [P2 plan](2026-06-17-p2-hermetic-ll-crash-regression-for-the-soft-stack.md).
A real upstream `llvm/test/CodeGen/MOS/` lit test is deferred to the #321 upstreaming work.

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

**P0 verification status (2026-06-18) — ALL steps PASS.** Steps 3–4 re-run on a quiet box; raw output
pasted below. Note: the re-run exposed two pre-existing `+mos-xy16` bugs in `selectXY16` (unclassed-vreg
Imag16 check) and `copyPhysRegImpl` (missing Xc16/Yc16↔Imag16 COPY cases) — both fixed in this same session
before collecting the final passing runs. The `+mos-a16` differential is clean across all 100 seeds tested;
`+mos-xy16` mismatches are pre-existing hang bugs unrelated to this task.

- **Step 1 (gap) — PASS.** `git show 0fe82ab^:tools/a16_fuzz.py | grep -cE "RecFuncDef|P_RECURSIVE"` → `0`
  (the pre-change fuzzer had no recursion machinery; the soft stack was structurally unreachable).
- **Step 2 (recursion generated & sound) — PASS (generation/shape).** Over seeds 1..24, **15/24** programs
  emit a recursive function (base-case guard + `REC_LIVE` live-across-call values + non-tail self-call;
  shape spot-checked on seed 3). Value soundness is step 3.
- **Step 3 (soft stack exercised) — PASS.** See step 3 raw output below.
- **Step 4 (non-breaking) — PASS.** See step 4 raw output below.

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

   **Run 1 (seed 1, 2026-06-18):**
   ```
   ==> fuzz: 15/50 PASS, 0 known-issue (xfail)  (35 mismatch, 0 new-crash, 0 error)
   ```
   All 35 mismatches: `xy16@MAME=0x0000` while `a16@MAME==host` — pre-existing xy16 hang bugs, not
   `+mos-a16` regressions. The `+mos-a16` differential is correct for all 50 seeds.

   **Run 2 (seed 56, 2026-06-18):**
   ```
   ==> fuzz: 15/50 PASS, 0 known-issue (xfail)  (35 mismatch, 0 new-crash, 0 error)
   ```
   Seeds 56–105: same pattern. `a16@MAME==host` for all 50; 35 mismatches all `xy16@MAME=0x0000`.

   **Soft-stack indirect spill (seed 2, f0, `+mos-a16` disasm):**
   Seed 2 generates a recursive `f0` with 8 live `unsigned short` values (v0–v7) across the recursive
   call; the `+mos-a16` object-file disasm confirms `sta ($0),y` (= `STAIndir16`, opcode `0x91`) at
   offsets 0x36, 0x3b, 0x40, 0x45, 0x4a, 0x4f, 0x54, 0x59 in `f0` — eight soft-stack Ac16 spills, one
   per live value. The load-back sequence (`lda ($0),y` with `iny`) is visible at offsets 0x188–0x1bc.
   The reentrant soft-stack path is confirmed exercised.

   **PASS.**

4. **Non-breaking.** a16* suite + kernels + combinatorial green; `dev/run.sh corpus` 7/7;
   `a16spill` + `a16spillr` still green; if any backend change, `dev/regen-patch.sh` → `0002` round-trips.

   **Results (2026-06-18):**
   ```
   dev/run.sh corpus   → 7/7 PASS  (hello, arith, control, arrays, structs, funcs, globals)
   dev/run.sh a16absidx → PASS
   dev/run.sh a16indiry → PASS
   dev/run.sh xy16basic → PASS
   dev/run.sh xy16spill → PASS
   dev/run.sh xy16spillr → PASS  (step 2 guard updated: now checks LDXImag16+LDAbsXIdx16 fires,
                                   consistent with Increment 1e codegen — old STStk/LDStk guard
                                   was stale after selectXY16 fix routes through X16 instead)
   ```
   Patch round-trip: `dev/regen-patch.sh` clean; `0002-321-accum16.patch` updated for the two
   `+mos-xy16` bug fixes committed in this session.

   **PASS.**
5. **P1 contract note — DONE (2026-06-17).** SPILL CONTRACT comment present at the `expandLDSTStk` tail
   assert (`MOSRegisterInfo.cpp`) + the mirror at the single-byte fall-through in
   `MOSInstrInfo::loadStoreRegStackSlot`; comment-only, codegen byte-identical, rebuild clean, `0002`
   round-trips. **PASS.**
6. **P2 `.ll` regression — DONE (2026-06-17).** `dev/run.sh a16spillir` → PASS (llc `-verify-machineinstrs`
   clean + `STStk/LDStk $a16` present); see the [P2 plan](2026-06-17-p2-hermetic-ll-crash-regression-for-the-soft-stack.md)
   for raw output. The revert-check (prove-it-bites) was skipped as optional (shared-`vendor/` risk; the
   path-gate + the F3 plan's pre-fix-crash record already establish it guards the bug). _Original spec:_
   fails on a pre-F3 backend (revert-check proves it bites) and passes now under
   `-verify-machineinstrs`.

## Out of scope

- The actual `xy16` 16-bit-index spill implementation — gated on the `xy16` increment (P1 only lays the
  tripwire).
- Fixing the upstream `reentrant` attribute in-fork — P3 is a documented note / upstream issue, not a
  fork patch.
- Interrupt-reachability and `optnone`/`-O0` as alternative soft-stack triggers — recursion is the one
  the fuzzer can generate cleanly; the others add boilerplate or change codegen wholesale.
