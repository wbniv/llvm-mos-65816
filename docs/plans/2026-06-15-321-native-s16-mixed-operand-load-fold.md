# #321 native s16 — mixed-operand load-fold (`t = a16v OP local`)

Load-fold follow-up **(a)**: a 16-bit ALU op with **one** near-abs global operand and
**one** Imag16 register operand (a local, a multi-use value) currently materializes the
global into an Imag16 pair (`lda abs; sta tmp`) before the op. Read the global directly
via the absolute ALU form instead — mirroring the both-global `selectAlu16AbsLd` fold,
but per-operand.

## Background

The both-operands-global cases are folded at the **combiner** level
(`matchAlu16Abs`/`matchAlu16AbsLd` → `G_*16_ABS`/`G_*16_ABSLD`, which `nearAbsLoad`
gates on *both* operands being single-use near-abs loads, or one load + one constant).
The **mixed** case (one near-abs load + one register) matches neither, so the op stays
a plain `G_ADD`/`G_SUB`/`G_AND`/`G_OR`/`G_XOR` and reaches `selectAlu16Native`, which
today loads operand A via `LDAImag16` and uses the Imag16 ALU form (`ADCImag16` …) for
operand B — so a global operand had to be lowered to an Imag16 temp first (`G_LOAD16_ABS`
selects independently to `lda abs; sta tmp`).

By selection time the operands are `G_LOAD16_ABS @g` pseudos (the legalizer's
`legalizeLoadStore16`), each single-use (a fresh load per use). `selectAlu16Native`
already sees them — the same situation `selectSbc16` exploited for the compare-operand
fold (committed `ef4671d`, reusing the `foldableAbsLoad16` helper).

The absolute ALU forms already exist and are used by `selectAlu16Abs`/`selectAlu16AbsLd`:
`ADCAbs16`, `SBCAbs16`, `ANDAbs16`, `ORAAbs16`, `EORAbs16` (`OP abs`, MLow=1, one memref)
and `LDAbs16` (`lda abs`). This increment just routes a mixed operand into them.

## Design — two independent fold sites in `selectAlu16Native`

For `dst = A OP B`, after the existing immediate-fold (which may set `Imm` and, for
commutative ops, swap so the constant is B):

- **LHS load (operand A → A16):** if `foldableAbsLoad16(A)`, emit `LDAbs16 A`
  (lda abs straight into A16); else `LDAImag16 A` (unchanged).
- **ALU operand (operand B):** `Imm` → `*Imm16` form (unchanged); else if
  `foldableAbsLoad16(B)`, use the **absolute** ALU opcode (`OP abs B`); else the Imag16
  ALU opcode (`OP B`, unchanged).

This is uniform across all five ops and needs **no commutativity swap** for the load
fold, because either operand position has a folding site:

| source                | A      | B      | emitted                               |
|-----------------------|--------|--------|---------------------------------------|
| `loc OP a16v`         | reg    | global | `lda zp loc; OP abs a16v`             |
| `a16v OP loc` (comm.) | global | reg    | `lda abs a16v; OP zp loc`             |
| `a16v - loc` (SUB)    | global | reg    | `lda abs a16v; sec; sbc zp loc`       |
| `loc - a16v` (SUB)    | reg    | global | `lda zp loc; sec; sbc abs a16v`       |

SUB stays correct: the minuend is always operand A (loaded into A16), the subtrahend is
operand B — and both the `LDAbs16` (A=global) and `SBCAbs16` (B=global) sites preserve
that order, so no swap is ever applied to a non-commutative op.

The both-global case (combiner already handles it) would, if it ever reached here, fold
*both* sites → `lda abs A; OP abs B` = exactly `selectAlu16AbsLd`'s output. Harmless.

Volatile-safe by the same 1-to-1 argument as the compare fold: each folded load is
single-use, so exactly one read of the global still happens, in program order. Folded
loads are erased after constraining (single-use; this op was their only consumer;
selection is bottom-up so they are not yet selected). `LdA`/`LdB` can't alias (if `A==B`
the reg has two uses → `foldableAbsLoad16` returns null for both).

## Implementation

`MOSInstructionSelector.cpp`, `selectAlu16Native`: add `AbsOpc` to the per-opcode switch
(`ADCAbs16`/`SBCAbs16`/`ANDAbs16`/`ORAAbs16`/`EORAbs16`), then the two fold sites above
+ a `Folded` vector erased at the end. Reuses the existing `foldableAbsLoad16`.

## Test

`examples/65816/a16mixfold.c` + `dev/a16mixfold.sh` (cloned from `a16loadfold.sh`):
`loc` is a multi-use local (so its def is non-foldable, materialized into one Imag16
pair) combined with single-use near-abs global `a16v` across ADD/SUB(both directions)/
AND/OR/XOR. Disasm gate asserts the absolute ALU forms appear (global read directly) and
that `a16v` is **not** materialized into an Imag16 pair (no `lda abs; sta zp` round-trip
for it). Distinctive `corpus_result`; MAME + bsnes-jg agree; `-verify-machineinstrs` clean.

## Verification steps

1. `dev/run.sh a16mixfold` — new test green on both emulators; disasm shows the abs ALU
   forms and no per-op Imag16 materialization of the global.
2. `dev/run.sh a16loadfold a16add a16sub a16bit a16local` — the existing ALU suite still
   green (both-global fold, immediate fold, and pure-Imag16 native path unaffected).
3. Full a16 suite (24 tests) + `dev/run.sh corpus` (7/7).
4. `-mllvm -verify-machineinstrs` clean on a16mixfold + a16loadfold.
5. `dev/regen-patch.sh` round-trips.

## Verification evidence (2026-06-15)

1. `dev/run.sh a16mixfold`:

   ```
   lda-abs=5  abs-ALU=2  materializations(lda abs;sta zp)=1  direct-global-reads=6
   PASS: a16v never materialized into an Imag16 pair (sole lda abs;sta zp is loc init)
   PASS: 6 direct global reads — each of the 6 mixed ops reads a16v in place
   SMOKE: PASS addr=0x7E0204 len=2 got=0x2DC0 (ran 60 ticks)          # MAME
   SMOKE: PASS off=0x204 len=2 got=0x2DC0 (ran 180 frames, bsnes-jg)  # bsnes-jg
   RESULT: PASS
   ```
   (Disasm: ADD/SUB/AND/OR/XOR each read `a16v` via `lda abs`/`adc|sbc abs`, no temp.) PASS.

2. `a16loadfold`, `a16add`, `a16sub`, `a16bit`, `a16local` — all PASS (both-global fold,
   immediate fold, pure-Imag16 native path unaffected).

   Note: `a16localx`'s disasm gate counted `adc zp` only; the mixed fold correctly turns
   `u = t + c16v` (local + global) into `adc abs`, so the gate was updated to count native
   adds across **both** forms (3 `adc zp` + 2 `adc abs` = 5 source adds). Value 0x33A0 and
   `-verify-machineinstrs` unchanged. PASS.

3. Full a16 suite (24 tests) + `dev/run.sh corpus`: all 25 green (`FAIL: NONE`). PASS.

4. `-mllvm -verify-machineinstrs` on a16mixfold, a16loadfold, a16add, a16sub, a16bit,
   a16local → all `rc=0`. PASS.

5. `dev/regen-patch.sh`: `RESULT: PASS — 0002 round-trips (reapplied MOS dir == live vendor)`.
   PASS.
