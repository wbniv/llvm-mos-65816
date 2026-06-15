# #321 native s16 — 16-bit bitwise chains (`a & b & c`, `| `, `^`)

ALU-chain extension: a homogeneous ≥3-term AND/OR/XOR chain of near-abs globals threads
the running value through A16 (`lda a; and b; and c; sta`) instead of round-tripping
each partial result through an Imag16 pair. The add-chain machinery (Increment 1c +
`add_chain16_ld` + the immediate-term fold) generalizes to the bitwise ops, which are
homogeneous, associative, and — unlike ADD — need **no carry-init** (no `clc`).

## Background

`a & b & c` lowers to a homogeneous `G_AND` tree (`%t = a&b; %u = %t&c`) — the
reassociation combiner keeps bitwise chains homogeneous (it does NOT reshape them like
`a-b-c → a-(b+c)`, which is why SUB chains are moot). Today each `&`/`|`/`^` folds its
global operand (`and abs`, via the load-fold) but the running value round-trips: `lda a;
and abs b; sta tmp; lda tmp; and abs c; sta tmp; …`. The bitwise abs/imm forms
(`ANDAbs16`/`ORAAbs16`/`EORAbs16`, `ANDImm16`/…) already exist (single-def, `$dst=$l`,
no carry).

## Implementation (low-risk: ADD path untouched)

The working ADD chain (`G_ADDCHAIN16_ABS`/`ABSLD`, `selectAddChain16`/`Ld`, its
combiners) is **not** modified — only the shared tree walk is generalized — so a bug in
the new bitwise code cannot affect add chains.

1. **`collectAddChain` → `collectAluChain(R, RootOpc, …)`**: parameterize by the chain
   operator. A constant leaf folds into `ConstAcc` using the op's combine
   (`+`/`&`/`|`/`^`, via `combineChainConst`); the ADD callers pass `G_ADD` (behavior
   identical — const fold is still `+`).

2. **Pseudos** `G_BITCHAIN16_ABS` / `G_BITCHAIN16_ABSLD` (MOSInstrGISel.td): op 0 =
   store global (ABS) / result def (ABSLD), op 1 = the bitwise opcode (`G_AND`/`G_OR`/
   `G_XOR`) as an immediate, ops 2..G+1 = term globals, optional trailing constant
   immediate. Memrefs: G loads (+ store for ABS).

3. **Combiners** `bit_chain16` (root `G_STORE`) / `bit_chain16_ld` (root `G_AND`/`G_OR`/
   `G_XOR`): `matchBitChain16{,Ld}` mirror the add-chain matchers but for a bitwise root
   (disjoint from `add_chain16` by opcode); collect via `collectAluChain`, threshold
   `loads + (const?1:0) >= 3`; `applyBitChain16{,Ld}` build the pseudo with the opcode +
   optional const operand.

4. **Selector** `selectBitChain16{,Ld}`: read the opcode operand, map to
   `ANDAbs16`/`ORAAbs16`/`EORAbs16` (+ the imm forms for a const term); emit
   `lda t0; OP t1; …; (OP #imm)?; sta` — single-def ops, **no `clc`**.

## Test

`examples/65816/a16bitchain.c` + `dev/a16bitchain.sh`: store-rooted `g = a & b & c`,
multi-use `t = a | b | c` (reused), and an XOR chain (optionally `+ const`). Disasm gate
asserts the chains read each global via `and/ora/eor abs` and thread through A16 (no
intermediate Imag16 round-trip, no `clc`). Distinctive `corpus_result`; MAME + bsnes-jg
agree; `-verify-machineinstrs` clean.

## Verification steps

1. `dev/run.sh a16bitchain` — green on both emulators; disasm shows threaded bitwise
   chains (no round-trips, no carry-init).
2. `dev/run.sh a16chain a16chainld a16chainimm a16bit` — the add chains and the 2-operand
   bitwise folds still green (ADD path untouched / disjoint).
3. Full a16 suite (31 tests) + `dev/run.sh corpus` (7/7).
4. `-mllvm -verify-machineinstrs` clean on a16bitchain.
5. `dev/regen-patch.sh` round-trips.

## Verification evidence (2026-06-15)

1. `dev/run.sh a16bitchain`:

   ```
   and-abs=2  ora-abs=2  eor-abs=2  sta-zp=3
   PASS: 2 and abs — AND chain reads globals directly
   PASS: 2 ora abs — OR chain reads globals directly
   PASS: 2 eor abs — XOR chain reads globals directly
   PASS: 3 sta zp — chains thread A16, no per-op round-trip
   SMOKE: PASS addr=0x7E0210 len=2 got=0x6261 (MAME) / off=0x210 got=0x6261 (bsnes-jg)
   RESULT: PASS
   ```
   Disasm: each chain is `lda a; OP b; OP c; sta` (store-rooted AND/XOR → `sta abs`,
   multi-use OR → `sta zp`), no carry-init, no `lda zp` mid-chain. PASS.

2. `a16chain`, `a16chainld`, `a16chainimm`, `a16bit` — all PASS (the ADD chains survive
   the `collectAddChain → collectAluChain` generalization; 2-operand bitwise unaffected). PASS.

3. Full a16 suite (31 tests) + `dev/run.sh corpus`: all 32 green (`FAIL: NONE`). PASS.

4. `-mllvm -verify-machineinstrs` on a16bitchain → `rc=0`. PASS.

5. `dev/regen-patch.sh`: `RESULT: PASS — 0002 round-trips`. PASS.
