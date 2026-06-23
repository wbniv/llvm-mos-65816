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

_(results pasted below each step as the spike runs)_

## Outcome

_(TBD — GO → upstream PR + fork patch + de-XFAIL; NO-GO → record what failed, keep issue-only.)_
