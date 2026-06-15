# #321 native s16 — 1-byte `inc a` / `dec a` (register ±1)

Inc/dec gap, part 1: a 16-bit `x ± 1` on a value in a register/Imag16 pair currently
**drops to 8-bit** — the legalizer routes every s16 `±1` to a byte `G_INC`/`G_DEC`
chain (`sep; ldx; stx; ldx; stx; inc zp; bne; inc zp; rep`), thrashing M-mode inside a
16-bit region. In 16-bit-accumulator mode one `inc a` / `dec a` increments all 16 bits,
so emit `lda x; inc a; sta dst` instead.

## Background

`legalizeAddSub` (MOSLegalizerInfo.cpp) special-cases a `±1` constant RHS to the
multi-byte `G_INC`/`G_DEC` path **even under `+mos-a16`** (a deliberate "smaller, no
accumulator needed" choice from Increment 1d — but it predates native M16 maturity and
is a clear loss inside a 16-bit region). Non-`±1` s16 add/sub already stays native
(`selectAlu16Native`). The global RMW cases (`g ± 1`) never reach here — the
`alu16_abs` combiner grabs `G_STORE(G_ADD(load g, ±1), g)` pre-legalize and emits
`lda; adc #imm; sta` (the `inc abs` memory-RMW form is part 2). So this part only needs
the **register/local** `x ± 1` to stay native and select to `inc a`/`dec a`.

`INC_Accumulator` (`inc a`) / `DEC_Accumulator` (`dec a`) exist as real instructions
(same accumulator-RMW shape as `ASL_Accumulator`). No `MLow=1` 16-bit pseudo wraps them
yet — add `INCAcc16`/`DECAcc16` mirroring `ASLAcc16`/`LSRAcc16`.

## Implementation

1. **Pseudos** (MOSInstrLogical.td, beside `ASLAcc16`): `INCAcc16`/`DECAcc16` —
   `MLow=1`, `Constraints "$dst = $src"`, `(outs Ac16:$dst)`/`(ins Ac16:$src)`,
   `PseudoInstExpansion<(INC_Accumulator)>` / `<(DEC_Accumulator)>`. Gated `HasAccum16`.

2. **Legalizer** (`legalizeAddSub`): under `hasAccum16` + s16, return the op un-narrowed
   **including `±1`** (an early native passthrough before the `±1`/byte path), so the
   local `x ± 1` reaches `selectAlu16Native`. Default 8-bit codegen keeps the byte path.

3. **`selectAlu16Native`**: detect a `±1` step from a constant operand and emit
   `INCAcc16`/`DECAcc16` on A16 instead of `(clc;) adc #1`:
   - `G_ADD` by `+1` (`0x0001`) → inc; by `-1` (`0xFFFF`) → dec (commutative — the const
     may be either operand; normalize so the value is loaded).
   - `G_SUB` by `+1` → dec; by `-1` → inc (the const must be the subtrahend B; `1 - x`
     is not a dec).
   Reuses the existing LHS-load fold (`foldableAbsLoad16`): `lda abs` if the value is a
   near-abs global, else `lda zp`. Then `inc|dec a`, then `sta dst` (Imag16). All
   `MLow=1` → one rep/sep bracket; value enters A16 only via the load and leaves only via
   the store (no Ac16↔8-bit COPY — the native invariant).

The signed-`-1` form is `0xFFFF` as a 16-bit immediate (`getImm16Operand` masks to 16
bits); the canonicalizer also turns `x - 1` into `x + 0xFFFF` in some paths, so both
`G_ADD 0xFFFF` and `G_SUB 1` must map to dec.

## Test

`examples/65816/a16incdec.c` + `dev/a16incdec.sh`: a loop counter and locals stepped by
`+1`/`-1` so the ops are register `±1` (not global RMW — that's part 2). Disasm gate
asserts `inc a` (0x1a) and `dec a` (0x3a) appear and the 8-bit byte inc/dec chain is
gone (no `e6`/`c6` inc/dec-zp, no `sep`-bracketed shuffle for the step).
`corpus_result==0x2668`; MAME + bsnes-jg agree; `-verify-machineinstrs` clean.

Companion test `examples/65816/a16loopred.c` + `dev/a16loopred.sh`: a counted increment
loop `while (i) { x = x + 1; i = i - 1; }` strength-reduces to a single native 16-bit
add (`x += n`). End-to-end correctness guard that the loop-combine stays semantically
correct after the add/sub + inc/dec legalization changes — distinct from the inc/dec
gate (the `inc`/`dec` vanish in the reduced form; what's asserted is a 16-bit `adc`, no
8-bit byte chain, no libcall, `corpus_result==0x1239`).

## Verification steps

1. `dev/run.sh a16incdec` — green on both emulators; disasm shows `inc a`/`dec a`, no
   8-bit byte inc/dec chain.
2. `dev/run.sh a16loop a16add a16sub a16localimm a16localsub` — existing add/sub/loop
   suite still green (non-±1 native path and the byte path for default codegen
   unaffected).
3. Full a16 suite (26 tests) + `dev/run.sh corpus` (7/7).
4. `-mllvm -verify-machineinstrs` clean on a16incdec.
5. `dev/regen-patch.sh` round-trips.

## Verification evidence (2026-06-15)

1. `dev/run.sh a16incdec`:

   ```
   inc a=2  dec a=2  inc-zp(e6)=0  dec-zp(c6)=0
   PASS: 2 inc a — native 16-bit increments
   PASS: 2 dec a — native 16-bit decrements
   PASS: no 8-bit byte inc/dec chain (fully native)
   SMOKE: PASS addr=0x7E020C len=2 got=0x2668 (MAME) / off=0x20C got=0x2668 (bsnes-jg)
   RESULT: PASS
   ```
   `dev/run.sh a16loopred` → `adc=1 inc-zp=0 dec-zp=0 jsr=0`, `got=0x1239` on both. PASS.

2. `a16loop`, `a16add`, `a16sub`, `a16localimm`, `a16localsub` — all PASS.

   Two disasm gates needed updating because the change **improved** mode-tracking (the
   trailing `+1` in each test is now a native `inc a` instead of an 8-bit byte inc that
   forced a mode switch): `a16ashift` no longer needs a `sep` (stays one M16 region —
   gate now asserts the `+1` is native `inc a`), and `a16ptr`'s two `rep` regions merged
   into one (gate relaxed `>=2` → `>=1`). Both values (0xFE01, 0xABCE) and
   `-verify-machineinstrs` unchanged. PASS.

3. Full a16 suite (27 tests) + `dev/run.sh corpus`: all 28 green (`FAIL: NONE`). PASS.

4. `-mllvm -verify-machineinstrs` on a16incdec, a16loopred, a16ashift, a16ptr → all
   `rc=0`. PASS.

5. `dev/regen-patch.sh`: `RESULT: PASS — 0002 round-trips`. PASS.
