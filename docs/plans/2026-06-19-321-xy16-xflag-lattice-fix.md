# Fix the xy16 X-flag (index-width) lattice in `MOSInsertREPSEP` (the all-xy16 backlog)

**Date:** 2026-06-19 · **Status:** **FIXED 2026-06-20.** Root cause confirmed: a `requiredXWidth` gap in
`MOSInsertREPSEP` left index-register **value** ops (compares + register inc/dec) X-agnostic, so they ran in
the ambient X=16 left by a preceding 16-bit-indexed load. ONE fix cleared **all 5** remaining #321 defects
(`pr49419`, `doloop-1`, `20041011-1`, `va-arg-22`, `k_isort` xy16) — the all-xy16 backlog, as predicted.
**Issue:** #321, ROADMAP M2.
**Required reading:** [pr49419 xy16-hang plan](2026-06-19-321-c-torture-pr49419-a16-xy16-hang.md) (the vehicle)
· [c-torture suite plan](2026-06-19-321-c-torture-execute-differential-suite.md) §"Phase 2 backlog —
RESOLUTION" · [xy16 integration plan](2026-06-18-321-xy16-legalizer-integration.md) ·
[the a16 frame-index fix](2026-06-19-321-cmpbrabsimm16-frameindex-elimination-scramble.md) (the
"one fix clears a cluster" precedent).

## TL;DR

The a16 (16-bit-accumulator) track is healthy; **all 5 remaining #321 defects are xy16** (16-bit *index*
registers): `pr49419` (hang), `k_isort` (wrong value), `doloop-1`, `20041011-1`, `va-arg-22`. For `pr49419`
the xy16 codegen traces **instruction-logic-correct** (loop2 is byte-identical to the now-passing a16) yet it
hangs ⇒ the defect is in the **processor X-flag (index-register width) state**, not the instruction stream.
xy16 is the only mode that toggles the index width (`rep #16`/`sep #16`/`sep #48`); a16 keeps the index 8-bit
and never emits them. So the prime suspect is the **X-flag lattice in `MOSInsertREPSEP`** — if it computes the
wrong index-width mode at some block entry, an index register is read/written at the wrong width, corrupting
a pointer or loop variable → a loop that never terminates (or a wrong checksum, as in `k_isort`). Likely a
**shared** cause across the xy16 cluster — one fix may clear several (as the frame-index fix cleared 13).

## Root cause (CONFIRMED) + the fix

`MOSInsertREPSEP::requiredXWidth(MI)` classifies each instruction's required X (index) width.
Its switch enumerated the index-register ops that are 8-bit-intent and so must run X=8 (loads/stores
of X/Y, `LDXIdx`/`LDYIdx`, `TA`/`TX`, `PH`/`PL` of X/Y) — but **omitted the index-register *value* ops**:
the compares **`CMPImm`/`CMPImag8`/`CMPAbs`** when their compared operand `$l` is X/Y (→ `cpx`/`cpy`), and
the register **`INC`/`DEC`** when their dest is X/Y (→ `inx`/`iny`/`dex`/`dey`). These fell through to the
`XW_None` (X-agnostic) default, so the pass placed no rep/sep around them and they executed in whatever
X width was **ambient**.

In `pr49419` loop1 (MIR `bb.2`): a 16-bit-indexed load `LDXImag16 + LDAbsXIdx16` opens the body with
`rep #$30` (M16+X16) and the only restore before the bound test is `SEP_Immediate 32` (M only) — so the
counter compare `CMPImm $y, 2` ran with **X still 16**. `cpy #2` in X16 reads a 2-byte immediate and
compares Y's high byte, which is **uninitialized** because `i` was created/incremented at X=8 (`LDImm 0`,
`INC $y`). Garbage high byte → the `i < m` bound never resolves → infinite loop → `corpus_result` stays
`0x0000` (the hang). `cpx #1` in the same block only happened to be safe because an adjacent `LDImag8 $x`
(already classified X8) forced X=8 around it.

**Fix** (`MOSInsertREPSEP.cpp`, `requiredXWidth` switch): add `CMPImm`/`CMPImag8`/`CMPAbs` (check operand 1,
the compared `$l`; operand 0 is the `Cc` carry def) and `INC`/`DEC` (check operand 0, the dest) → return
`XW_X8` when that operand is X/Y. After the fix the pass restores X=8 before the compare — it even folds the
M- and X-restores into one `sep #$30` (one *fewer* instruction). The accumulator compare `CMP`/`CMPImm16`
and `INA`/`DEA` keep `XW_None` (their X/Y test fails → fall through). Strictly xy16-gated: `requiredXWidth`
is only called under `HasIndex16`, so default and `+mos-a16` codegen are untouched by construction.

Why no global-array micro-test: the X=16 ambient requires a 16-bit-indexed op, and in the *committed*
toolchain the absolute/(zp)-indexed 16-bit selection fires only for `pr49419`'s double-indirect
computed-index chase — global/pointer loops narrow to 8-bit X, so a minimal global-array test compiles to
all-X8 code and would not exercise the bug. The regression guards are therefore the cleared **c-torture
rows** (hard-FAIL on regression) plus **`k_isort`** (always-on in the a16 suite; its xy16 leg was the bug).

## Background — the M and X flags on the 65816

`rep`/`sep` with operand bits set/clear two independent width flags: **M** (bit 5, `#$20`) = accumulator
width, **X** (bit 4, `#$10`) = index (X/Y) width. `+mos-a16` drives only **M** (16-bit accumulator, 8-bit
index). `+mos-xy16` additionally drives **X** (16-bit index) → it emits `rep #16`/`sep #16` (and `sep #48` =
`#$30` = both). `MOSInsertREPSEP` is the dataflow pass that places these to satisfy each instruction's
required mode while minimizing toggles, tracking the mode **across basic blocks** (a lattice/fixpoint). The
xy16 X-flag handling is the 2026-06-18 addition and the least battle-tested part.

## Reproduction (host-side, no emulator)

`pr49419` xy16 hangs: `default = a16@MAME = a16@bsnes = PASS`, `xy16@MAME = 0x0000`. Build:
`mos-clang --config …/mos-snes.cfg -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-xy16 -O1
-Dmain=torture_test_main -Dabort=__torture_abort -Dexit=__torture_exit -o x.sfc pr49419.c _shim.o`
(+ `-Wl,--lto-emit-asm` for asm; `-Wl,-mllvm,-print-after=mos-insert-rep-sep -Wl,-mllvm,-filter-print-funcs=torture_test_main`
for the MIR with the X-flag mode).

## Approach
1. Read `MOSInsertREPSEP.cpp`'s X-flag lattice (the index-width transfer/meet + the rep/sep insertion).
2. Dump pr49419 xy16 MIR after `mos-insert-rep-sep`; find a block/instruction where the **actual** index
   width (from the rep/sep placement) ≠ the width the instruction **requires** (a `lda abs,x` / `ldx`/`ldy` /
   `cpx`/`cpy`/`txa`/`iny` reading the index reg at the wrong width). Cross-check against a16 (immune).
3. If elusive in the full test, **minimize**: a small `+mos-xy16` loop over a stack/global array using
   16-bit-indexed addressing that hangs (a clean micro-vehicle), debug there.
4. Fix the lattice (conservative — a misclassification must re-establish the needed width, never assume it);
   gate strictly so a16 / default codegen is unchanged.

## Verification (the contract — filled 2026-06-20)
1. `dev/run.sh torture --opt -O1 --tests pr49419.c` → **XPASS**; remove its `xfails.tsv` row.
   ```
   ==> torture-run: 1 test(s), -O1, default==+mos-a16==+mos-xy16 (MAME + bsnes-jg)
     XP pr49419.c              XPASS listed in xfails.tsv but now PASSes — remove the row
   ==> torture-run: 0 PASS, 0 FAIL, 0 SKIP, 0 XFAIL, 1 XPASS (of 1)
   ```
   **PASS** — row removed.
2. **xy16 cluster sweep** — `doloop-1`, `20041011-1`, `va-arg-22`, and `k_isort`.
   ```
   ==> torture-run: 3 test(s), -O1, default==+mos-a16==+mos-xy16 (MAME + bsnes-jg)
     XP doloop-1.c             XPASS ... — remove the row
     XP 20041011-1.c           XPASS ... — remove the row
     XP va-arg-22.c            XPASS ... — remove the row
   ==> torture-run: 0 PASS, 0 FAIL, 0 SKIP, 0 XFAIL, 3 XPASS (of 3)
   ---
   [PASS] k_isort  0xF47A (all agree)   # default == +mos-a16 == +mos-xy16 == host, both emus
   ```
   **PASS** — **all 4** torture rows + `k_isort`'s xy16 leg cleared by the one fix (shared cause confirmed).
   All 4 `xfails.tsv` rows removed; `k_isort` needs no known-fail mechanism (it just passes).
3. Regression guard: the cleared **c-torture rows** (hard-FAIL on regression) + **`k_isort`** (always-on,
   a16 suite, xy16 leg). A standalone `examples/65816/xy16*.c` micro-test was **attempted and dropped** — see
   "Why no global-array micro-test" above (committed toolchain narrows global indexing to X8, so a minimal
   test would compile to all-X8 code and not exercise the bug). **PASS** (guards in place).
4. Gate.
   ```
   ==> csmith: 45/50 PASS, 0 xfail, 5 skip  (0 mismatch, 0 crash, 0 error)   # default+a16+xy16 vs host; verify-machineinstrs under a16+xy16
   ==> corpus: 7/7 passed
   ```
   **PASS** (the 5 skips are the expected Csmith `corpus_result`-GC'd divergences).
5. Default + a16 codegen unchanged. `requiredXWidth` is only called under `HasIndex16` (xy16) — the pass
   early-returns unless `hasAccum16()`; all 3 call sites are `HasIndex16`-guarded. Empirically the fuzzer's
   default and a16 legs agree with the host across all 45 programs. **PASS** (xy16-only by construction).
6. `0002` regen — diff vs the committed 0002 is **exclusively** the `requiredXWidth` `INC`/`DEC` +
   `CMPImm`/`CMPImag8`/`CMPAbs` cases; no foreign files/hunks; round-trip `RESULT: PASS`. **PASS**.

## Risks / scoping
- **Shared-but-not-identical:** some of the 5 may be distinct (e.g. `20041011-1` 64-bit pressure, `va-arg-22`
  varargs). Step 2 measures the overlap; don't assume one fix clears all.
- **Lattice fixes are subtle** (cross-block fixpoint). Keep the change conservative (over-establish width on
  uncertainty) and run the full differential — a wrong X-flag meet could regress other xy16 programs.
- xy16 implies a16, so re-confirm both: a fix must not break the a16 path.
