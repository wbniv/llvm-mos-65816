# Patch 0029 — independent review (Claude)

Second, independent review of Codex's register-exhaustion fix, done 2026‑09‑22
against the same pinned llvm-mos revision `742d554bf08042b8df93d791c335260fadd16643`.
Scope: the patch, its two tests, the PR draft, and the recorded validation.
Verdict first, evidence after. This is not maintainer feedback.

**Verdict: ready to post.** The diagnosis is right, the guard is minimal and
provably regression-free on its own terms, and the tests discriminate. Two
things were changed as a result of this review, both small: the guard no longer
counts reserved class members as available registers, and its comment now says
what actually happens. The material gap was validation breadth (a 231-test
regex selection instead of the full CodeGen suites); that is closed below with
the complete X86, ARM, AArch64 and MOS suites on the revised patch.

Revised patch: `c2c962311fc40a43d570f141ef0ba6240b317952456bea17c56c1f90066ced88`
(Codex's reviewed hash was `1b0aee74…`).

## What I verified myself

| Claim | How | Result |
|---|---|---|
| The C reproducer fails on the unpatched compiler | project clang `-O2 -emit-llvm` on `mixed-width-call.c`, then the unpatched `build/upstream-llc/bin/llc -O2 -verify-machineinstrs` | `ran out of registers during register allocation in function 'stage'` |
| …and compiles with the patch | same IR through `build/register-exhaustion-build/bin/llc` and the project clang at `-O1/-O2/-Os` | clean, exit 0 |
| The MIR test discriminates | ran `twoaddr-reschedule-physreg.mir` (LiveVariables and LiveIntervals) through the unpatched and both patched llc builds | unpatched FAIL ×2, patched PASS ×4 |
| The patch is what was tested | `git diff` in `build/register-exhaustion-src` reproduces `patches/llvm-mos/0029-*.patch` byte for byte; the assertion build's source matches the hunk | sha256 `1b0aee74…` on both sides |
| Nothing leaked into 0002 | `grep -c "Extending a physical definition" patches/llvm-mos/0002-*.patch` on the dirty working copy | 0 |
| 0028 is not in the candidate | `git status` in `build/register-exhaustion-src` | only `TwoAddressInstructionPass.cpp` modified; 0028 tests untracked, its source hunk absent |
| Current-upstream applicability | `gh api repos/llvm-mos/llvm-mos/compare/742d554…main` | `status=identical, ahead_by=0`: the pinned base **is** upstream main today; the patch also applies clean (`git apply --check`) on the `~/llvm-mos` clone that carries newer LLVM merges |

## The C++ change

The guard sits inside the existing dependency loop of
`rescheduleKillAboveMI`, before the use/def split, so it sees every register
operand of every instruction the kill will jump over, including `MI` itself.
For a virtual operand it asks whether every physical register of that operand's
class overlaps a live physical definition of the instruction being moved. If
so, the move is refused.

**Why this is the right predicate.** After the move, each of `KillMI`'s live
physical definitions is live-through every crossed instruction (a crossed
redefinition of it is already rejected by the existing `OtherDefs` check). A
virtual operand at a crossed instruction must occupy a register of its class at
that point, live-through or not, dead def or not. If every member of the class
is one of those live-through physical registers, no assignment exists and
spilling cannot manufacture one. So every move the guard refuses is a move that
would necessarily have failed allocation. That is the strongest possible form of
"a gate must only ever miss a win, never cause a regression": it cannot miss a
win at all, because there was no allocatable outcome to win.

**Cost.** `all_of` short-circuits on the first non-overlapping member, so for
any ordinary class it stops after one or two probes; the expensive
all-overlap path only runs when the move is about to be refused. The check is
also gated on `!LiveDefs.empty()`, which is the rare case (a kill that is a
copy into a physical register, or a non-copy kill with live implicit defs).

**Placement matches the pass's own conventions.** It uses the existing
alias-aware `regOverlapsSet`, uses `LiveDefs` rather than `Defs` (a dead
physical def only occupies the register at the moved instruction, never across
the crossed ones), and calls `MRI->getRegClass` unconditionally exactly as
`isProfitableToConv3Addr` and `processTiedPairs` already do in this file.

### Findings and what was done

1. **Reserved registers counted as "available" — fixed.** The class iteration
   included reserved members (on MOS: `RS0`, `RS8`, `RS16+`), which the
   allocator never hands out, so a class whose only non-overlapping members are
   reserved would have slipped through. The lambda now returns
   `MRI->isReserved(PhysReg) || regOverlapsSet(LiveDefs, PhysReg)`. This can
   only add refusals, and every added refusal is still a necessarily-failing
   move, so the zero-regression argument is unchanged. `isReserved` asserts that
   reserved registers are frozen; both instruction selectors and the MIR parser
   freeze them before this pass runs, and every `-run-pass` and full-pipeline
   invocation below exercises that path under assertions.
   It is **not directly testable on MOS**: a movable kill with more than one
   live physical def does not exist here (`isSafeToMove` refuses inline asm
   outright, checked in `MachineInstr.cpp`; I built the 14-def inline-asm MIR to
   try and the pass never reaches the guard), and no MOS class has "one
   allocatable member plus reserved ones". The existing three MIR cases and the
   IR test cover the predicate; the reserved clause is covered by the argument
   above and by the full suites not changing.
2. **Pre-existing physical liveness is not modelled — stated, not fixed.** The
   guard only counts registers made live by *this* move. A class exhausted by
   one register from this move plus another already live across the crossed
   instruction is not caught. On `mos6502` this is unreachable in practice:
   every folded-load two-address `MI` has an `Ac` tied operand, so a hoist of
   `$a` is always refused, and the only other hoistable argument copies are
   `$x` / `$rcN`, whose crossed temporaries (`GPR`, `Imag8`) keep spare members.
   Modelling it means teaching the two-address pass register pressure across
   the block, which is a much larger patch than this fix warrants; the PR
   description now says so in one paragraph.
3. **Comment wording — fixed.** "Extending a physical definition across a
   constrained virtual register" read as if the vreg were being extended; it now
   says "across an instruction with a constrained virtual operand" and
   "every unreserved member of its class".

## The tests

- **MIR test** (`twoaddr-reschedule-physreg.mir`): three well-chosen shapes,
  the refused `$a` hoist, the still-permitted `$x` hoist past a `GPR`
  temporary, and the intervening constrained `Yc` index. The middle case is the
  important one: it proves the guard is not "disable rescheduling". Both liveness
  analyses are exercised. Good.
- **IR test** (`mixed-width-call.ll`): its `CHECK`s are weak (`jsr ext` /
  `rts`), but that is fine here: lit runs with `pipefail`, so the crash itself
  fails the test, and the point is reachability from IR, not the schedule.
- **Placement.** MOS-only tests are correct for llvm-mos. If this ever goes to
  llvm/llvm-project instead, the MIR would need a port to an in-tree target with
  a singleton class, and the argument in the PR would need an X86-style example.

## Validation of the revised patch

Codex's evidence was honest about its limits: 131 MOS tests, and a 231-test
X86/ARM/AArch64 selection chosen by filename regex plus a grep for
`twoaddressinstruction`. That selection was the weak point. The guard fires on
any two-address instruction whose kill is a copy into an argument register,
which is a shape scattered across the *whole* CodeGen suite, not just tests
named `twoaddr*` or `coalesc*`. So the complete suites were run, in the same
`llvm-mos-65816-dev` container, on the assertion-enabled
`build/0029-cross-target-build` (X86, ARM, AArch64, MOS) rebuilt from
`build/register-exhaustion-src` with the revised patch, and on the release
`build/register-exhaustion-build` candidate through Codex's own mounts.

| Suite | Compiler | Result |
|---|---|---|
| `test/CodeGen/X86` + `ARM` + `AArch64`, complete | assertions on | 11,459 discovered: 11,408 pass, 23 expectedly fail, 28 fail in the first pass |
| those 28 | assertions on | all exit‑127 tool gaps (`llvm-readelf` ×27, `llvm-lto2` ×1); after adding the alias and building the tool, 28/28 pass |
| `test/CodeGen/MOS` + `test/MC/MOS` | assertions on | 131 pass, 1 unsupported, 2 excluded (the untracked 0028 tests) |
| `test/CodeGen/MOS` + `test/MC/MOS` | release candidate | 131 pass, 1 unsupported, 2 excluded |
| C reproducer, `-O0…-Oz` × {plain, `-mllvm -verify-machineinstrs`} | release candidate clang | 12/12 |
| bundled MIR test, LiveVariables and LiveIntervals, plus `-start-before` leg | both revised builds / unpatched | PASS ×6 / FAIL ×2 (ordering), verifier clean everywhere |
| reproducer IR at `-O2 -verify-machineinstrs` | both revised builds / unpatched | OK / `ran out of registers` |

**Net: zero codegen failures across 11,459 + 132 tests; every failure in the
first pass was a helper tool the minimal build had not linked.** The first
full-suite run on Codex's unrevised hash gave the same picture (11,376 pass,
60 tool-gap failures: `split-file` ×37, `llvm-readelf` ×22, `llvm-nm` ×1), so
the reserved-register clause changed no test outcome, as expected.

Artifacts, all under `build/0029-claude-review/` (untracked): `run*.sh` (the
exact container scripts), `run*.log`, `lit-codegen.json` (unrevised),
`lit2-codegen.json`, `lit2-mos-assert.json`, `lit2-mos-release.json`,
`lit3-subset.json`, `lit4-lto2.json`, `matrix2.txt`, `patch2.sha256`,
`llc2-version.txt`. The project toolchain (`build/llvm-mos-install`) was
rebuilt from the edited `vendor/` tree so the installed clang carries the
revised guard.

## Process notes

- The repo commit `e5d20bb` carries no tool-attribution trailer; the PR draft
  does (`Assisted-by:`), which is what llvm-mos's `AIToolPolicy.md` asks for.
  Fine as is.
- The PR draft, simulated review, preview HTML, TODO entry and both upstream
  tracker docs were left edited but uncommitted by Codex (drop the demo link,
  add the attribution, restate remaining steps). They are all 0029-only hunks
  and are committed together with this review and the revised patch.
- The project toolchain rebuild first failed at `install-llvm-mc`: eight files
  under `build/llvm-mos{,-install}` were root-owned from a Sep 20 container run,
  so `file INSTALL cannot set permissions`. Ownership was reset through the
  container and the install rerun.
- The dirty `dev/toolchain.sh` hunk (apply 0028) belongs to the separate 0028
  work and is left alone.

## Recommendation

Post it. The PR draft already carries the refined guard description, the
stated limitation, the full-suite numbers and both `Assisted-by:` trailers.
