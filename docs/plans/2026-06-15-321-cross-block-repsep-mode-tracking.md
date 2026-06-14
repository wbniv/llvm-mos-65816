# #321 native s16 — cross-block REP/SEP mode-tracking (churn minimization)

**Date:** 2026-06-15 · **Status:** planning → implementing → **DONE** (verified, patch round-trips)

## Context

`MOSInsertREPSEP` (the pass that inserts `rep #$20` / `sep #$20` to set the 65816 M accumulator-width
flag) is currently **per-block and 8-bit-anchored** (its own header calls this the "Increment 1a
minimal" convention): every basic block *starts* in 8-bit mode and is *forced back* to 8-bit before its
terminator (`MOSInsertREPSEP.cpp:124,147-152`). Intra-block it is already sticky — one mode is held
across adjacent 16-bit ops, and M-agnostic ops (`clc`/`sec`, `isMWidthAgnostic`) don't break the run —
so straight-line 16-bit code already collapses to ~one `rep/sep` pair.

The artifact is **cross-block**: a loop with a 16-bit body re-runs `rep … sep` *every iteration*,
because the latch is forced back to 8-bit and the header re-enters 16-bit. Real hand-written 65816 sets
16-bit mode once and stays in it across the whole region/loop, switching only to touch 8-bit hardware.
This increment makes the pass behave that way: **propagate the M mode across the CFG and place switches
only at genuine transitions, hoisting them out of loops.** It's the foundation that makes every per-op
16-bit feature (the ALU/compares already shipped; shifts/inc-dec later) actually pay off.

## Correctness is paramount

A wrong mode at any instruction is a silent miscompile (an 8-bit `lda` under M=0 loads 16 bits, etc.).
Invariants that MUST hold after the pass, on every path:
- The mode at each instruction matches its required width (`MLow` ⇒ 16-bit; non-agnostic non-`MLow`
  ⇒ 8-bit; agnostic ⇒ either).
- **Function entry is 8-bit** (ABI) and **every `call`/return boundary is 8-bit** (the 6502 calling
  convention and 8-bit hardware ABI). Calls mid-function must be in 8-bit mode (callee assumes 8-bit).
- Interrupt-handler entry/exit unaffected (vectors run 8-bit).

## Approach — forward dataflow + transition placement

### Step 1 — per-block transfer facts
For each block B, scan ops (skipping agnostic): record `First[B]` (mode the first mode-requiring op
needs, or *none*), `Out[B]` as a function of entry (= last mode-requiring op's mode, or *passthrough*
if B has none). Treat any op that forces 8-bit (a call, a non-agnostic 8-bit op, the terminator's
implicit 8-bit need) as a hard 8-bit requirement.

### Step 2 — fixpoint for entry modes `In[B]`
Lattice `{⊥ unvisited, M8, M16, ⊤ conflict}`. `In[entry]=M8`. `In[B] = meet(Out[P] for preds P)`,
where a passthrough block forwards `In[P]`. Iterate to fixpoint (loops converge because `Out` is
monotone given `In`).

### Step 3 — place switches at transitions, not block boundaries
- **Inside B**: run the existing intra-block placement but *seeded with `In[B]`* instead of always M8,
  and **don't force 8-bit at exit** unless the terminator/successors require it.
- **On edges P→B** where `Out[P] != In[B]`: insert the switch. Avoid critical-edge splitting by
  placing at end-of-P (if P has one successor) or start-of-B (if B has one predecessor); for true
  critical edges, split the edge (or, conservatively for v1, normalize both sides to M8 at that
  boundary — correct, just not optimal).
- **Conflict (`In[B]=⊤`)**: pick a canonical entry (M8) and let the disagreeing preds carry edge
  switches — always correct.
- **Calls / returns**: force M8 immediately before any call and before returns (re-enter M16 after the
  call only if a following op needs it — the intra-block pass handles that).

### Step 4 — keep the STZ fusion (Increment 1a) as-is; it's independent.

## Scoping for a safe first landing
v1 may **fall back to the current per-block M8 anchoring at any block boundary it isn't sure about**
(conflicts, critical edges) — that's always correct, just leaves some churn. The must-win case is the
**natural loop with a 16-bit body**: `rep` sinks to the preheader, `sep` rises to the exit, the body
stays 16-bit across iterations. Land that, verified, then widen.

## Tests
- `examples/65816/a16loop.c`: a `for`/`while` loop with a 16-bit-accumulator body (e.g. sum a table,
  or `while (i) { acc += step; i--; }`) — assert the loop body has **no per-iteration `rep/sep`** (one
  `rep` before the loop, one `sep` after) and the computed result on **both** MAME and bsnes-jg.
- A second test with a **call inside a 16-bit region** to prove the M8-at-call invariant.
- Regression: corpus 7/7 + all 13 a16* tests green (default/8-bit untouched; the pass is gated on
  `hasAccum16`).

## Verification
1. Build clean. 2. `a16loop` disasm: exactly one `rep #$20` / one `sep #$20` around the loop, none in
the body; correct result both emulators. 3. The call-in-16-bit-region test runs correct (call executes
8-bit). 4. corpus 7/7 + a16 suite green. 5. Patch `0002` round-trips.

## Out of scope (later)
- The X-flag (xy16 / 16-bit index registers) — a separate mode dimension.
- Cross-call mode persistence (a 16-bit calling convention) — the ABI work.
- Optimal critical-edge handling if v1 uses the conservative M8 fallback there.
- Making 16-bit *volatile compare* operands read `abs` directly instead of being
  byte-loaded (`ldx/ldy`) into a zp temp first — a *selection* artifact (a16cmp
  has it too), not a REP/SEP one. It forces an 8-bit toggle inside any loop whose
  test reloads a volatile each iteration (see the a16loop note below).

## What landed

The pass (`MOSInsertREPSEP.cpp`) now:
- classifies each instruction's required width — `requiredWidth()`: `MLow`⇒M16;
  `isReturn`/`isCall`⇒M8 (the ABI boundary); `isBranch` and carry-init⇒agnostic
  (no constraint); everything else⇒M8;
- computes per-block `First`/`Last` facts and a forward-dataflow `In`/`Out` over a
  `{None, M8, M16, Conflict}` lattice. Entry is pinned M8 (ABI); a non-passthrough
  block's `In` is pinned to its `First` (so its entering edges, not an in-block
  switch, deliver the right width); passthrough blocks meet their preds to a
  fixpoint;
- places switches at transitions: **inside** a block via the seeded intra-block
  walk (no forced 8-bit at exit), and **on edges** `P→B` where `Out[P]≠In[B]`
  (end-of-`P` if `P` has one successor, else start-of-`B` if `B` has one
  predecessor);
- **bails the whole function to the legacy per-block M8 anchoring** if any switch
  would land on a true critical edge (source >1 succ AND target >1 pred). v1 does
  not split critical edges — always correct, just leaves the old churn there. The
  must-win loop never hits this.

The STZ store-of-zero fusion (Increment 1a) is unchanged and runs first.

## Evidence (verification steps with raw output)

**1. Build clean.**
```
==> done in 0m 18s: clang version 23.0.0git (...c798c31416f72b395c658b5502d281a162387ab1)
```
PASS — incremental rebuild of the edited pass + relink, exit 0.

**2. `a16loop` disasm: one `rep`/one `sep` around the loop, none in the body; correct on both emulators.**
The loop body is a single all-16-bit block; `rep` hoists to the preheader (0x18),
`sep` sinks past the back-edge (`bcc $1a` at 0x25) to the exit (0x27):
```
      18: c2 20        	rep	#$20
      25: 90 f3        	bcc	$1a <main+0x1a>
      27: e2 20        	sep	#$20
  PASS: exactly one rep #$20 (hoisted to the preheader)
  PASS: exactly one sep #$20 (sunk to the loop exit)
  PASS: no rep/sep inside loop body [0x1a,0x25)
SMOKE: PASS addr=0x7E0204 len=2 got=0x2340 (ran 60 ticks)
  SMOKE: PASS off=0x204 len=2 got=0x2340 (ran 180 frames, bsnes-jg)
RESULT: PASS — 16-bit loop body holds 16-bit mode across iterations (rep hoisted, sep sunk); both emulators read 0x2340
```
PASS. (The loop-carried value and bounds are 16-bit zp *locals*; a value reloaded
from a *volatile* each iteration is byte-loaded — see "Out of scope" — and an 8-bit
counter lives in X/Y, so a16loop loops on the accumulator with the bounds hoisted.)

**3. The call-in-16-bit-region test runs correct (call executes 8-bit).**
```
      1d: e2 20        	sep	#$20      ; 8-bit before the call
      23: 20 00 00     	jsr	$0 <main>
      34: c2 20        	rep	#$20      ; re-enter 16-bit after
  PASS: 8-bit accumulator at the call (jsr)
  PASS: 2 rep / 2 sep — 16-bit work brackets the call
SMOKE: PASS addr=0x7E0204 len=2 got=0x4456 (ran 60 ticks)
  SMOKE: PASS off=0x204 len=2 got=0x4456 (ran 180 frames, bsnes-jg)
RESULT: PASS — call executes in 8-bit mode inside a 16-bit region; both emulators read 0x4456
```
PASS.

**4. corpus 7/7 + a16 suite green.**
```
==> corpus: 7/7 passed
a16 a16add a16sub a16bit a16imm a16chain a16local a16localx a16localsub
a16localbit a16localimm a16loadfold a16cmp  — all RESULT: PASS
a16loop a16call                              — all RESULT: PASS
```
PASS — 13 prior a16* tests + 2 new + corpus 7/7. (corpus builds without `+mos-a16`,
exercising the `hasAccum16()` gate: the pass early-returns, default codegen untouched.)

**5. Patch `0002` round-trips.**
```
==> [verify] diff -rq reapplied MOS dir vs live vendor MOS dir
RESULT: PASS — 0002 round-trips (reapplied MOS dir == live vendor)
```
PASS — regenerated via `dev/regen-patch.sh` (isolated-worktree method).
