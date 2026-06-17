# #321 — fix the seed-42 default-build miscompile (an `0002` `legalizeICmp` EQ-swap leaked into the non-a16 path)

**Date:** 2026-06-18
**Status:** **IMPLEMENTED + VERIFIED** (committed `51a5bae`). One-line codegen fix in `0002`
(`MOSLegalizerInfo.cpp`); regenerated patch + TODO/plan updates.
**ROADMAP:** step 5 (M2) — correctness defect in the `+mos-a16` patch series, surfaced by the Tier-1
differential fuzzer.
**Context:** discovered during the [A/X-return plan](2026-06-17-321-ax-return-convention.md) verification
(`dev/run.sh fuzz 50 1` came back 49/50). Triage history: [TODO Done `321-seed42-legalizeicmp-swap`](../../TODO.md).

## The defect

The Tier-1 fuzzer's **seed 42** (`dev/run.sh fuzz 1 42`) computed `corpus_result = 0xB226`, but the correct
value is **`0xEC0D`** — and the wrong value appeared in **both** the default 8-bit build **and** the
`+mos-a16` build (and on bsnes-jg). Two independent oracles agreed on the correct value: the fuzzer's
exact-16-bit Python model **and** the *unpatched upstream* `mos-clang` (default 8-bit) on real MAME. So the
defect was in **our committed patches**, in a code path the **default (non-a16) build also takes** — i.e.
**not** `+mos-a16`-specific, and unrelated to the A/X return convention it was found alongside.

This is the canonical violation of **governing lesson #2**: an `+mos-a16` change must be gated so a
misclassification only ever *misses a win*, never *regresses the default path*. Here a `+mos-a16` helper
leaked into the 8-bit path and corrupted a comparison.

## Root cause

`MOSLegalizerInfo::legalizeICmp` performs an EQ **operand canonicalization** (for the native-s16 EQ fold
that puts the Imag16-resident value on the LHS and the foldable absolute global on the RHS). There are two
swaps. The **second** is correctly gated on `NativeS16Eq` (which is `hasAccum16 && Type==S16 &&
Pred==ICMP_EQ && …`). The **first** was guarded only by `ComputedVsGlobal`:

```cpp
// BEFORE (buggy):
if (ComputedVsGlobal && isFoldableAbsS16Load(LHS) && isImag16Resident(RHS))
  std::swap(LHS, RHS);
```

`ComputedVsGlobal` is defined purely from the operand shapes (`isImag16Resident` / `isFoldableAbsS16Load`)
— it does **not** require `hasAccum16`, and the swap has **no `Pred == EQ` check**. The swap is only valid
for EQ (whose `Z` is symmetric: `a-b==0 ⟺ b-a==0`). So in the **default 8-bit build**, a **non-EQ** compare
(`<` / `>`) whose operands happened to be a computed-s16 value vs. a foldable absolute global hit
`std::swap(LHS, RHS)` and **reversed the comparison operands** → `a < b` became `b < a` → wrong branch →
wrong `corpus_result`. (seed-42 is dense with signed/unsigned 16-bit `<`/`>` over computed values and
`arr[...]` globals, so it triggered.)

## The fix (one line)

Gate the first swap on `NativeS16Eq`, exactly like the second — so it only fires in the intended
native-`+mos-a16` EQ-canonicalization path, where EQ's `Z`-symmetry makes the swap safe:

```cpp
// AFTER (fixed):
if (NativeS16Eq && ComputedVsGlobal && isFoldableAbsS16Load(LHS) &&
    isImag16Resident(RHS))
  std::swap(LHS, RHS);
```

`vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp`, regenerated into
`patches/llvm-mos/0002-321-accum16.patch` via `dev/regen-patch.sh` (round-trips; only `MOSLegalizerInfo.cpp`
changed; no foreign hunks; F4 stays in `0003`).

## How it was localised — isolated `git worktree` + ccache-reuse build bisection

The bug was **codegen-state-sensitive** (only the full seed-42 program triggered it; `f0`/`f1` standalone
were correct) and produced **byte-identical post-legalize MIR**, so MIR diffing alone could not find it. It
was bisected by building patch *subsets* in isolation and running the seed-42 differential on each:

- A detached **`git worktree` of `vendor/llvm-mos` at pristine upstream** + selectively `git apply`-ed
  patch hunks, built into a **separate** `build/` dir (never touching the shared `build/llvm-mos`),
  **reusing the warm `build/.ccache`** so each incremental rebuild was minutes, not the 30–90 min cold
  build. The unpatched `/opt/llvm-mos` in the dev container served as the correct-value oracle.

Bisection result (seed-42 default 8-bit `corpus_result`; `0xEC0D` = correct):

| toolchain | seed-42 | |
|---|---|---|
| upstream (no patches) | `0xEC0D` | clean |
| upstream + **register topology only** (`A16`/`B`/`Ac16` + bank) | `0xEC0D` | **topology innocent** |
| upstream + `0001` + `0002`-td + feature-infra | `0xEC0D` | td/instr-defs innocent |
| + `0002` selector `.cpp` | `0xEC0D` | selector innocent |
| + `0002` `InstrInfo`/`LateOpt`/`RegisterInfo` | `0xEC0D` | post-RA innocent |
| + unconditional `MOSInsertREPSEP` pass | `0xEC0D` | pass innocent (early-exits `!hasAccum16`) |
| + `0002` legalizer **constructor rules** | `0xEC0D` | rules innocent |
| + `0002` `legalizeICmp` | **`0xB226`** | **← the culprit** |
| full `0002` **minus** the un-gated swap (the fix) | `0xEC0D` | **fixed** |

Two earlier attributions were **wrong and corrected along the way**: (1) "concurrent agent's `vendor/`
edits" — refuted (vendor HEAD is pristine upstream; the `M` files in `git -C vendor status` *are* the
applied patches), and (2) "the register topology perturbs default RA" — refuted (`upstream + topology →
0xEC0D`). The lesson: **bisect with builds; do not trust a plausible mechanism story.**

## Verification (run on a quiet box; raw output below each step)

1. **seed-42 differential fixed.** `dev/run.sh fuzz 1 42` → `corpus_result` host == default == `+mos-a16`
   on MAME + bsnes-jg.

```
==> a16 differential fuzz: 1 program(s), seeds 42..42
  [ ok ] seed    42  0xEC0D (all agree)
==> fuzz: 1/1 PASS, 0 known-issue (xfail)  (0 mismatch, 0 new-crash, 0 error)
```

**PASS** — was `host=0xEC0D, default@MAME=a16@MAME=a16@bsnes=0xB226`; now all `0xEC0D`.

2. **No regression — full Tier-1 suite.** a16* + kernels suite, corpus, `fuzz 50 1`.

```
### suite total: pass=50 fail=0 failed=[] ###
==> corpus: 7/7 passed
==> a16 differential fuzz: 50 program(s), seeds 1..50
==> fuzz: 50/50 PASS, 0 known-issue (xfail)  (0 mismatch, 0 new-crash, 0 error)
```

**PASS** — a16 suite 50/50, corpus 7/7, `fuzz 50 1` 50/50 (was 49/50; seed 42 now green).

3. **a16 EQ-canonicalization still works (the fix preserves the native fold).** `a16eqvalmg` (computed vs
   global EQ — the test that exercises the `ComputedVsGlobal` swap under `+mos-a16`).

```
a16eqvalmg +mos-a16 : got=0x0111  (want 0x0111)
  a16eqvalmg verify: CLEAN
  a16eqvalmg native cmp-long (cf): 2  (ComputedVsGlobal fold intact)
```

**PASS** — `0x0111`, `-verify-machineinstrs` clean, the `cmp` long-addressing fold (`CmpBrImagAbs16`) is
still emitted — the swap still fires correctly in the native-a16 EQ path.

4. **`0002` regenerated cleanly.** Only `MOSLegalizerInfo.cpp` changed; no foreign hunks; round-trips.

```
RESULT: PASS — 0002 round-trips (reapplied MOS dir == live vendor)
```

**PASS** — `git diff patches/llvm-mos/0002-*.patch` shows exactly the swap-gate change (+ mechanical hunk
offsets); only the `MOSLegalizerInfo.cpp` index hash changed; `grep -c 'TXY\|TYX'` = 0 (F4 not absorbed).

## Regression guard

The standing **Tier-1 differential fuzzer** is the guard: seed 42 is in the deterministic `fuzz 50 1` run
(now 50/50), so the exact reproducer is exercised on every fuzz pass. Re-run `dev/run.sh fuzz 50 1` after
any future `legalizeICmp` / EQ-canonicalization / native-s16 change.

## Lessons (folded into `docs/agent-handoff.md`)

- **Gate *every* `+mos-a16` change — including operand canonicalizations, not just instruction selection.**
  An EQ-only operand swap with no `hasAccum16`/`Pred==EQ` guard silently corrupted the default 8-bit path.
- **The differential fuzzer catches default-build regressions from `+mos-a16` work**, because it compiles
  each program *both* ways and compares to host. A green a16 suite is not enough.
- **Bisect vendor changes with isolated `git worktree` + ccache-reuse builds** when MIR diffing is
  inconclusive (state-sensitive bugs, byte-identical post-legalize IR). Build subsets; trust the build, not
  the story.

## Out of scope

- No change to the A/X return convention (its plan is test+docs-only and unaffected).
- The native-s16 EQ fold itself is unchanged for `+mos-a16` (the fix only stops the swap from firing when
  the feature is off / the predicate is non-EQ).
