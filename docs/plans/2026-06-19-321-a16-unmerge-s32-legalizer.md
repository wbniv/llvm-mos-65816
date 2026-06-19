# Investigation: `+mos-a16` has no s32 (`long`/`int32_t`) legalization in s16-interacting shapes

**Date:** 2026-06-19 · **Status:** IMPLEMENTING — **Decision: (a) INVEST** (build s32-under-a16). The
investigation below established there is **no minimal "B"**: the correctness fix *is* the s32-under-a16
feature. Work happens on the `main` checkout (project #321 practice; `vendor/llvm-mos` edited in place → `0002`).
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

## Verification (paste raw output under each step on execution)
1. **Repro fixed.** Csmith seed 11 compiles clean under `+mos-a16` (`-fno-lto -c` AND full `--config` LTO),
   default still clean. _(paste)_
2. **No default regression.** `dev/run.sh corpus` 7/7. _(paste)_
3. **Differential intact + extended.** `dev/run.sh corpus-a16` 5/6 + XFAIL (globals.c). _(paste)_
4. **s32 sweep seeds PASS.** csmith_run (rebuilt toolchain) seeds 1–100 → the 10 former `a16-unmerge-s32`
   XFAILs now PASS, 0 mismatch, 7 diverged SKIP → **93 PASS / 7 skip / 0 xfail**. _(paste)_
5. **Hermetic regression.** `dev/run.sh a16unmerge` verifies clean with the fix; aborts without it. _(paste)_
6. **Patch round-trips.** `dev/regen-patch.sh` → `0002` captures only this MOS delta; round-trip verify passes,
   no foreign hunks. _(paste)_
7. **XFAIL removed** from `tools/a16_fuzz.py` `KNOWN_ISSUES` (on `wt/321-csmith`) so the signature hard-FAILS
   again on regression. _(paste)_

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
