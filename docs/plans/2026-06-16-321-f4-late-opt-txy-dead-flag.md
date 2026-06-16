# #321 F4 — fix the `mos-late-opt` TYX/TXY dead-flag crash (upstream llvm-mos bug)

**Date:** 2026-06-16
**Status:** **FIXED + VALIDATED (2026-06-16).** Repro + seeds 10/16 compile clean; `fuzz 50 1` → **50/50**
(both emulators, values agree); the `mos-late-opt` lit test passes (existing CHECKs corrected + 2 new
regression cases); non-breaking suite green; patch `0003` round-trips. **Upstream PR ready** — awaiting the
user-triggered submit.
**ROADMAP:** step 5 (M2) · **TODO:** M2 "soft-stack spill coverage" item (this is finding **F4**)
**Found by:** [P0 soft-stack spill coverage](2026-06-16-321-soft-stack-spill-coverage.md) — the fuzzer
recursion feature, on its first run (seeds 10 & 16). Validates that plan's thesis: the under-exercised
reentrant path harbored a real bug.
**Cousin of:** [F3](2026-06-16-321-fix-cmp-value-selectimm.md) (also a register-level codegen crash, also
`+mos-a16`-pressure-triggered — but F3 was the Ac16 spill; this is an upstream peephole).

## The bug

A recursive (reentrant) `+mos-a16` function crashes the backend under `-verify-machineinstrs`:

```
*** Bad machine code: Using an undefined physical register ***
- instruction: $y = TX $x
```

The **default (non-`+mos-a16`) build of the same program is clean**, and the program is valid (host-gcc
== the fuzzer's oracle). 2/50 fuzz seeds hit it (10, 16); both in recursive functions.

## Root cause (upstream, not #321)

`MOSLateOptimization::combineLdImm` (`MOSLateOptimization.cpp`) is a per-block peephole that tracks the
known immediate value in A/X/Y and rewrites `LD_ #imm` into a register transfer/`INC`/`DEC` when another
register already holds the value. After any such rewrite, a shared cleanup block runs:

```cpp
if (Load) {                                     // Load = the SOURCE register's tracked def
  Load->MI->getOperand(0).setIsDead(false);     // the source value is now USED -> un-dead its def
  for (...) J.clearRegisterKills(...);          // and not killed before the new use
}
```

Every transfer rewrite sets `Load` to its source so this runs — `TXA`/`TYA` (`Load=&LoadX/Y`),
`TAX`/`TAY` (`Load=&LoadA`). But the **W65816 `TYX`/`TXY` branches forgot to assign `Load`**, so for
`$y = LDImm k → $y = TX $x` the cleanup is **skipped**. When the source `$x` came from a `dead $x = LDImm k`
(a dead constant rematerialized by RA — common in the reentrant soft-stack reload chains), its def keeps
the `dead` flag while the new `TX` adds a use → the verifier sees `$x` used past a dead def → "undefined
physical register."

It is **upstream llvm-mos** code: `MOSLateOptimization.cpp` is pristine in `vendor/` (only
`MOSSubtarget.h` carries #321 edits), and the branch blames to upstream `c798c3141` (the maintainer's
W65816 support). `+mos-a16` is merely the *trigger* — its wider-accumulator pressure produces the
`dead $x = LDImm` + same-value `$y = LDImm` reload pattern; the bug is reachable by any W65816 code that
does. The `mos-late-opt` pass is only added to the pipeline under the #321 toolchain (patch `0002`
registers it), which is why we see it now.

## The fix (2 lines)

Set `Load` to the transfer **source** in both W65816 branches, exactly like every sibling rewrite, so the
existing dead-flag/kill cleanup runs:

```cpp
if (Dst == MOS::X && LoadY.MI && LoadY.Val == Val) {
  Load = &LoadY;                                 // <-- added (TYX source is Y)
  MI.setDesc(TII.get(MOS::TX)); ...
} else if (Dst == MOS::Y && LoadX.MI && LoadX.Val == Val) {
  Load = &LoadX;                                 // <-- added (TXY source is X)
  MI.setDesc(TII.get(MOS::TX)); ...
}
```

This extends the source register's live range from its `LDImm` to the new transfer (un-dead + clear kills)
— correct because the value is now genuinely used, and safe because nothing redefines the source in
between (verified in the repro MIR).

**Landing — upstream-first.** This is an upstream bug, so the fix goes to `llvm-mos/llvm-mos` as a proper
PR (clean branch off upstream `main`, the 2-line fix + an LLVM lit test, validated). Our fork carries the
*same commit* as `patches/llvm-mos/0003-late-opt-txy-dead-flag.patch` — a carrier referencing the PR, not a
private workaround — only until it merges upstream, at which point we drop `0003` and bump the vendor pin.
`gh` is authed as `wbniv` (repo scope); fork `wbniv/llvm-mos` to be created. Opening the public PR is the
one user-triggered step (per the #320 upstream-posting norm); everything up to it is automated.

## Verification (the spec — run, paste raw output, mark PASS/FAIL)

1. **Repro compiles clean.** `ctrl.c` (hand-derived from seed 16) + fuzz seeds 10 & 16 under
   `+mos-a16 -verify-machineinstrs` → exit 0 (was: `Bad machine code: $y = TX $x`). Default build stays
   clean.
2. **The peephole still fires.** A `$y = LDImm k` with a live `$x = LDImm k` still becomes `$y = TX $x`
   (the fix preserves the optimization, only repairs liveness) — confirm a `TX` is still emitted in a
   non-dead case and the dead-source case now carries a non-dead `$x` def.
3. **Fuzz gate green.** `dev/run.sh fuzz 50 1` → 50/50 PASS, 0 new-crash / 0 mismatch (the new recursive
   corpus, formerly 2 crashers, now all clean and value-correct on MAME + bsnes-jg).
4. **Non-breaking.** a16* suite + `dev/run.sh corpus` 7/7 + `a16spill`/`a16spillr` still green.
5. **Patch round-trips.** `dev/regen-patch.sh` (extended for `0003`) → round-trips; `git status
   vendor/` clean after.

### Verification results (2026-06-16, rebuilt toolchain) — all PASS

1. **Repro clean.** `ctrl.c`, `faithful16.c`, fuzz seeds 10 & 16 under `+mos-a16 -verify-machineinstrs`
   → all exit 0 (was: `Bad machine code: $y = TX $x`). Default build stays clean. 50-seed compile sweep:
   `clean=50 crash=0` (was 48+2). **PASS.**
2. **Peephole preserved.** Seed 16's `+mos-a16` asm still emits a `txy`/`tyx` (count=1) — the rewrite
   still fires, only its liveness is repaired. The lit test's `ldimm_to_txy`/`tyx` still produce
   `$y = TX $x` (with the stale `killed` now cleared). **PASS.**
3. **Fuzz gate green.** `dev/run.sh fuzz 50 1` → `50/50 PASS, 0 known-issue (0 mismatch, 0 new-crash,
   0 error)` — host == default == `+mos-a16` on MAME + bsnes-jg across the recursive corpus. **PASS.**
4. **Non-breaking.** `dev/run.sh corpus` → 7/7 (incl. recursive `funcs`); `a16spillr` (soft-stack Ac16,
   0x3457 both emus), `a16spill` (F3 guard), `a16localx` (0x33A0), `a16localbit` (0x000F) → all PASS.
5. **Lit test + patch.** `update_mir_test_checks.py` regen of `late-opt-65816.mir`; `llc -run-pass=
   mos-late-opt -verify-machineinstrs | FileCheck` → **PASS** (the 2 new dead-source cases verify clean —
   they error on pre-fix code). `0001+0002+0003` apply cleanly on pristine `c798c3141` (round-trip PASS).

## Regression guard

Commit a dedicated regression alongside the fix: either a hermetic `.ll` lit test (a `$y = LDImm k` with
a `dead $x = LDImm k` source under W65816 → must emit a valid `TX` with a non-dead `$x`), or fold the
recursive C repro into the suite. The fuzzer's de-crashed seeds 10/16 are the broad guard; a pinned test
is the narrow one.

## Out of scope

- The other P0 follow-ups (P1 `expandLDSTStk` contract note, P2 `.ll` durability, P3 `reentrant`
  upstream note) stay in the [parent plan](2026-06-16-321-soft-stack-spill-coverage.md).
- Upstreaming the PR to llvm-mos is user-triggered (like the #320 note).
