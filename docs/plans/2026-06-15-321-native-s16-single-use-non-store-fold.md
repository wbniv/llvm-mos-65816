# #321 native s16 — load-fold follow-up (b): single-use-non-store results

Load-fold follow-up **(b)**: a 16-bit ALU op `dst = a OP b` with near-abs global
operands whose **result is single-use but the use is not a near-abs store** — e.g.
`(a16v + b16v)` feeding another op, a compare, a shift, or an indirect store. The
load-fold core's `matchAlu16AbsLd` explicitly skips these (`if hasOneNonDBGUse(Dst)
return false;`), and the store peephole `matchAlu16Abs` needs the result to feed a
near-abs store, so before this work the globals were materialized into Imag16 pairs.

## Finding: already covered by the mixed-operand fold

The mixed-operand load-fold (committed `75b395e`) generalized `selectAlu16Native` to
fold **any** single-use near-abs `G_LOAD16_ABS` operand directly — operand A into the
LHS `lda abs` (`LDAbs16`), operand B into the absolute ALU form (`adc|sbc|and|ora|eor
abs`). That fold is keyed purely on the **operands**, not on the result's use-count or
its consumer. So a single-use-non-store op simply reaches `selectAlu16Native` (neither
combiner fires) and its global operands fold there — including the **both-global** case
(both A and B fold, giving `lda abs a; OP abs b`, identical to `selectAlu16AbsLd`).

Verified empirically (no code change needed):

```c
r += (a + b) ^ c;   // (a+b): both-global, single-use, non-store
r += (a - b) | d;   // (a-b): SUB
r += (a & b) + c;   // (a&b): AND
```

→ each inner op emits `lda abs a; (clc|sec;) adc|sbc|and abs b; sta tmp` with **zero**
`lda abs; sta zp` materializations of any global (9/9 global operand reads direct);
`-verify-machineinstrs` clean.

So (b) needs no new codegen — it was completed implicitly by the `selectAlu16Native`
generalization. What's missing is a **regression guard**: no existing test asserts the
both-global single-use-non-store shape on the emulators (`a16loadfold` has a multi-use
result, `a16mixfold` has one global + one local, `a16localx` has Imag16-local operands).

## Test

`examples/65816/a16sunfold.c` + `dev/a16sunfold.sh`: three both-global single-use-non-
store ALU ops (ADD/SUB/AND) each feeding a further non-store op, `corpus_result==0x3480`.
Disasm gate asserts **no** global is materialized into an Imag16 pair (`lda abs; sta zp`
adjacency == 0) and the absolute ALU forms appear (operands read in place). MAME +
bsnes-jg agree; `-verify-machineinstrs` clean.

## Verification steps

1. `dev/run.sh a16sunfold` — green on both emulators; disasm shows the abs ALU forms and
   zero global materialization.
2. `dev/run.sh a16loadfold a16mixfold a16localx a16chain` — the existing fold/chain suite
   still green (multi-use, mixed, and add-chain paths unaffected).
3. Full a16 suite (25 tests) + `dev/run.sh corpus` (7/7).
4. `-mllvm -verify-machineinstrs` clean on a16sunfold.
5. `dev/regen-patch.sh` round-trips (no MOS source change this increment — patch is
   unchanged; round-trip still verified).

## Verification evidence (2026-06-15)

1. `dev/run.sh a16sunfold`:

   ```
   lda-abs=3  abs-ALU=6  materializations(lda abs;sta zp)=0  direct-global-reads=9
   PASS: no global materialized into an Imag16 pair (every operand read in place)
   PASS: 6 absolute ALU ops — second operands folded (>=1 per inner op)
   PASS: 9 direct global reads — both operands of each inner op read in place
   SMOKE: PASS addr=0x7E0208 len=2 got=0x3480 (ran 60 ticks)          # MAME
   SMOKE: PASS off=0x208 len=2 got=0x3480 (ran 180 frames, bsnes-jg)  # bsnes-jg
   RESULT: PASS
   ```
   Disasm: each inner op is `lda abs a; (clc|sec;) adc|sbc|and abs b; sta tmp` — both
   globals read in place, 0 materializations. PASS.

2. `a16loadfold`, `a16mixfold`, `a16localx`, `a16chain` — all PASS (multi-use, mixed,
   Imag16-local, and add-chain paths unaffected).

3. Full a16 suite (25 tests) + `dev/run.sh corpus`: all 26 green (`FAIL: NONE`). PASS.

4. `-mllvm -verify-machineinstrs` on a16sunfold → `rc=0`. PASS.

5. `dev/regen-patch.sh`: `RESULT: PASS — 0002 round-trips`. Patch `git diff` empty — no
   MOS source change this increment (the fold was already implemented by `selectAlu16Native`
   in `75b395e`). PASS.
