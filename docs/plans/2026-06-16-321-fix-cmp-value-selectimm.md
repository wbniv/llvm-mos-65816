# #321 native s16 — fix the compare-result-as-value `SelectImm` crash (F3)

**Date:** 2026-06-16
**Status:** **FIXED (2026-06-16).** Root cause is register allocation, NOT the legalizer (candidate A
disproven — see §Outcome). Fixed by spilling the 16-bit accumulator (`Ac16`) via a direct 16-bit
load/store instead of a COPY through an 8-bit GPR. `dev/run.sh fuzz 50 1` → **50/50 PASS, 0 xfail**
(the 8 formerly-XFAIL seeds all agree host==default==a16 on MAME + bsnes). See **§Resolution**.
**ROADMAP:** step 5 (M2) · **TODO:** M2 "16-bit comparison follow-ups" item (c)
**Predecessor:** [Tier-1 corpus plan](2026-06-15-321-tier1-broaden-corpus.md) (this is its finding **F3**)

## Goal

Make the Tier-1 differential fuzzer go **fully green** — `dev/run.sh fuzz 50 1` → **50/50 PASS, 0 xfail**
(today 42/50 PASS + **8 xfail**, all the `cmp-value-selectimm` known issue). Concretely: a 16-bit
compare whose boolean result is consumed as a **cross-block i1 value** (a stored bool / `G_SELECT` / PHI
under branchy control flow) must stop emitting invalid MIR, on both emulators, with correct values.

## Resolution (2026-06-16): FIXED — spill the 16-bit accumulator via a 16-bit load/store

**One-line fix in `MOSInstrInfo.cpp::loadStoreRegStackSlot`** (the spill/reload path). The static-stack
spill code special-cased `Imag16` (two byte stores of sublo/subhi) and let **everything else fall through
to a single-byte path** that does `GPR = COPY <reg>` then stores one byte. An **`Ac16`** value (the
16-bit accumulator `A16`) hit that fall-through, so spilling it emitted `GPR = COPY A16` — a COPY between
the accumulator and an 8-bit reg, which `copyPhysRegImpl` lowers via its `Anyi1` branch to
`SelectImm $a16` (invalid: `$a16` is not a Flag register) → the F3 crash. The same happened on reload
(`A16 = COPY GPR`), giving the two `SelectImm` errors.

The fix adds an `Ac16` case **before** the `Imag16` case that spills/reloads `A16` with a **single direct
16-bit `STAbs16`/`LDAbs16`** to the frame index — never a COPY through a GPR:

```cpp
if (Ac16 reg) {
  Builder.buildInstr(IsLoad ? MOS::LDAbs16 : MOS::STAbs16)
      .addReg(Reg, getDefRegState(IsLoad) | getKillRegState(IsKill))
      .addFrameIndex(FrameIndex).addMemOperand(MMO);
} else if (Imag16 reg) { /* existing byte-pair spill */ } else { /* existing single byte */ }
```

This restores the documented native-s16 invariant — *"the accumulator is entered/left ONLY via [16-bit]
load/store instructions — never a COPY between Ac16 and an 8-bit reg"* (`MOSInstrLogical.td`). `Ac16`
exists only under `+mos-a16`, so the `HasAccum16`-gated `LDAbs16`/`STAbs16` are always legal at a spill
of an `Ac16` value; `eliminateFrameIndex` rewrites the frame index to a `mos-static-stack` target-index
exactly like the 8-bit `STAbs`; and `MOSInsertREPSEP` (the final pass, after RA + static-stack alloc)
wraps the `MLow=1` op in its own `rep #$20 … sep #$20`. Confirmed in the repro disasm:
`rep #$20; lda <slot>; … ; sta <slot>; sep #$20` for the spill, a 16-bit reload under `rep`, and **no**
`SelectImm`/byte-COPY.

**Scope / known limitation:** the fix covers the **static stack** (used by every `nonreentrant` function,
i.e. the entire fuzz corpus + the repro). The **soft-stack** path (`expandLDSTStk`, for reentrant
functions) likewise only special-cases `Imag16`; an `Ac16` value spilled there would hit the same crash.
That is **pre-existing, not reachable by the corpus**, and harder (the accumulator high byte `B` can't be
byte-addressed without `XBA`), so it is left as a tracked follow-up — it crashes **loudly** under
`-verify-machineinstrs` (never silently miscompiles). [TODO M2].

## Outcome (2026-06-16): the diagnosis that led to the fix — candidate A (legalizer) was the wrong layer

**The plan's root-cause hypothesis below (the legalizer s16 ordering gate lacking the
all-uses-are-`G_BRCOND_IMM` guard) is WRONG.** Candidate A was implemented, tested, and **disproven**;
the change was reverted byte-exact (`0002` round-trips, `git status` clean). The crash is introduced
**after register allocation**, not in the legalizer.

**What candidate A actually did (and why it didn't fix F3):**
- Implemented: gate the native s16 `UGE` path (and the `SLT → ULT` rewrite) on the same
  `all_of(use == G_BRCOND_IMM)` guard the equality path uses, factored into a shared helper
  `s16CmpResultIsBranchOnly`. This is *correct* and produces **clean SSA** — post-instruction-selection
  MIR has no `SelectImm`; the value-consumed compare lowers via a proper control-flow PHI diamond.
- But **all 8 XFAIL seeds (1,7,9,11,22,35,41,44) still crash identically** with the gate applied, and a
  clean `unsigned short r = (a >= b)` (UGE-as-value, no register pressure) **already compiled native and
  valid** without the gate (`cmp $0`, `-verify-machineinstrs` clean). So candidate A would only
  **pessimize** correct code (force UGE/EQ-as-value to the 8-bit chain) **without fixing the crash**.
  Reverted.

**The real root cause (located by walking the pass pipeline on the committed repro):**
- The crash — `$x = SelectImm $a16, -1, 0` / `$a16 = SelectImm $x, -1, 0`, "`$a16`/`$x` is not a Flag
  register" — first appears **after `postrapseudos`** (post-RA pseudo expansion). The
  post-instruction-selection (SSA) MIR is **clean**.
- It is emitted by **`MOSInstrInfo::copyPhysRegImpl`** (`MOSInstrInfo.cpp:743`), the `Anyi1`→`Anyi1`
  copy branch, lowering a COPY whose operands the register allocator placed on the **16-bit accumulator
  `$a16`** and a GPR. I.e. an **i1 (`Anyi1`) value got entangled with the 16-bit-accumulator (`ac16`)
  live range** during coalescing/allocation, so a spill/copy of the accumulator is materialized as the
  i1→GPR `SelectImm` — reading `$a16` as a flag → invalid MIR → segfault in link-time codegen.
- Trigger (from the Two-Address MIR): in the repro, `%128:ac16 = LDAbs16 @in_idx` (the `arr[in_idx & 7]`
  index) is **live across the `f0()` call**. The call clobbers the accumulator, so RA must preserve a
  16-bit accumulator value across the call — and under the **branchy CFG + i1 compare-result pressure**
  of these programs, the spill/coalesce entangles it with an `Anyi1`. A *pure* "16-bit value live across
  a call" reduction (no compares) compiles **clean** — so the i1/branchy pressure is a necessary
  ingredient, but the failure is in **register allocation**, not the compare legalization.

**This is exactly the A16↔8-bit coalescer crash the native-s16 work already fought** (ROADMAP §5,
Increment 1d: "keep `A16` and 8-bit `A` from entangling … always via load/store, never a COPY to/from
8-bit"). The add path *avoided* it by construction; F3 showed it **resurfaces via spill copies** when a
16-bit accumulator value is forced across a call.

**→ FIXED (see §Resolution):** of the two options this diagnosis suggested — prevent the `Anyi1`↔`ac16`
entanglement, or give the `ac16` spill a real 16-bit save/restore — the second is the surgical one. The
`ac16` spill now uses a direct `STAbs16`/`LDAbs16` and never produces the `Anyi1` COPY. Validated on the
full differential gate: the 8 seeds + repro compile clean and `fuzz 50 1` → 50/50, all values agreeing.

## The bug — original (INCORRECT) hypothesis, kept for the record

> ⚠️ **Superseded by §Outcome.** The legalizer analysis below is the hypothesis this pass set out to
> fix; it was **disproven** (the native UGE-as-value path is valid in isolation, and the real crash is a
> post-RA `copyPhysRegImpl`/coalescer entanglement). Read §Outcome first.

Under `+mos-a16`, a 16-bit compare result used as a VALUE (not a branch) materializes via
`SelectImm $a16, -1, 0` (or `SelectImm $y, -1, 0`) — a GPR where the `SelectImm` pseudo requires a
**Flag** (`Cc`/`NZ`) register operand:

```
*** Bad machine code: Illegal physical register for instruction ***
- instruction: $x = SelectImm $a16, -1, 0
$a16 is not a Flag register.
fatal error: error in backend: Found 2 machine code errors.
```

`-verify-machineinstrs` reports it; a normal build **segfaults** in link-time codegen. The default
(non-`+mos-a16`) build of the same source is clean.

**Why:** in `MOSLegalizerInfo.cpp::legalizeICmp` the s16 **ordering** native gate has no guard on how
the result is used, unlike the s16 **equality** gate immediately above it:

- `MOSLegalizerInfo.cpp:1361` `NativeS16EqBranch` — keeps an s16 `ICMP_EQ` native **only when every use
  is `G_BRCOND_IMM`** (the Z flag must fuse into a terminator).
- `MOSLegalizerInfo.cpp:1366` `NativeS16` — keeps an s16 `ICMP_UGE` native **unconditionally** (the
  comment claims "ordering-as-value already goes native, as C is a plain i1" — that assumption is what
  the fuzzer disproved). `ICMP_SLT` reaches this via the `SLT → ULT` sign-flip rewrite at
  `MOSLegalizerInfo.cpp:1311`, and `ULT` canonicalizes to `UGE`.

So an ordering compare feeding a `G_SELECT`/PHI stays native, and the C-flag i1 is mis-selected into
`SelectImm <GPR>`. A prior attempt (2026-06-15, reverted; see the comment at `MOSLegalizerInfo.cpp:1357`)
tried to fold the s16 compare back to native through `buildNZSelect` (`:1267`) → `G_SELECT` and it did
**not** work — the value path narrows in the select lowering.

**Minimal repro (committed):** `examples/65816/a16spill.c` (was `known/a16-cmp-value-selectimm.c`; delta-reduced from
fuzz seed 1). Bare `r = (a == b)` does NOT trigger it; the branchy CFG that turns the result into a
cross-block value does. The 8 fuzz seeds that XFAIL today: **1, 7, 9, 11, 22, 35, 41, 44**.

## Approach (two candidates — both legalizer-level; see §Outcome — A disproven)

> ⚠️ Both candidates below target the **legalizer**, which §Outcome shows is the **wrong layer** for F3.
> Candidate A was implemented and reverted (it pessimizes correct code without fixing the crash).
> Candidate B (materialize the flag into a value natively) would face the *same* post-RA coalescer
> entanglement. The real fix is in register allocation / `copyPhysRegImpl`.

### ~~A — conservative: narrow ordering-as-value to the 8-bit chain~~ (DISPROVEN — see §Outcome)

Mirror the equality guard onto the ordering path: keep an s16 `UGE` (and the `SLT → ULT` rewrite)
native **only when every use is `G_BRCOND_IMM`**; otherwise fall back to the existing 8-bit byte-compare
narrowing (the default path, which correctly produces an i1 in a GPR — no `SelectImm <GPR>`). Touch:

- `MOSLegalizerInfo.cpp:1366` — gate `NativeS16` for `UGE` on the same `all_of(use_instructions(Dst),
  … == G_BRCOND_IMM)` predicate used by `NativeS16EqBranch` (1361). Factor the predicate into a helper.
- `MOSLegalizerInfo.cpp:1311` — the `SLT → ULT` sign-flip rewrite: only fire it when all uses are
  branches too, so an `SLT`-as-value narrows directly via the default signed path instead of emitting
  the `eor #$8000` XORs and then narrowing the `ULT`. (If leaving it unguarded still produces correct
  code — XOR'd operands through the 8-bit chain — that's acceptable; verify either way.)

Trade-off: a compare whose result is a value (rare — the micro-tests all branch on their compares)
regresses to 8-bit. **Correctness over optimization** — this kills the crash and is the safe landing.
Watch the `SelectImm $y` variant in the repro: confirm it also comes from the s16 path (so the guard
fixes it) and not a separate 8-bit select issue; if separate, investigate that path too.

### B — optimal (harder, optional follow-up): materialize the flag into a value natively

Keep ordering/equality-as-value native by lowering the s16 compare's C/Z flag to a 0/1 value correctly
— either a `SelectImm` that reads the real **flag** register (not the accumulator), or a
compare→branch→`0/1` materialization at selection. This is what the reverted 2026-06-15 attempt was
reaching for; only pursue it after A lands green, and keep it gated/reversible.

## Verification

> **Two passes are recorded here.** First, the evidence that **candidate A (legalizer) FAILED** — kept
> because it's *why* the diagnosis moved to register allocation. Then the **Ac16 spill fix verification
> (all PASS)** below. Final results are in *Verification results — the Ac16 spill fix*.

### Candidate A (legalizer gate) — DISPROVEN

**Step 1 — repro compiles clean under `-verify-machineinstrs` (candidate A applied):**

```
$ mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
    -mllvm -verify-machineinstrs -c examples/65816/a16spill.c   # (then known/a16-cmp-value-selectimm.c)
  $x = SelectImm $a16, -1, 0
  $a16 = SelectImm $x, -1, 0
*** Bad machine code: Illegal physical register for instruction ***
$a16 is not a Flag register.
fatal error: error in backend: Found 2 machine code errors.        # exit 1
```
**FAIL** — identical crash to pre-fix. All 8 seeds (1,7,9,11,22,35,41,44) still crash identically with
the gate. First bad MIR appears after `postrapseudos`; SSA-Selected MIR is clean. **F3 is a register-
allocator bug (`copyPhysRegImpl:743`), not the legalizer gate — candidate A reverted, XFAIL kept.**

**Control — native UGE-as-value is already valid without the gate** (so candidate A only pessimizes):
```
$ printf 'volatile unsigned short a,b,corpus_result;int main(void){unsigned short r=(a>=b);corpus_result=r;for(;;){}}' \
  | mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
    -mllvm -verify-machineinstrs -x c -c -        # exit 0, disasm uses native `cmp $0`
```
**PASS (clean) — confirms the native path is correct in isolation; the crash needs register pressure.**

**Revert is byte-exact:** `dev/regen-patch.sh` → `RESULT: PASS — 0002 round-trips`; `git status patches/`
empty.

### Verification results — the Ac16 spill fix (all PASS, 2026-06-16, quiet box)

1. **Repro + all 8 seeds compile clean under `-verify-machineinstrs`** (was: 2 machine-code errors each);
   default build stays clean. Repro + seeds 1,7,9,11,22,35,41,44 → all exit 0. **PASS.**
2. **Committed regression test:** the repro moved out of `known/` → `examples/65816/a16spill.c` +
   `dev/a16spill.sh` (`dev/run.sh a16spill`). Compile-time gate (the bug is invalid MIR, not a wrong
   value — the value side is the de-XFAIL'd fuzzer): asserts `+mos-a16 -verify-machineinstrs` clean, that
   the body still emits the `Ac16` spill (`STAbs16/LDAbs16 $a16, %stack.0` — 2 ops found), and default
   clean. → `RESULT: PASS`. **PASS.**
3. **De-XFAIL'd the fuzzer** (`KNOWN_ISSUES = []` in `tools/a16_fuzz.py`, so the signature hard-FAILs
   again). `dev/run.sh fuzz 50 1` → `50/50 PASS, 0 known-issue (xfail) (0 mismatch, 0 new-crash, 0 error)`.
   Spot-checks: seed 1 → `0x525C (all agree)`, seed 7 → `0x9447 (all agree)`
   (host==default==a16@MAME==a16@bsnes). **PASS.**
4. **Non-breaking:** `==== a16+kernels suite: 40 PASS, 0 FAIL ====` (32 a16* + 6 kernels + 2
   combinatorial), `dev/run.sh corpus` → `7/7 passed`. **PASS.** (a16spill adds a 41st test.)
5. **`dev/regen-patch.sh` round-trips** (`RESULT: PASS — 0002 round-trips`); the fix is in `0002`. **PASS.**

## The fix in one place

`MOSInstrInfo.cpp::loadStoreRegStackSlot` (static-stack branch): add an `Ac16` case **before** the
`Imag16` case that spills/reloads the 16-bit accumulator with a single direct `LDAbs16`/`STAbs16` to the
frame index, instead of falling through to the single-byte path that emits `GPR = COPY A16` →
`SelectImm $a16`. Six-line change; see §Resolution.

**Follow-up (tracked, not blocking):** the soft-stack spill path (`expandLDSTStk`, reentrant functions)
has the same `Imag16`-only gap for `Ac16` — pre-existing, unreachable by the (nonreentrant) corpus, and
harder (the accumulator high byte needs `XBA` to byte-address). It crashes loudly under verify, never
miscompiles. [TODO M2].
