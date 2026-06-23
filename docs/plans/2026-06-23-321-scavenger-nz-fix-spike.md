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

## Outcome — NO-GO for a narrow fix (issue stays issue-only; now better-evidenced)

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
