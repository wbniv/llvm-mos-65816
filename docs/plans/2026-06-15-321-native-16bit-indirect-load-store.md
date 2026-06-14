# #321 native s16 — native 16-bit indirect load/store (`*p`, `a[i]`, `a[i]=v`)

**Date:** 2026-06-15 · **Status:** **DONE** (verified, patch round-trips)

## Evidence (raw output)

`dev/run.sh a16ptr` — store `*p=v` is `sta (zp)` (92), load `*p` is `lda (zp)` (B2),
each under one rep/sep, no `(zp),y` byte pair:
```
      14: c2 20        	rep	#$20
      18: 92 00        	sta	($0)
      1a: e2 20        	sep	#$20
      26: c2 20        	rep	#$20
      28: b2 00        	lda	($0)
      2c: e2 20        	sep	#$20
  PASS: 1 lda (zp) · 1 sta (zp) · no (zp),y byte pair
SMOKE: PASS addr=0x7E0206 len=2 got=0xABCE (ran 60 ticks)
  SMOKE: PASS off=0x206 len=2 got=0xABCE (ran 180 frames, bsnes-jg)
RESULT: PASS — native 16-bit indirect load/store round-trips 0xABCE; both emulators agree
```
`-verify-machineinstrs` clean (after fixing the load memref: it belongs on
`LDAIndir16`, the real load — not the internal `STAImag16`; the verifier caught the
"Missing mayLoad flag" before it could ship). Non-breaking: corpus 7/7 (default
pointer/array codegen untouched by the `hasAccum16` gate), all 20 a16* tests green.
`dev/regen-patch.sh` → 0002 round-trips (2528 lines, 20 files).

## Context

Next in the agreed #321 order: "indexed/array access". Investigation **corrected
the scope**: llvm-mos lowers *all* indexed/array access via computed pointers +
indirect addressing, and the pointer arithmetic is **already native 16-bit** under
`+mos-a16` (the `asl`/`adc` for `a + i*2` are bracketed `rep…sep`). The index
registers stay 8-bit (used only as the +0/+1 byte offset). So the **X-flag (xy16)
mode dimension is NOT needed for array access** — that's a separate, optional, lower-
priority addressing strategy llvm-mos doesn't use (deferred to TODO to re-evaluate).

The actual gap: the 16-bit **value** is loaded/stored through the computed pointer
as **two 8-bit indirect ops** instead of one native 16-bit op. Today:
```
g = *p;     ->  lda (zp); sta __rc; ldy #1; lda (zp),y; ... sta g   (byte pair)
a[i] = v;   ->  lda lo; sta (zp); ldy #1; lda hi; sta (zp),y         (byte pair)
```
Native (this increment):
```
g = *p;     ->  rep #$20; lda (zp); sta g; sep #$20
a[i] = v;   ->  rep #$20; lda v; sta (zp); sep #$20
```
i.e. `lda (zp)` / `sta (zp)` in 16-bit-accumulator mode — one 16-bit indirect op.
The 65816 `lda (dp)` / `sta (dp)` (opcodes B2 / 92) load/store 16 bits when M=0;
no new real opcode, just `MLow=1` logical forms (same trick as `LDAbs16`).

**Scope (this increment):** native 16-bit **indirect** `(zp)` load and store only —
the most common pointer-based access (`*p`, `a[i]`, `a[i]=v`, `p[i]`). M-flag only;
reuses the established combiner/legalizer + selector + REP/SEP machinery.

## How native 16-bit memory access already works (the pattern to follow)

`G_LOAD`/`G_STORE` are `.maxScalar(0,S8)` (MOSLegalizerInfo.cpp:344) — s16 normally
narrows to two s8. Native 16-bit *absolute* access exists only because a **pre-
legalizer combiner** (`matchAlu16AbsLd`, MOSCombiner.cpp) recognizes s16 `G_LOAD`
operands of an ALU op and rewrites to `G_*16_ABS` before narrowing. A **plain**
16-bit load/store (no ALU) has no such rule, so it narrows — that's the gap.

For s8, `legalizeLoad`/`legalizeStore` (MOSLegalizerInfo.cpp:~1690/1732) call
`selectAddressingMode`, which picks `G_LOAD_INDIR`/`G_STORE_INDIR` (line ~2056) vs
abs/indexed from the address pattern. We reuse exactly this: route s16 through the
same addressing-mode selection, emitting 16-bit indirect pseudos.

## Design — route s16 indirect load/store native

### 1. New 16-bit logical forms — `MOSInstrLogical.td` (by `LDAImag16`, ~694)
Mirror `LDIndir`/`STIndir` (lines 536/572) with `MLow=1`, `Ac16`:
```
def LDAIndir16 : MOSLoad, PseudoInstExpansion<(LDA_Indirect addr8:$addr)> {
  let Predicates = [HasAccum16];   // LDA (zp) is 65C02+; w65816 has it
  let MLow = 1;
  dag OutOperandList = (outs Ac16:$dst);
  dag InOperandList = (ins Imag16:$addr);
}
def STAIndir16 : MOSStore, PseudoInstExpansion<(STA_Indirect addr8:$addr)> {
  let Predicates = [HasAccum16];
  let MLow = 1;
  dag InOperandList = (ins Ac16:$src, Imag16:$addr);
}
```

### 2. New generic pseudos — `MOSInstrGISel.td` (by `G_LOAD_INDIR`)
`G_LOAD16_INDIR` (outs s16 dst; ins ptr addr; mayLoad) and `G_STORE16_INDIR`
(ins s16 val, ptr addr; mayStore), `Predicates = [HasAccum16]`, mirroring the 8-bit
`G_LOAD_INDIR`/`G_STORE_INDIR`.

### 3. Legalizer — route s16 indirect through `selectAddressingMode`
- `MOSLegalizerInfo.cpp:338`: under `STI.hasAccum16()`, add `S16` to the
  `customForCartesianProduct` data-type set so s16 loads/stores reach the custom
  handler instead of `maxScalar`-narrowing.
- In `legalizeLoad`/`legalizeStore`, when `hasAccum16() && type==S16`: run the same
  address analysis as the s8 path; **if it resolves to the indirect case** (a
  pointer in zp, no constant/index offset — the `!Index` branch at line 2054),
  emit `G_LOAD16_INDIR`/`G_STORE16_INDIR`. **Otherwise fall back to narrowing**
  (`Helper.narrowScalar` / the existing path) so abs and indexed 16-bit access
  stay byte-wise for now (follow-ups).

### 4. Selector — `MOSInstructionSelector.cpp`
`G_LOAD16_INDIR` → `LDAIndir16` (def `Ac16`, use Imag16 addr) + `STAImag16` (result
→ Imag16 dst), mirroring `selectAlu16AbsLd`'s result handling. `G_STORE16_INDIR` →
`LDAImag16` (value Imag16 → Ac16) + `STAIndir16` (Ac16 → addr). Both runs are all
`MLow=1`, so MOSInsertREPSEP brackets each with one rep/sep. The value enters/leaves
A16 only via the Imag16 load/store — no Ac16↔8-bit COPY.

## Test — `examples/65816/a16ptr.c` + `dev/a16ptr.sh`
```c
volatile unsigned short v = 0xABCD;
unsigned short slot;
unsigned short * volatile p = &slot;
volatile unsigned short corpus_result;
int main(void) {
  *p = v;                 // native 16-bit indirect store -> slot = 0xABCD
  corpus_result = *p + 1; // native 16-bit indirect load  -> 0xABCE
  for (;;) {}
}
```
Result **0xABCE**. Disasm gate: `lda (zp)` (B2) and `sta (zp)` (92) present under
rep/sep, and **no** `(zp),y` byte-pair (`91`/`B1` with `ldy #1`) for the access;
MAME + bsnes-jg assert 0xABCE. Wire `a16ptr` into `dev/run.sh`.

## Verification
1. Build clean (`dev/run.sh toolchain`); `-verify-machineinstrs` clean on a16ptr.
2. `dev/run.sh a16ptr` → one rep/sep bracket with `lda (zp)`/`sta (zp)`, no byte
   pair; corpus_result == 0xABCE on MAME + bsnes-jg.
3. Non-breaking: corpus 7/7 + all 19 a16* + a16ptr green. (corpus exercises pointer
   code without `+mos-a16`, confirming the gate leaves default codegen untouched.)
4. `dev/regen-patch.sh` → 0002 round-trips.
If keeping s16 loads native destabilizes selection (e.g. an s16 G_LOAD reaches a
path that can't handle it) and isn't resolved within the 3-attempt debugging limit,
revert and record the failure mode — must not ship a load/store miscompile.

## Land
Regen patch 0002; update ROADMAP step 5 + TODO (Done; add the deferrals below);
fill this plan's evidence; commit on `main` with Co-Authored-By; push.

## Deferred to TODO (per this increment's scope decision)
- **Indexed 16-bit load/store**: `abs,x` (array-sum loops: `ldy a,x; lda a+1,x` →
  `rep; lda a,x; sep`) and `(zp),y` — the indexed/indirect-indexed variants.
- **Plain 16-bit absolute** load/store of a standalone global (`g = gg`) where no
  ALU fold applies (the ALU-fused abs case already works via the load-fold).
- **X-flag (xy16) mode dimension** — 16-bit index registers (`rep/sep #$10`); a
  separate mode dimension in MOSInsertREPSEP enabling `lda abs,x` with a 16-bit
  index. Re-evaluate value later (llvm-mos's pointer-based lowering may make it
  marginal).

## Critical files
- `vendor/.../MOSInstrLogical.td` — `LDAIndir16`/`STAIndir16` (~694).
- `vendor/.../MOSInstrGISel.td` — `G_LOAD16_INDIR`/`G_STORE16_INDIR`.
- `vendor/.../MOSLegalizerInfo.cpp` — s16 in the load/store custom set (~338) +
  indirect-native branch in `legalizeLoad`/`legalizeStore` (~1690/1732, reuse the
  `selectAddressingMode` indirect branch ~2054).
- `vendor/.../MOSInstructionSelector.cpp` — select `G_LOAD16_INDIR`/`G_STORE16_INDIR`.
- `examples/65816/a16ptr.c`, `dev/a16ptr.sh` (new); `dev/run.sh` (wire-in).
- `patches/llvm-mos/0002-321-accum16.patch`; `docs/ROADMAP.md`; `TODO.md`; this plan.
