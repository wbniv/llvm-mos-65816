# #321 native s16 — immediates within 16-bit add chains (`a + b + c + K`)

ALU-chain extension: a ≥3-term add chain that includes a **constant** term
(`g = a + b + c + K`, or the multi-use `t = a+b+c+K; …`) currently fails to fuse — the
chain combiners require every leaf to be a near-abs load, so the constant breaks the
match and the whole chain falls back to the per-add path (each partial sum round-tripped
through an Imag16 pair). Allow constant leaves so the chain threads through A16 with the
constant folded as `adc #imm`.

## Background

`collectAddChain` (MOSCombiner.cpp) walks a 16-bit G_ADD tree and accepts a leaf only if
it is a single-use near-abs `G_LOAD`. A `G_CONSTANT` leaf returns false, so
`a + b + c + K` (root `((a+b)+c)+K`) fails to collect and neither `add_chain16` (store)
nor `add_chain16_ld` (multi-use) fires. Baseline: `lda a; clc; adc b; sta tmp; lda tmp;
clc; adc c; sta tmp; lda tmp; clc; adc #K; sta` — the globals and the `#K` fold, but two
`sta tmp; lda tmp` round-trips remain. Threaded: `lda a; clc; adc b; clc; adc c; clc;
adc #K; sta`. (The combiner runs pre-legalize, so a 16-bit literal is a single
`G_CONSTANT` — `getIConstantVRegValWithLookThrough` reads it directly.)

## Implementation

1. **`collectAddChain`**: add `int64_t &ConstSum, bool &HasConst` out-params. A constant
   leaf folds into `ConstSum` (rematerializable — use-count irrelevant, never erased; so
   the const check precedes the single-use gate that loads/adds still require). Multiple
   constants in the tree accumulate into one.

2. **`matchAddChain16` / `matchAddChain16Ld`**: fire when
   `Terms.size() + (HasConst ? 1 : 0) >= 3` (so `a+b+c` (3 loads) and `a+b+K` (2 loads +
   const) both qualify, while `a+b` and `a+K` stay the 2-operand `alu16_abs`/`alu16_absld`
   immediate cases — disjoint).

3. **`applyAddChain16` / `applyAddChain16Ld`**: after the term globals, append ONE
   immediate operand `(ConstSum & 0xFFFF)` when `HasConst`. Memrefs unchanged (only the
   global loads, plus the store for the store-rooted form).

4. **`selectAddChain16` / `selectAddChain16Ld`**: detect a trailing `isImm()` operand. The
   global terms are `lda t0; (clc; adc tI)…`; the constant (if present) is a final
   `clc; adc #imm`; then the store / `STAImag16`. Operand and memref indices account for
   the optional trailing immediate.

## Test

`examples/65816/a16chainimm.c` + `dev/a16chainimm.sh`: a store-rooted `g = a + b + c + K`
and a multi-use `t = a + b + c + K; …` (exercising both apply/select paths). Disasm gate
asserts the chain threads through A16 (`adc abs` per global term + one `adc #imm`, no
intermediate Imag16 round-trip — `sta zp` count minimal). Distinctive `corpus_result`;
MAME + bsnes-jg agree; `-verify-machineinstrs` clean.

## Verification steps

1. `dev/run.sh a16chainimm` — green on both emulators; disasm shows one A16-threaded
   chain ending in `adc #imm`.
2. `dev/run.sh a16chain a16chainld a16loadfold a16imm` — the no-const chains and the
   2-operand immediate folds still green (unaffected / disjoint).
3. Full a16 suite (30 tests) + `dev/run.sh corpus` (7/7).
4. `-mllvm -verify-machineinstrs` clean on a16chainimm.
5. `dev/regen-patch.sh` round-trips.

## Verification evidence (2026-06-15)

1. `dev/run.sh a16chainimm`:

   ```
   adc-abs=4  adc-imm=2  sta-zp=2
   PASS: 2 adc #imm — each chain's constant folded INTO the chain
   PASS: 4 adc abs — chain globals read directly
   PASS: 2 sta zp — chains thread A16, no per-add round-trip
   SMOKE: PASS addr=0x7E020C len=2 got=0x2569 (MAME) / off=0x20C got=0x2569 (bsnes-jg)
   RESULT: PASS
   ```
   Disasm: store-rooted `lda a; clc; adc b; clc; adc c; clc; adc #4; sta os` and the
   multi-use variant ending `adc #5; sta t` — both threaded, no round-trips. PASS.

2. `a16chain`, `a16chainld`, `a16loadfold`, `a16imm` — all PASS (no-const chains and the
   2-operand immediate folds unaffected / disjoint). PASS.

3. Full a16 suite (30 tests) + `dev/run.sh corpus`: all 31 green (`FAIL: NONE`). PASS.

4. `-mllvm -verify-machineinstrs` on a16chainimm → `rc=0`. PASS.

5. `dev/regen-patch.sh`: `RESULT: PASS — 0002 round-trips`. PASS.
