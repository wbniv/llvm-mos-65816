# Investigation: `+mos-a16` has no s32 (`long`/`int32_t`) legalization in s16-interacting shapes

**Date:** 2026-06-19 · **Status:** **DONE** — **(a) implemented + verified** (see *RESULT*). The investigation
below established there is **no minimal "B"**: the correctness fix *is* the s32-under-a16 feature. Landed on the
`main` checkout (`vendor/llvm-mos` edited in place → `0002`); the csmith-branch XFAIL is removed separately.
**Issue:** #321, ROADMAP M2.
**Found by:** the Csmith differential fuzzer (`wt/321-csmith`, 10/100 seeds, e.g. seed 11) — XFAILed there as
`a16-unmerge-s32`. See [csmith plan](2026-06-19-321-csmith-differential-fuzzer.md) §Phase 1–3 RESULT.

## Symptom

`+mos-a16` aborts the backend on valid C that uses `int32_t`/`long` in shapes where the i32 interacts with a
16-bit value (e.g. truncating an i32 to i16). The **default 8-bit build compiles the same program clean.**
```
LLVM ERROR: unable to legalize instruction: %_(s16), %_(s16) = G_UNMERGE_VALUES %_(s32) (in function: main)
```
Fast deterministic repro: Csmith seed 11, compile-time (`-fno-lto -c`) under `+mos-a16`. The trigger is the
CRC fold `low16(crc) ^ high16(crc)` (a `trunc i32→i16`) under i32 register pressure — bare one-liners optimize
to bytes and don't hit it, so any regression test must be a **frozen `.ll`** (the `a16spillir.ll` precedent).

## Root cause — confirmed

`MOSLegalizerInfo.cpp`. The relevant rules only know **s16/ptr ↔ s8 bytes**:
```cpp
G_TRUNC          .legalFor({{S1,S8},{S1,S16},{S8,S16}})          // no s32->s16
G_ANYEXT/G_ZEXT  ...                                              // no s8->s32 etc.
G_MERGE_VALUES   .legalForCartesianProduct({S16,P},{S8,PZ})       // no 2×s16->s32
G_UNMERGE_VALUES .legalForCartesianProduct({S8,PZ},{S16,P})       // no s32->2×s16
```
**Why default works but a16 doesn't:** default narrows *every* s32 op to **s8** (maxScalar S8), so an s32 is
always 4×s8 bytes and the artifact combiner extracts pieces — no s32↔s16 boundary ever forms. Under `+mos-a16`
**s16 is a legal type**, so `narrowScalar` of a wide op stops at **s16** (it cannot step past a legal type down
to s8). That diverts s32 into **2×s16** pieces — and the s32↔s16 (un)merge / trunc / ext machinery that this
requires **does not exist** (neither in the legalizer nor the selector).

## Finding: there is no minimal "B" (route-through-s8) fix — it cascades into the A foundation

Measured, not assumed (each step = one ~15 s incremental rebuild + seed-11 recheck):

1. `.lower()` the wide-scalar `G_UNMERGE_VALUES` → error moves to **`G_TRUNC s32→s16`** (the generic
   `lowerUnmergeValues` expands to `trunc`/`lshr`, and trunc s32→s16 is itself unsupported).
2. Make `G_UNMERGE/G_MERGE`/`G_TRUNC` s32↔s16 **legal** → error moves to **`G_ANYEXT s8→s32`**. Unlocking each
   s32 op just exposes the next (anyext → then zext/sext → …).
3. The selector can't absorb it either: `selectMergeValues` is hardcoded 2×s8→s16 (`composePtr`/`LDImm16`);
   there is no s32 register class, so an s32 value cannot be a selected value — it must be fully decomposed
   into s16/s8 pieces *with selector support for those splits/merges*, which is absent.

You **cannot** force s32→s8 under a16 (the conventional cheap fix) because making **s16 legal structurally
stops narrowing at s16**. So correct i32-under-a16 requires implementing s32↔s16 across `G_TRUNC`, `G_ANYEXT`,
`G_ZEXT`, `G_SEXT`, `G_MERGE_VALUES`, `G_UNMERGE_VALUES` **plus** matching selector support — i.e. the **core
of "approach A" (native 16-bit i32)**. The correctness fix and the optimization are the *same* work here.

## Decision: (a) — implement s32-under-a16 (chosen by the project owner, 2026-06-19)

Build the s32↔2×s16 path so `+mos-a16` handles `int32_t`/`long` correctly (and gains the 16-bit-chunk i32
codegen — the M2 "optimizing payoff"). The correctness fix and the optimization are the same work here.

## Implementation phases (each gated by a rebuild + seed-11 recheck; correctness gated by the differential)

- **P1 — Legalizer artifacts.** Make the s32↔s16 boundary ops legal/lowered under a16 so legalization
  completes: `G_TRUNC s32→s16`, `G_ANYEXT/G_ZEXT/G_SEXT` to/from s32, `G_MERGE_VALUES 2×s16→s32`,
  `G_UNMERGE_VALUES s32→2×s16`. Gate on `hasAccum16()` so DEFAULT codegen is untouched. Walk the cascade
  (the investigation got trunc→anyext→…) until seed 11 clears the Legalizer pass.
- **P2 — Selector / artifact-combiner.** A "whole" s32 has no register class, so the s32↔2×s16
  (un)merge/trunc/ext must be folded by the `LegalizationArtifactCombiner` (the default path's mechanism for
  s8) and never reach selection. Where one does reach selection, extend `selectMergeValues` /
  `selectUnmergeValues` (`MOSInstructionSelector.cpp`) — currently 2×s8→s16 only — to the s16-piece case.
  Goal: seed 11 selects with no "cannot select".
- **P3 — Correctness.** The differential is the oracle: seed 11 and the 10 former-XFAIL sweep seeds must
  produce **host==default==a16==xy16** (a wrong lowering shows as a value mismatch, not a silent pass).
- **P4 — Land it.** Frozen `.ll` regression (`examples/65816/a16unmerge.ll` + `dev/run.sh a16unmerge`, the
  `a16spillir.ll` precedent), remove the `a16-unmerge-s32` XFAIL on `wt/321-csmith` (regression guard),
  `dev/regen-patch.sh` → `0002`, update `TODO.md`.

## RESULT (2026-06-19): **DONE** — fix landed + verified

The fix is **4 additive, `hasAccum16()`-gated legalizer rules** (`G_ANYEXT`, `G_TRUNC`, `G_MERGE_VALUES`,
`G_UNMERGE_VALUES` extended for s32↔s16); the artifact combiner folds the s32↔2×s16 (un)merge so **no selector
change was needed**. `G_ZEXT` was deliberately left at `maxScalar(0, S8)` — an early attempt to raise it to S16
broke plain `s8→s16` zext (caught by corpus-a16; reverted). Two false trails the differential/red-green caught
(measure-don't-assume): a hand-minimized `.ll` that *looked* like seed 11 but compiled on baseline (silent
no-op), and a **stale `build/llvm-mos/bin/llc`** (`dev/run.sh toolchain` builds only `--target distribution`, so
llc isn't rebuilt) — the gate therefore drives the rebuilt `mos-clang -Xclang -disable-llvm-passes`, not llc.

### Verification
1. **Repro fixed.** Seed 11 compiles clean under `+mos-a16` and the differential agrees:
   `[ ok ] seed 11  0xB44A (all agree)` (host==default==a16==xy16==bsnes). **PASS.**
2. **No default regression.** Default codegen is `hasAccum16()`-gated out; covered transitively by step 3
   (corpus-a16 builds + runs the DEFAULT ROM of every corpus program and all agree). **PASS.**
3. **Differential intact.** `dev/run.sh corpus-a16` → `5/6 passed, 1 xfail` (globals.c regalloc XFAIL). **PASS.**
4. **s32 sweep seeds PASS.** csmith_run (rebuilt toolchain) seeds 1–100:
   `==> csmith: 92/100 PASS, 0 xfail, 8 skip  (0 mismatch, 0 crash, 0 error)`. The 9 purely-s32 seeds
   (11/39/49/50/71/83/87/96/100) now PASS with agreeing values; seed 9 (both s32 AND diverging) reclassifies
   to SKIP. Baseline was 83 PASS / 10 xfail / 7 skip → now **92 / 0 / 8**. **PASS.**
5. **Hermetic regression, red-green validated** (fresh binaries):
   ```
   baseline (fix reverted): RESULT: FAIL  (unable to legalize ... G_UNMERGE_VALUES %_(s32))
   fix applied:             RESULT: PASS — hermetic .ll: +mos-a16 s32 unmerge/trunc compiles clean
   ```
   **PASS.**
6. **Patch round-trips.** `dev/regen-patch.sh` → `RESULT: PASS — 0002 round-trips`; the `0002` delta is exactly
   the 4 legalizer rules (+76/−15), no foreign hunks. **PASS.**
7. **XFAIL removed** from `tools/a16_fuzz.py` `KNOWN_ISSUES` (on `wt/321-csmith`) so `a16-unmerge-s32`
   hard-FAILS again on regression. _(done on the csmith branch)_

## Evidence (raw)
- Baseline error (seed 11, a16, `-fno-lto -c`): `unable to legalize ... G_UNMERGE_VALUES %530:_(s32)`.
- After `.lower()` unmerge: `unable to legalize ... G_TRUNC %530:_(s32)`.
- After s32 (un)merge+trunc legal: `unable to legalize ... G_ANYEXT %528:_(s32) = G_ANYEXT %357:_(s8)`.
- `selectMergeValues` (`MOSInstructionSelector.cpp:2046`) = 2×s8→s16 only (`getFirst3Regs` + `composePtr`).
- Default build of seed 11 links clean throughout; plain i32 `a^b`/`a&b` (result stored as i32) compile clean
  under a16 (the i32 stays in byte pieces); only s16-interaction (trunc-to-i16) breaks.
- Toolchain reverted + rebuilt: seed 11 fails the original `G_UNMERGE s32` way → baseline restored.

## Logistics note
The compiler fix (if (a)) lives in `vendor/llvm-mos` (main checkout) → `0002`. The XFAIL bookkeeping lives in
`tools/a16_fuzz.py` `KNOWN_ISSUES` on `wt/321-csmith`. If (a) lands, remove that entry (regression guard); if
(b), keep it and add the documented-limitation note.
