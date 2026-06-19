# #321 native s16 — 16-bit **indexed** comparisons (RHS `cmp abs,x` / `cmp (zp),y` fold) + comparison differential-audit

**Target:** `vendor/llvm-mos/llvm/lib/Target/MOS/` (`+mos-a16`). On execution, copy this into
`docs/plans/2026-06-19-321-native-16bit-indexed-compares.md` and add a TODO.md M2 entry first (plan-first
contract); **branch off the current `main` tip (`2c720a0`)** — the xy16 X-flag-lattice fix has **landed** (see
*Concurrency & coordination*); a `wt/321-idxcmp` worktree is optional (clean commits, not isolation). Regen
`patches/llvm-mos/0002-321-accum16.patch` via `dev/regen-patch.sh` at the end.

## Context

The user asked to **(#2) extend, then (#1) harden** the unsigned 16-bit comparison codegen. Investigation found
the literal "unsigned s16 comparisons" work already shipped (Slice 1, 2026-06-14) and the whole compare family
(equality, signed, eq-as-value, global-RHS fold) has since landed. The one **genuine residual gap** is the
**16-bit *indexed* compare**: the 8-bit path has `CMPAbsIdx`/`CMPIndirIdx` + `CmpBrAbsIdx`/`CmpBrIndirIdx`, and
the 16-bit path has indexed *loads* (`LDAbsIdx16`/`LDIndirIdx16` via `G_LOAD16_ABS_IDX`/`G_LOAD16_INDIR_IDX`,
increment 1e) and non-indexed 16-bit *compares* (`CMPImag16`/`CMPAbs16`/`CMPImm16`) — but **no 16-bit indexed
compare**. So `limit < arr[i]` (u16) stages `arr[i]` through an `Imag16` zero-page pair instead of folding into
one `cmp arr,x`.

**Governing-lesson-#1 scoping (measure, don't assume) — already done statically, confirm empirically in Phase 0:**
the pass order is `ExpandPostRAPseudos` → `MOSLateOptimization`/`threadAccum16` (`MOSTargetMachine.cpp:321,325`),
and `threadAccum16` (`MOSLateOptimization.cpp:423-506`) collapses a `STAImag16 $h=$a16` followed by a redundant
`LDAImag16 $a16=$h` (a reload **into A16**) but **not** a `STAImag16 $h` consumed by a `CMPImag16 …,$h` (a memory
compare operand — line 489 `A16` clobber / line 499 `HomeRead` block the erase). Therefore:

| Shape | Indexed operand role | Today | Verdict |
|---|---|---|---|
| `arr[i] < limit` (and `arr[i]==k`) | **LHS**, loaded into A16 | `lda arr,x; cmp limit` after the staged value threads back into A16 | **already optimal — no work** |
| `limit < arr[i]` | **RHS**, the cmp operand | `lda arr,x; sta __rc; lda limit; cmp __rc` — `sta __rc` survives | **genuine gap → BUILD** |
| `g == arr[i]` / both-indexed EQ | RHS via Z-fusion | staged through `Imag16` | real but rare → **DEFER** |

Why LHS is already optimal: `arr[i] < limit` is `ICMP_ULT` → `negateInverseComparison` (inverts predicate only,
**no operand swap**) → `arr[i]` stays on the `G_SBC` LHS; `selectMem16AbsIdx` emits `LDAbsIdx16 $a16; STAImag16 $rc`
and `selectSbc16` emits `LDAImag16 $a16b,$rc` immediately after → an **emit-adjacent** redundant round-trip that
copy-elimination / `threadAccum16` removes. `limit < arr[i]` → `arr[i]` on the RHS → `selectSbc16` falls to
`CMPImag16 $rc` with an intervening `LDAbs16 limit` that clobbers A16, so the stage cannot be threaded away.

## Concurrency & coordination — RESOLVED (the xy16 X-flag-lattice fix landed 2026-06-20)

**Re-evaluated against HEAD `2c720a0`.** The concurrent xy16 work has **landed and merged**: `55ec505` "fix the
`requiredXWidth` index-width gap — clears all 5 remaining defects" + `185b886` narrowed **pr49419 to an
xy16-only hang** (root cause = the X-flag lattice's CPX/CPY index-width gap, *not* the signed-compare path).
The c-torture backlog is clear. Consequences for this plan:

- **No more race / no integrate-from-union.** The lattice fix is already in `main`'s `0002`. Branch off the
  settled tip `2c720a0`; a worktree is now optional (clean commits, not isolation).
- **My core code is byte-unchanged.** Only `55ec505` touched `0002` since the baseline, and it did **not** alter
  `selectSbc16` (9→9), `foldableAbsLoad16` (16→16), `CMPAbs16` (10→10), the indexed-load infra, or
  `eliminateFrameIndex` (symbol-count diff). The RHS-indexed fold design is intact.
- **X-width coupling now concrete + de-risked.** `requiredXWidth` now classifies the CPX/CPY compare family
  (`CMPImm`/`CMPImag8`/`CMPAbs` with an index-reg operand) as `X8`, and **explicitly documents that the 16-bit
  *accumulator* compare `CMPImm16` stays `XW_None`**. My `CMPAbsIdx16`/`CMPIndirIdx16` are 16-bit *accumulator*
  compares whose index is used only for *addressing* (like `LDAbsIdx16`) → they mirror `LDAbsIdx16`'s `XW_None`,
  correct because the op that loads the 8-bit index into X is itself `X8`-classified (LDImm/LDAbs/TAX),
  establishing an X8 ambient. **No `requiredXWidth` edit needed; the Phase-3 xy16 differential verifies it.**

## The bar (correctness = the differential)

host-computed == default(non-`+mos-a16`)@MAME == `+mos-a16`@MAME == `+mos-a16`@bsnes-jg, plus
`-verify-machineinstrs` clean. Any disagreement/crash is a real defect. (Commands in
[`docs/agent-handoff.md`](docs/agent-handoff.md).)

---

## Phase 0 — Measure & confirm scope (throwaway worktree, no `vendor/` edit)

Build the real shapes with the **current** toolchain and read the disasm to confirm the table above before
touching codegen. Compile each with `+mos-a16 -Os` and `llvm-objdump -d --mcpu=mosw65816`:

1. `if (arr[i] < limit)` and `if (arr[i] == k)` → **expect** `lda arr,x; cmp …` with **no** `sta __rc`
   (confirms LHS already optimal; if a `sta __rc` appears, the LHS case also needs work — re-scope).
2. `if (limit < arr[i])`, `if (limit > arr[i])` etc. → **expect** `lda arr,x; sta __rc; lda limit; cmp __rc`
   (confirms the gap). Repeat with `p[i]` (pointer-indexed) → `(zp),y` form.
3. Grep the corpus / a csmith sweep for the RHS-indexed idiom frequency to size the win (governing lesson #3:
   modest gains still count, but record the magnitude). Record bytes saved per site (`lda+sta` ≈ 4–5 B + one
   freed `Imag16` slot).

Record the verdict (script + measurements) under `dev/` per the worktree workflow; merge only the durable
artifact back.

## Phase 0 — RESULT (measured 2026-06-20) — SCOPE CORRECTED

Built `/tmp/m_idxcmp.c` (non-volatile `u16 arr[8]` + volatile `u8` index) and read the `+mos-a16 -Os` disasm:

- **LHS-indexed already optimal — CONFIRMED.** `arr[i] < limit` → `lda (ptr); cmp limit`; `arr[i] == k` →
  `lda (ptr); cmp #imm16`. No `sta __rc`. No work.
- **RHS-indexed gap — CONFIRMED.** `limit < arr[i]` → `lda (ptr); sta __rc; lda limit; cmp __rc` — the `sta __rc`
  survives (threading can't remove it; `lda limit` clobbers A16 between). Same for `p[i]`.
- **SURPRISE / scope correction:** a `u16 arr[i]` does **not** become `lda abs,x` (`G_LOAD16_ABS_IDX`) — the `*2`
  element scaling defeats that pattern, so it materializes a pointer and uses **`lda (zp)` plain indirect**
  (`G_LOAD16_INDIR` → `LDAIndir16`, opcode `b2`; comment `MOSInstrLogical.td:842` = "`*p, a[i], a[i]=v, p[i]`").
  So the fold instruction is **`CMPIndir16` (`cmp (zp)`)**, *not* `CMPAbsIdx16`. This is **cleaner**: a plain
  indirect operand has **no index register → no X-flag-lattice coupling (R6 gone), no frame-index concern**, and
  it mirrors `LDAIndir16` + the 8-bit `m_FoldedLdIndir`→`CMPIndir` fold (`MOSInstructionSelector.cpp:1539`).
- The `abs,x`/`(zp),y` **indexed** compare forms (`CMPAbsIdx16`/`CMPIndirIdx16`, the original 1a) only fire for
  the rarer byte-cast / pointer-indexed shapes (`a16absidx.c`/`a16indiry.c`) → **deferred** pending a frequency
  scan.

**Phase 1 below is revised accordingly: build `CMPIndir16` (primary, the measured common case).**

---

## Phase 1 — Build: RHS-indexed unsigned-ordering fold

Mirrors three existing patterns: `LDAbsIdx16` (16-bit indexed load), `CMPAbs16` (16-bit compare), and the 8-bit
`CMPAbsIdx` selectSbc fold. **Resolved design point (R1):** selection is bottom-up
(`InstructionSelect.cpp:214` "reverse block order"), so at `selectSbc16` time the RHS def is still the **generic**
`G_LOAD16_ABS_IDX` — match that opcode (same as `foldableAbsLoad16` matches generic `G_LOAD16_ABS`).

**1a. New MC compare instruction (REVISED → `CMPIndir16`)** — `MOSInstrLogical.td`, beside `CMPImag16` (~:866),
mirroring `LDAIndir16` (`:843`) + the 8-bit `CMPIndir` (`:406`):
```tablegen
def CMPIndir16 : MOSCMP16, PseudoInstExpansion<(CMP_Indirect addr8:$addr)> {
  dag InOperandList = (ins Ac16:$l, Imag16:$addr);    // cmp (zp), M=16
}
```
`MOSCMP16` supplies `Predicates=[HasAccum16]`, `MLow=1`, `mayLoad`, `(outs Cc:$carry)`. `HasAccum16` (65816)
includes the `(zp)` indirect mode, so no separate `Has65C02` is needed — same as `LDAIndir16`. *(Deferred:
`CMPAbsIdx16` (`cmp abs,x`) / `CMPIndirIdx16` (`cmp (zp),y`) for the byte-cast / pointer-indexed shapes — those
carry the X-flag coupling and an FI-base concern; build only if a frequency scan justifies them.)*

**1b. `foldableIndirLoad16` helper** — `MOSInstructionSelector.cpp`, beside `foldableAbsLoad16` (~:1395):
single-use + same-BB; def opcode `G_LOAD16_INDIR` → returns the load (operand 1 = the zp pointer pair). At
`selectSbc16` time the RHS def is still the **generic** `G_LOAD16_INDIR` (bottom-up selection,
`InstructionSelect.cpp:214`), so match that opcode — same as `foldableAbsLoad16` matches generic `G_LOAD16_ABS`.
No `isXc16Reg` guard needed (an indirect-load result is never Xc16-constrained).

**1c. `selectSbc16` RHS arm** — insert between the `foldableAbsLoad16(R)`→`CMPAbs16` branch (~:1443) and the
`CMPImag16` fallback (~:1450): if `foldableIndirLoad16(R)` matches, build `CMPIndir16`
(`addDef(CarryOut).addUse(Lo).addUse(LdR->getOperand(1).getReg()).cloneMemRefs(*LdR)`); push the load to `Folded`
(erased by the existing loop at :1460). The pointer use is **transferred**, live to the cmp by construction.

**1d. MCInstLower — none.** `CMPIndir16` is `(zp)` indirect (no abs base), so there is no ZP-confusable reparse
window; `PseudoInstExpansion<(CMP_Indirect addr8:$addr)>` suffices, exactly like `LDAIndir16` and the 8-bit
`CMPIndir`.

**1e. Frame-index — none.** `CMPIndir16`'s address operand is an `Imag16` (zp pointer pair), never a frame index,
so `eliminateFrameIndex` is not involved. (The deferred `abs,x` form would have needed the `MOSRegisterInfo.cpp`
`default`-arm check; `(zp)` indirect does not.)

**1f. Gating (governing lesson #2 — a miss must only forgo a win, never regress):** `CMPIndir16` is
`Predicates=[HasAccum16]`; the fold lives in `selectSbc16`, reached only for an **s16** `G_SBC` (`selectSbc`
:1475); `G_LOAD16_INDIR` only exists under `+mos-a16`. single-use + same-BB makes the fold 1-to-1 volatile-safe
(one memory access either way). Multi-use / cross-block / non-indirect RHS → falls to `CMPImag16` (today's
codegen). **Verified 2026-06-20:** the fold fires only for the RHS-`<` indirect operand (`cmp (zp)`=`d2`), while
LHS-loaded and `>`-swapped cases keep `lda (zp); cmp` (`b2`); `-verify-machineinstrs` clean; existing a16 suite
green (a16cmp/a16abscmp/a16scmp/a16indiry/a16absidx/a16eqval).

---

## Phase 2 — Tests (regression guard, in the same change)

Mirror `examples/65816/a16cmp.c` (ordering) + `a16absidx.c` (indexed). **Use non-volatile arrays + a volatile
index** (`a16absidx.c`'s volatile *array* would block the single-use compare fold; a volatile *index* still
forces runtime `G_LOAD16_ABS_IDX`):

- `a16cmpidx.c` **(DONE, 2026-06-20)**: `lim < arr[k]` (array) + `lim < parr[k]` (pointer), both branch
  directions + the 0x0099-vs-0x0200 high-byte-differs pair + boundary values (0x0000/0x8000/0xFFFF). The five
  RHS-`<` cases fold to `cmp (zp)` (`d2`); the two `lim > arr[k]` cases swap arr[k] to the LHS (`lda (zp); cmp`).
  Disasm gate: ≥1 `rep`, ≥5 `cmp (zp)` folds, **no** `cpx/cpy`. `corpus_result == 0x1111` on **both** MAME and
  bsnes-jg; `-verify-machineinstrs` clean.
- **LHS control — covered:** the two `lim > arr[k]` cases (arr[k] swapped to LHS) keep `lda (zp); cmp` and do
  **not** mis-fold.
- **`a16cmpidxframe.c` — N/A.** `CMPIndir16`'s operand is an `Imag16` pointer pair, never frame-index-eliminated,
  so there is no `f2d65c2`-class hazard to lock. (Would apply only to the deferred `abs,x` form.)
- **Lit `.ll` — SKIP.** There is **no `+mos-a16` lit-test convention** under `test/CodeGen/MOS/` (verified
  2026-06-20); the project's bar is the `dev/` emulator-differential micro-test, which `a16cmpidx.c` follows.
- `dev/a16cmpidx.sh` **(DONE)** — wired into `dev/run.sh` usage + help (generic `dev/<target>.sh` dispatch).

---

## Phase 3 — Differential-audit / harden (the user's "#1", covers old + new) — DONE 2026-06-20

**Built both legs the user asked for (#2 the matrix harness, then #1 the existing differentials).** New
harness `examples/65816/a16cmpaudit.c` + `dev/a16cmpaudit.sh` (wired into `dev/run.sh`): 8 predicates ×
{as-value, as-branch} × RHS shapes {reg, imm, global, global-array[k], pointer[k], stack-array[k]} +
LHS-indexed control, swept over the boundary set, each outcome folded into a rolling checksum. Host oracle
`0x5EE0` (reproducible: `cc -DHOST_ORACLE examples/65816/a16cmpaudit.c && ./a.out`; stable `-O0…-Os`).
`dev/run.sh a16cmpaudit` → **host == default == +mos-a16 on both emulators, verify-clean**. The existing
differentials confirm no regression: a16 compare suite 6/6, `fuzz 50 1` 0-mismatch/0-crash, `torture 60`
60/60 no XPASS churn. (Raw output in the Verification section, step 9.)

A focused stress harness proving the **whole** unsigned-ordering compare surface (now including indexed) correct:
- Matrix: 4 orderings × operand shapes {reg, imm, global, computed, **abs-idx**, **(zp),y-idx**, stack-idx} ×
  boundary values {0x0000, 0x00FF, 0x0100, 0x7FFF, 0x8000, 0xFFFF, equal, equal-high-byte} × {as-branch,
  as-value}. Host oracle == default@MAME == a16@MAME == a16@bsnes-jg, `-verify-machineinstrs` clean.
- Run the existing fuzz + c-torture differentials (`dev/run.sh fuzz`, `dev/run.sh torture`) which already exercise
  array-indexed compares — confirm 0 new mismatches and no new XFAIL/XPASS churn.
- Outcome: a green bill of health, or a found miscompile + in-backend fix + regression test.

---

## Deferred (gate on Phase 0/3 measurement, not built now)

- **EQ RHS-indexed fusion** (`g == arr[i]` / both-indexed): new `CmpBrAbsIdx16`/`CmpBrIndirIdx16` pseudos +
  `expandCmpBr16` arm (forward addr+idx) + `selectBrCondImm` fold. Lacks the obvious redundant-`sta` the ordering
  path has (the load's `Imag16` home is read directly by a single Z-compare); low frequency.
- **`+mos-xy16` 16-bit-index compares** (`cmp abs,X16`): separate instruction; the v1 helper deliberately
  ignores `G_LOAD_ABS_IDX16`/`G_LOAD_INDIR_IDX16`.
- **Indexed LHS explicit fold** — only if Phase 0 shows threading misses it.

## Risks

- **R1 (resolved):** generic-vs-selected load opcode — bottom-up selection ⇒ match generic `G_LOAD16_ABS_IDX`.
  Confirm empirically: Phase 1 disasm shows the fold fires (`cmp arr,x`, no `sta __rc`).
- **R2 (low):** volatile RHS — single-use ⇒ exactly one access folded or not; verify with a volatile-RHS codegen
  test, mirror `foldableAbsLoad16` (no extra volatile bail unless the test shows a semantics change).
- **R3 (low):** `cmp abs,x` ZP-confusable base reparse — closed by the explicit MCInstLower case (1d).
- **R5 (low):** scheduling could split the LHS `STAImag16`/reload and regress it to staged — latent only
  (straight-line `if` has nothing between); the LHS control test guards it.
- **R6 (low, de-risked — lattice landed):** xy16 `X=8` bracketing of the new indexed compares relies on the
  now-**landed** X-flag lattice. My compares mirror `LDAbsIdx16` (`XW_None`, correct via the X8-classified
  index-load); verify via the Phase-3 xy16 differential. No `MOSInsertREPSEP.cpp` edit expected; if the xy16 leg
  ever shows a mis-bracket, the fix belongs in `requiredXWidth` (keyed off the `Xc`/`Yc` operand class). a16 is
  independent.

## Verification (run each; paste raw output + PASS/FAIL back into the plan on execution)

**EXECUTED 2026-06-20 — all PASS (toolchain `clang-23` mtime `2026-06-20T02:29`).**

1. **Build:** `dev/run.sh toolchain` — verify the rebuild took (fresh `build/llvm-mos-install/bin/clang-23`
   mtime; the stale-`clang-23` gotcha).
   ```
   -rwxr-xr-x 1 will will 124761488 2026-06-20T02:29 build/llvm-mos-install/bin/clang-23
   ```
   **PASS** — fresh build (this morning); the CMPIndir16 fold is in it (steps 2–4 below confirm).
2. **Fold fires (the win):** compile `a16cmpidx.c` with `+mos-a16 -Os -c`; `llvm-objdump -d --mcpu=mosw65816`
   shows `cmp abs,x`/`cmp (zp),y` under one `rep #$20`…`sep #$20`, **no** `sta __rc` for the RHS operand, **no**
   `cpx/cpy`. PASS ⇔ the staged store is gone. *(Scope correction, Phase 0: the fold is `cmp (zp)` / `$D2`,
   not `cmp abs,x` — the `*2` element scaling routes `u16 arr[i]` through a computed pointer.)*
   ```
   ==> disasm gate: each RHS-indexed compare folds to cmp (zp) ($D2) under rep/sep —
       NOT a staged lda (zp); sta $__rc; lda lim; cmp $__rc, and NOT an 8-bit cpx/cpy chain
     PASS: 19 rep #$20 bracket(s) — 16-bit compares
     PASS: 5 cmp (zp) folds (one per RHS-indexed compare, value read in place)
     PASS: no 8-bit cpx/cpy compare-chain (fully native 16-bit)
   ```
   **PASS** — 5 `cmp (zp)` folds, no staged `sta __rc`, no `cpx/cpy`.
3. **LHS unchanged:** the control case still emits `lda (zp); cmp limit` (no regression).
   The two `lim > arr[k]` cases swap `arr[k]` to the LHS and keep `lda (zp); cmp` (opcode `$B2`), not a mis-fold
   — confirmed in the same disasm gate (only the 5 RHS-`<` operands fold to `$D2`). **PASS**.
4. **Differential:** `dev/run.sh a16cmpidx` → `corpus_result` matches host on **both** MAME and bsnes-jg, both
   branch directions + high-byte-differs.
   ```
   ==> MAME: assert corpus_result == 0x1111 (RHS < folds + > swapped-to-LHS + high-byte-differs)
   SMOKE: PASS addr=0x7E0200 len=2 got=0x1111 (ran 60 ticks)
   ==> bsnes-jg: assert corpus_result == 0x1111 (independent confirmation)
     SMOKE: PASS off=0x200 len=2 got=0x1111 (ran 180 frames, bsnes-jg)
   RESULT: PASS — native 16-bit RHS-indexed compare fold (cmp (zp)) computes 0x1111; both emulators agree
   ```
   **PASS** — `0x1111` on both emulators.
5. **verify-machineinstrs:** `… -mllvm -verify-machineinstrs -c` on the test set — clean (no "Bad machine code").
   Baked into `dev/a16cmpidx.sh:41` (the disasm-gate compile is `-mllvm -verify-machineinstrs -c`); step 2 ran
   it with no "Bad machine code" output. `a16cmpaudit` (step 9) also compiles `+mos-a16 -verify-machineinstrs`
   clean via `diff_check`. **PASS**.
6. **Frame-index:** ~~`a16cmpidxframe.c` (stack array)~~ — **N/A.** `CMPIndir16`'s address operand is an
   `Imag16` (zp pointer pair), never a frame index, so `eliminateFrameIndex` is not involved — there is no
   `f2d65c2`-class hazard for this form (would apply only to the deferred `cmp abs,x`). The Phase-3 audit
   (step 9) still exercises a **stack array** `sa[k]` RHS shape and agrees 4-way. **N/A → covered.**
7. **lit:** ~~`llvm-lit …/<new>.ll`~~ — **SKIP.** No `+mos-a16` lit-test convention exists under
   `test/CodeGen/MOS/` (verified 2026-06-20); the project's bar is the emulator-differential micro-test.
8. **Non-breaking:** existing a16 suite; `dev/run.sh fuzz 50 1` 0 mismatch; `dev/run.sh torture` no new FAIL.
   ```
   ######## a16cmp ######## RESULT: PASS — 0x1103; both emulators agree
   ######## a16scmp ######## RESULT: PASS — 0x0111; both emulators agree
   ######## a16abscmp ######## RESULT: PASS — 0x4303; both emulators agree
   ######## a16indiry ######## RESULT: PASS — 0x5678; both emulators agree
   ######## a16absidx ######## RESULT: PASS — 0x9ABC; both emulators agree
   ######## a16eqval ######## RESULT: PASS — 0x0101; both emulators agree
   ==> csmith: 45/50 PASS, 0 xfail, 5 skip  (0 mismatch, 0 crash, 0 error)
       skip buckets: diverged-before-result (corpus_result GC'd)=5
   ```
   **PASS** — a16 compare suite 6/6; fuzz 50 0 mismatch / 0 crash (5 benign skips). *(c-torture: see step 9.)*
9. **Audit (Phase 3):** the whole-compare-surface differential-matrix harness `a16cmpaudit` (8 predicates ×
   {as-value, as-branch} × RHS shapes {reg, imm, global, global-array[k], pointer[k], stack-array[k]} +
   LHS-indexed control, over boundary values) — all cells agree 4-way, verify-clean. Plus the c-torture
   execute differential (the existing suite already exercises array-indexed compares).
   ```
   ==> a16cmpaudit: differential default vs +mos-a16  (expected 0x5EE0; bsnes=yes)
     [PASS] a16cmpaudit  0x5EE0 (all agree)
   RESULT: PASS — a16cmpaudit: default == +mos-a16 == host on both emulators
   ```
   Host oracle `0x5EE0` is reproducible by host-compiling the harness (`cc -DHOST_ORACLE … && ./a.out`,
   stable across `-O0…-Os`). c-torture differential (`dev/run.sh torture 60`):
   ```
   ==> torture-run: 60 PASS, 0 FAIL, 0 SKIP, 0 XFAIL (of 60)
   ```
   **PASS** — audit harness 4-way agree; c-torture 60/60 no FAIL / no XPASS churn.
10. **Patch round-trips:** `dev/regen-patch.sh`; `git diff --cached --name-only` is exactly your files (never
    `vendor/`, foreign patches, `docs/transcripts/`); sanity-check `0002` didn't absorb foreign hunks.
    ```
    RESULT: PASS — 0002 round-trips (reapplied MOS dir == live vendor)
    # git diff --stat: 0002 = 40 insertions / 6 deletions (exactly the CMPIndir16 fold)
    # CMPIndir16=4, foldableIndirLoad16=2; no foreign new symbols absorbed
    ```
    **PASS** — idempotent regen; only the CMPIndir16 hunk added.

## References

- Slice-1 plan [`docs/plans/2026-06-14-321-native-16bit-compares.md`]; equality
  [`…2026-06-15-321-native-16bit-equality-compares.md`]; abs-operand fold
  [`…2026-06-15-321-native-16bit-compare-abs-operand-fold.md`]; increment-1e indexed load/store
  [`…2026-06-18-321-abs-x-indiry-16bit-indexed-load-store.md`]; A16-threading
  [`…2026-06-17-321-a16-threading.md`]; frame-index scramble
  [`…2026-06-19-321-cmpbrabsimm16-frameindex-elimination-scramble.md`]. Master TODO item: `TODO.md:41`.
- Code anchors: `selectSbc16` `MOSInstructionSelector.cpp:1413`; `foldableAbsLoad16` :1395; `selectBrCondImm`
  :1161; `selectMem16AbsIdx` :2993; `CMPAbs16`/`MOSCMP16` `MOSInstrLogical.td:861`; `LDAbsIdx16` :690;
  `threadAccum16` `MOSLateOptimization.cpp:423`; `expandCmpBr16` `MOSInstrInfo.cpp:1433`; `eliminateFrameIndex`
  `MOSRegisterInfo.cpp:256`; bottom-up select `InstructionSelect.cpp:214`.
