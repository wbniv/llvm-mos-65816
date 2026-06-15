# #321 native s16 — multi-use 16-bit add chain (`t = a+b+c…`, t reused)

Load-fold follow-up **(c)**: a ≥3-term 16-bit add chain of near-abs globals whose
**result is multi-use** threads the running sum through A16 without intermediate Imag16
round-trips — extending `add_chain16` (Increment 1c) from the store-rooted case to a
register result, exactly as `alu16_absld` extended `alu16_abs`.

## Background

`add_chain16` fuses `g = t0 + t1 + … + tN` (≥3 near-abs-global loads) into
`G_ADDCHAIN16_ABS` → `lda t0; (clc; adc tI)…; sta g` — one A16 thread, no intermediate
`sta tmp; lda tmp`. But it is rooted at a **G_STORE** and `collectAddChain` requires
every node (including the root) to be single-use, so a **multi-use** chain result
(`t = a+b+c+d; g = t; h = t; …`) doesn't match. Today such a chain still folds the
globals per-add (each `adc abs`, via the earlier load-fold work) but round-trips the
running sum through an Imag16 pair between every add (`…; adc abs b; sta tmp; lda tmp;
clc; adc abs c; sta tmp; …`) — N−2 wasted `sta;lda` pairs for an N-term chain.

## Implementation (mirror of `alu16_absld`)

1. **Pseudo** `G_ADDCHAIN16_ABSLD` (MOSInstrGISel.td): like `G_ADDCHAIN16_ABS` but
   `(outs type0:$dst)` (a register result) + variadic term-global ins, `mayLoad` only
   (no store, N load memrefs).

2. **Combiner** `add_chain16_ld` (MOSCombine.td, rooted on `G_ADD`):
   `matchAddChain16Ld` — fire on a `G_ADD` whose s16 result is **multi-use** (the guard
   that keeps `add_chain16`/`alu16_absld` disjoint: single-use-store is `add_chain16`'s,
   2-operand multi-use is `alu16_absld`'s — a ≥3 chain root has one interior-G_ADD
   operand so `alu16_absld`'s both-loads test fails). Collect the chain by running the
   existing `collectAddChain` on the root's **two operands** (it requires single-use
   interior nodes + leaves — correct; only the root may be multi-use); require ≥3 terms.
   `applyAddChain16Ld` builds `G_ADDCHAIN16_ABSLD` with the term globals, redirects the
   root's uses to the new result (`replaceRegWith`), then erases the root, the interior
   adds (pre-order, parent-before-child), and the loads.

3. **Selector** `selectAddChain16Ld` (mirror `selectAddChain16`): operand 0 is the
   result def, operands 1..N the term globals, N load memrefs. Emits
   `lda t0 (LDAbs16); (clc; adc tI (ADCAbs16))…; sta dst (STAImag16)` — the value enters
   A16 only via the loads/adds and leaves only via `STAImag16` (no Ac16↔8-bit COPY).

## Test

`examples/65816/a16chainld.c` + `dev/a16chainld.sh`: `t = a + b + c + d` (4 near-abs
globals), `t` stored to three globals (multi-use). Disasm gate asserts the chain reads
each global via `adc abs` and that there is **no** intermediate Imag16 round-trip in the
chain (the number of `sta zp` between the first `lda` and the final result store drops to
0 — the running sum stays in A16). Distinctive `corpus_result`; MAME + bsnes-jg agree;
`-verify-machineinstrs` clean.

## Verification steps

1. `dev/run.sh a16chainld` — green on both emulators; disasm shows one A16-threaded
   chain (no `sta tmp; lda tmp` between adds).
2. `dev/run.sh a16chain a16loadfold a16mixfold a16sunfold` — the store-rooted chain and
   the 2-operand load-folds still green (disjoint).
3. Full a16 suite (29 tests) + `dev/run.sh corpus` (7/7).
4. `-mllvm -verify-machineinstrs` clean on a16chainld.
5. `dev/regen-patch.sh` round-trips.

## Verification evidence (2026-06-15)

1. `dev/run.sh a16chainld`:

   ```
   adc-abs=3  sta-zp=1
   PASS: 3 adc abs — each chain term read directly (4-term chain)
   PASS: 1 sta zp — sum stays in A16, no intermediate round-trip
   SMOKE: PASS addr=0x7E020C len=2 got=0x1234 (MAME) / off=0x20C got=0x1234 (bsnes-jg)
   RESULT: PASS
   ```
   Disasm: `lda a; clc; adc b; clc; adc c; clc; adc d; sta t` then 3× `lda t; sta g_i`
   (baseline had `sta tmp; lda tmp` between every add — `sta zp` count 3 → 1). PASS.

2. `a16chain`, `a16loadfold`, `a16mixfold`, `a16sunfold` — all PASS (store-rooted chain
   and 2-operand folds unaffected; disjoint). PASS.

3. Full a16 suite (29 tests) + `dev/run.sh corpus`: all 30 green (`FAIL: NONE`). PASS.

4. `-mllvm -verify-machineinstrs` on a16chainld → `rc=0`. PASS.

5. `dev/regen-patch.sh`: `RESULT: PASS — 0002 round-trips`. PASS.
