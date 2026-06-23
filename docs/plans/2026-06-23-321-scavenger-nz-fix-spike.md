<!-- HISTORY: snapshots in docs/plans/.history/ (regen-md-history hook). -->

# #321 scavenger N/Z crash — spike a fix (turn the issue into issue+fix, like #561→#563)

**Status:** SPIKE IN PROGRESS (2026-06-23) · **Issue:** #321, ROADMAP M2 · upstream defect.
**Goal:** the user asked to try a real fix even though the prior verdict said "issue-only, maintainer
territory." Even a shared-code fix is worth proposing — the maintainer reviews/refines/rejects it; a tested
patch beats a bug report. If the spike yields a differential-clean fix → it becomes a **PR with the fix**
(referencing the scavenger issue, like #563 did for #561). If it confirms the structural mess → record
exactly what was tried + why it failed (which strengthens the upstream issue), keep issue-only.

Worktree: `wt/scavenger-nz` (compiler-changing, warm-build copy; retain/teardown per outcome).

## Root cause (confirmed this spike, deeper than the issue body)

`f0` (a16, `-Os`) has many `STStk`/`LDStk` frame-slot accesses interleaved with a `CMPImag16` whose N/Z
stay live. `scavengeFrameVirtualRegs` rematerializes a carry-class frame vreg (`%NN.subcarry:pc = LDCImm
0`) and **picks `$p` (the status register) as the scratch to spill**. Scavenger debug trace:

```
Scavenged register with spill: $p until undef %29.subcarry:pc = LDCImm 0
```

`saveScavengerRegister` for `P`: `UseHardStack = (Reg==P) && pushPullBalanced(I,UseMI)`. At this site the
range is **unbalanced** (net pushes from the frame spill) → `UseHardStack=false` → falls through to the
illegal `STImag8 $rc17, $p` ("$p is not a GPR register", verifier-rejected; asserts build aborts earlier at
`assertNZDeadAt` because **N is live**). `canSaveScavengerRegister(P)` returns `pushPullBalanced(I,UseMI)`
but **never checks N/Z liveness**, so it green-lights a P spill the save path cannot legally honor.

## Hypothesis under test (attempt 1 of ≤3)

Make the `P` gate conservative: `canSaveScavengerRegister(P)` returns true only when the range is
push/pull balanced **and** N/Z are dead at both the save (`I`) and restore (`UseMI`) points. Add a
non-asserting `nzDeadAt()` helper (factored out of `assertNZDeadAt`) and use it in the gate. Rationale: a
misclassification can then only ever *miss* a P scavenge (the scavenger picks a different register or spill
point), never emit an illegal P spill — the project's "gate conservatively; never regress" principle.

**Risk being tested empirically:** if P is the *only* candidate at that site, refusing it may turn the
miscompile into a different fatal ("ran out of registers" / "scavenge failed"). The spike answers whether a
viable alternative exists.

## Verification

1. **Crash gone (release):** `mos-clang --target=mos -mcpu=mosw65816 +mos-a16 -Os -mllvm
   -verify-machineinstrs -c examples/65816/a16scavnz.c` compiles clean (no `$p is not a GPR register`).
2. **Crash gone (asserts):** same TU on the asserts build does not abort at `assertNZDeadAt`.
3. **No new fatal:** neither build reports "ran out of registers" / "scavenge failed" / any other backend
   error on the repro.
4. **No regression:** `dev/run.sh corpus` 7/7; the a16 micro-suite green; a fuzz pass (`dev/run.sh fuzz
   50 1`) 0-mismatch — in particular the 8 formerly-XFAIL'd scavenger seeds
   (169/173/196/268/271/272/306/420) now compile clean.
5. **XPASS guard:** if fixed, `dev/run.sh known-issues` will flip the `scavenger-p-not-gpr` repro from
   "still reproduces" to XPASS — so the `KNOWN_ISSUES` entry + `a16scavnz.c` gate get updated (de-XFAIL).

### Step 1 — release `-verify` on `a16scavnz.c`

```
fatal error: error in backend: Scavenger spill for register not yet implemented.
  llvm::RegScavenger::spill → scavengeRegisterBackwards → scavengeFrameVirtualRegs
Register:                       (empty name — a flag/carry-class pseudo, not a GPR)
```

**FAIL (informative).** The illegal `STImag8 $p` is gone (the gate refused P), but the scavenger then falls
through to the `default:` arm of `saveScavengerRegister` — `report_fatal_error("Scavenger spill for register
not yet implemented")` — on a **nameless flag/carry-class register**. So refusing P does not let the
scavenger find a legal alternative; it just relocates the failure.

(Steps 2–5 not run: step 1 already shows the hypothesis does not yield a clean compile.)

## Attempt 2 — mark `LDCImm` rematerializable (user asked to keep trying)

The scavenged value is `%N.subcarry = LDCImm 0` (carry constant). `MOSImmediateLoad` sets
`isAsCheapAsAMove`/`isMoveImm` but **not** `isReMaterializable` (the sibling `LDImm1` flag-load explicitly
does). `LDCImm` lowers to `CLC`/`SEC` — reads nothing, writes only C (not N/Z) — so it is trivially
remat-safe (unlike `LDImm` = `LDA/LDX/LDY #imm`, which writes N/Z, so the flag can't go on the base class).
Added `let isReMaterializable = true;` to `LDCImm` only. Rebuilt (bit confirmed in
`MOSGenInstrInfo.inc`: `LDCImm … |Rematerializable|CheapAsAMove`).

**Result: the crash *signature changes but does not clear.*** The illegal `STImag8 $p` is gone, but the
scavenger now hits the **same** `report_fatal_error("Scavenger spill for register not yet implemented")` on
the **same nameless flag-class register** as attempt 1. So both a "refuse P" gate and "rematerialize the
carry" converge on the identical wall: at this site the scavenger must free a flag/carry-class register that
MOS's `saveScavengerRegister` has **no implementation to spill**.

(The `LDCImm`-rematerializable change is arguably a real latent upstream improvement on its own — it matches
`LDImm1` and is remat-safe — but it does **not** fix this crash, so it is not proposed as the fix and was
not landed/differential-tested.)

## Outcome — NO-GO for a narrow fix (issue stays issue-only; now better-evidenced)

Two principled, independently-reasoned patches (attempt 1 = the conservative `canSaveScavengerRegister(P)`
N/Z gate; attempt 2 = `LDCImm` rematerializable) both move the symptom but fail at the same wall. **Attempt 3
(diagnostic, not a fix)** instrumented `saveScavengerRegister`'s `default:` arm to name the dead-end
register:

```
Register: '' num=0 RC=Ac        (num=0 = MOS::NoRegister; class = Ac, the accumulator)
```

**This is the decisive finding.** After both fixes peel off the illegal-`P`-spill symptom, the scavenger is
asked for an **accumulator-class (`Ac`) scratch and finds none to scavenge** — it passes `NoRegister`. That
is **register-pressure exhaustion**, not a localized scavenger bug: under `+mos-a16` the 16-bit values
saturate the tiny MOS register file, leaving nothing for the frame-index scavenger to free. It is the **same
root cause** as the project's already-deferred `regalloc-out-of-registers` / `a16-zp-pressure-overflow`
known-issues — the **Phase-3 `+mos-a16` Ac16/ZP-residency rework**
([docs/investigations/65816-a16-regalloc-pressure-failure.md](../investigations/65816-a16-regalloc-pressure-failure.md)),
explicitly deferred as a major undertaking.

So the honest #2 conclusion: **there is no bounded scavenger patch.** The illegal-`P`-spill is a *symptom*
of a16 register pressure; fixing the spill path just surfaces "no register to scavenge." The real fix is the
deferred Phase-3 pressure rework (reduce a16 register pressure / ZP-residency so the scavenger always has a
free accumulator), which is the large, separate effort already on the backlog — not landed here, not
unreviewed. The 8 fuzz seeds stay XFAIL'd + XPASS-guarded; the issue is filed as the upstream report
(strengthened with both tested dead-ends). Three hypotheses spent → conclusion reached, per the debugging
limit. `wt/scavenger-nz` reverted to pristine; dead-end spike → teardown (durable artifact = this plan).

The conservative `canSaveScavengerRegister(P)` N/Z gate — the safest possible local patch — **dead-ends**:
at the failing site *every* register the scavenger can pick is unsaveable. P has no legal soft spill
(`STImag8 $p` illegal) and can't take the hard-stack bracket across the unbalanced range; the only other
candidate is a flag/carry-class pseudo with **no `saveScavengerRegister` implementation at all**. So the
defect is not in the gate — it is that MOS asks the scavenger to free a register in a flag-live, unbalanced
context where the target has **no legal way to spill anything**.

A real fix therefore lives in shared, regression-sensitive territory — one of:
1. **Implement a flag-preserving P save that tolerates an unbalanced range** (PHP at `I` + a stack-relative
   restore at `UseMI` accounting for the net push count) — fragile, and the observed double-P-scavenge
   (`PH $p` "using an undefined physical register" alongside the `STImag8 $p`) shows the reserved RC17 slot
   already collides across the two scavenge events.
2. **Change how MOS models the flag/carry-class vreg** (`%NN.subcarry:pc = LDCImm 0`) so a frame access in a
   flag-live context doesn't force scavenging an unsaveable register in the first place.

Both are core MOS scavenger/frame-lowering changes across all subtargets — **maintainer territory**, exactly
as the 2026-06-19 verdict held. This spike *confirms* that verdict with a concrete tested negative, which is
the durable win: the upstream issue can now state "the conservative N/Z gate on
`canSaveScavengerRegister(P)` does not work — it dead-ends the scavenger on a flag-class pseudo with no
spill impl; the fix must address [1]/[2]." That is materially stronger maintainer guidance than the original
issue.

**Disposition:** the in-worktree gate edit is **not landed** (it doesn't fix the bug). Keep the issue
**issue-only** (`docs/321-upstream-scavenger-nz-issue.md`); fold this tested-negative into its "Likely fix
directions" if/when posting. `wt/scavenger-nz` is a **dead-end spike** → teardown
(`dev/worktree-teardown.sh scavenger-nz`); the durable artifact is *this plan*. The 8 fuzz seeds stay
XFAIL'd + XPASS-guarded as before — nothing changes in-fork.
