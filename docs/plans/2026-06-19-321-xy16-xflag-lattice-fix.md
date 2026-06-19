# Fix the xy16 X-flag (index-width) lattice in `MOSInsertREPSEP` (the all-xy16 backlog)

**Date:** 2026-06-19 · **Status:** **INVESTIGATION → fix.** Root cause TBD (X-flag-lattice hypothesis). The
high-leverage successor to the a16 frame-index fix — every remaining #321 c-torture/kernel failure is xy16.
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

## Verification (the contract — fill after the fix)
1. `dev/run.sh torture --opt -O1 --tests pr49419.c` → **XPASS**; remove its `xfails.tsv` row. `(pending)`
2. **xy16 cluster sweep** — re-run `k_isort`, `doloop-1`, `20041011-1`, `va-arg-22` (+ the torture xy16 rows);
   record which clear (shared-cause test). Remove cleared rows / fix `k_isort`'s xy16 leg. `(pending)`
3. Regression test: a `examples/65816/xy16*.c` micro-test for the X-flag-width loop shape, both emulators. `(pending)`
4. Gate: `fuzz 50 1` (a16 **and** xy16 tracks), `corpus`, the a16 suite (incl. `k_isort`), `-verify-machineinstrs`. `(pending)`
5. Default + a16 codegen unchanged (the fix is xy16-only): prove via the fuzzer's default leg + an a16 spot-check. `(pending)`
6. `0002` regen, no foreign hunks. `(pending)`

## Risks / scoping
- **Shared-but-not-identical:** some of the 5 may be distinct (e.g. `20041011-1` 64-bit pressure, `va-arg-22`
  varargs). Step 2 measures the overlap; don't assume one fix clears all.
- **Lattice fixes are subtle** (cross-block fixpoint). Keep the change conservative (over-establish width on
  uncertainty) and run the full differential — a wrong X-flag meet could regress other xy16 programs.
- xy16 implies a16, so re-confirm both: a fix must not break the a16 path.
