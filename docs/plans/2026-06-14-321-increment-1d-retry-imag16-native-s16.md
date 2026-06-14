# M2 / #321 — Increment 1d-retry: GISel-native s16, value resident in Imag16 (no Ac16↔8-bit COPY)

**Date:** 2026-06-14 · **Status:** **STEPS 1–4 DONE — the coalescer crash is SOLVED.** Native s16 add
runs in `Imag16` on both emulators; the exact complex multi-op shape that crashed the prototype now
compiles clean. Step 5 (sub/bitwise/immediate native) is the remaining extension. Supersedes the
reverted [1d prototype](2026-06-14-321-increment-1d-gisel-native-s16.md). · **Milestone:** M2
(ROADMAP step 5). **Builds on:** 1b (`A16` accumulator + `Ac16` + `MOSInsertREPSEP`) and 1c (chains).

## The corrected root-cause (why 1d crashed, and why this won't)

The reverted prototype crashed the register coalescer: an 8-bit constant `LDImm` coalesced into `A16`
(whose sublo *is* the 8-bit `A`), producing a malformed `$a16 = LDImm`. My first two diagnoses —
"the `A16=A` aliasing is the bug" and "any `Ac16` vreg is the bug" — are **both wrong**, proven by the
code:

- The **peephole (1b/1c) already creates `Ac16` vregs** (`MOSInstructionSelector.cpp:1990-1991`,
  `:2054`) and never crashes. So `Ac16` vregs per se are fine.
- The `A16=B:A` aliasing (`MOSRegisterInfo.td:104-109`) is **load-bearing for soundness**: the
  peephole emits a *self-contained* `clc;lda;adc;sta` on **physical/transient `A16`** spanning several
  instructions; the allocator only knows `A` is occupied across that span *because* `A16` aliases `A`.
  Remove the aliasing → the scavenger could stick an 8-bit value in `A` mid-bracket → silent
  miscompile. So **keep the aliasing.**

The precise invariant the peephole satisfies and the prototype violated:

> **No `COPY` (or subreg-COPY) ever bridges an `Ac16` vreg and an 8-bit vreg.** The accumulator is
> entered/left **only via load/store instructions** (`LDAbs16`/`STAbs16` — and, new here,
> `LDAImag16`/`STAImag16`), never via `COPY`. The s16 *value*'s home register class is **`Imag16`**
> (zero-page pairs), genuinely independent of `A`. 8-bit↔16-bit boundaries go through `Imag16`'s own
> byte subregs (`Imag8` = `EXTRACT_SUBREG ..., sublo/subhi`), never through `A16`.

The prototype broke this by keeping the value resident *in* `Ac16` and shuffling it to/from `Imag16`
with `copyPhysReg` (which emits COPY-like transfers) — that COPY is exactly what an 8-bit `LDImm`
coalesced into. **This retry never does that:** every native s16 op is a self-contained
`LDAImag16 → (clc;) ADCImag16 → STAImag16` sequence, mirroring `selectAlu16Abs` but with `Imag16`
operands. The value lives in `Imag16` between ops (normal allocatable/spillable vregs); `A16` is the
transient accumulator within one op, reached only by load/store. No bridging COPY ⇒ nothing for the
coalescer to corrupt.

## What this unlocks (the cases the peephole can't do)

The 1b/1c combiner only fires on `g = a OP b` shapes over **globals**. This makes the GISel pipeline
carry an `s16` **value** through `Imag16`, so **locals, multi-use intermediates, arbitrary s16
dataflow** work — e.g. the peephole-impossible:
```c
unsigned short f(void){ unsigned short t = a + b; return t & c; }  // t local, reused
```

## Decomposition — each step verified non-breaking (corpus 7/7 + a16* suite) before the next

**Step 1 — `Imag16`-operand ALU ops (inert).** Add `LDAImag16`/`STAImag16` (lda/sta zp, 16-bit,
`MLow=1`, `Ac16`↔`Imag16`), `ADCImag16`/`SBCImag16`, `ANDImag16`/`ORAImag16`/`EORImag16` —
PseudoInstExpand to the `_ZeroPage` real opcodes, same `Ac16` accumulator shape as the `*Abs16` ops
(`MOSInstrLogical.td:600-674`) but reading a zero-page `Imag16` operand instead of `addr16`. Not
selected by anything yet. *Verify: tablegen builds, corpus 7/7, all six a16* tests still pass (proves
the new ops don't perturb the peephole).* **Open Q to resolve here:** their MC lowering —
`PseudoInstExpansion<(ADC_ZeroPage addr8:$r)>` needs the `Imag16` operand to lower to the zp address
of its **low** byte (like `ADCImag8`, `MOSInstrLogical.td:95`); confirm the imag-reg→zp-addr lowering
treats the `Imag16` operand's sublo correctly (it already does for `LDImag8`/`STImag8`).

**Step 2 — legalizer keeps s16 `G_ADD` native under `hasAccum16`** (split from `G_SUB`), and keeps
s16 `{G_LOAD,G_STORE}` un-narrowed so a load feeding the add stays s16. The cohesive core: load/store/
add go native together. *Verify: `-verify-machineinstrs` clean; no GISel fallback; corpus 7/7 (the
gate is `STI.hasAccum16()`, so default builds are untouched).*

**Step 3 — RegBankSelect + InstructionSelect for native s16 add.** s16 → `AnyRegBank` → `Imag16`
class. `selectAdd16Native(MI)`: mirror `selectAlu16Abs` (`:1958`) — `LDAImag16 a` (or fold a near-abs
global load to `LDAbs16`), `clc`, `ADCImag16 b` (or `ADCAbs16`), `STAImag16 dst`. Operands & result
are `Imag16`; `Ac16` only the transient def-chain (`Lo→Res`); **no COPY to/from 8-bit**.
*Verify:* `examples/65816/a16local.c` (a multi-use local s16 add — forces the native path past the
peephole) compiles **without the coalescer crash** and runs `0x1122` on **both** emulators; corpus
7/7; all six prior a16* tests green.

**Step 4 — the previously-crashing complex case.** `examples/65816/a16localx.c` — ≥3 s16 ops + a
reused local + a select (the exact shape that produced `$a16 = LDImm`). *Verify: compiles clean (no
coalescer crash), runs correct on both emulators.* **This is the proof the root-cause fix holds.**

**Step 5 — extend to sub / bitwise / immediates native**, then iterate outward (chains already work
via 1c's `selectAddChain16`; unify later). *Verify each: both emulators + corpus 7/7.*

All edits extend `patches/llvm-mos/0002-321-accum16.patch`.

## Mechanism map (grounded in the current tree)

- **New ops** (`MOSInstrLogical.td`, beside the `*Abs16` block at `:600-674`): `LDAImag16` =
  `MOSLoad`, `PseudoInstExpansion<(LDA_ZeroPage addr8)>`, `(outs Ac16) (ins Imag16:$src)`, `MLow=1`.
  `STAImag16` = `MOSStore`, `(STA_ZeroPage)`, `(ins Ac16:$src, Imag16:$dst)`. `ADCImag16` mirrors
  `ADCAbs16` (`:610`) with `(ins Ac16:$l, Imag16:$r, Cc:$carryin)` → `(ADC_ZeroPage addr8)`. Bitwise
  via a `MOSBitImag16<real>` class paralleling `MOSBitAbs16` (`:633`).
- **Legalizer** `legalizeAddSub` (`MOSLegalizerInfo.cpp:670-682`): currently
  `narrowScalarAddSub(MI,0,S8)` for non-±1 s16 add. Wrap: `if (STI.hasAccum16() && Ty==S16) return
  Legalized;` (leave for the selector). Same early-out idea for the s16 `{G_LOAD,G_STORE}` rule.
  Note `STI` is reachable from the legalizer ctor (the predicate already exists as `HasAccum16`).
- **Selector** `selectAdd16Native`: register in `select()`'s switch beside `selectAlu16Abs`
  (`:254-259`); structure copied from `selectAlu16Abs` (`:1958-2034`) — same `LDImm1` carry-init,
  same `constrainSelectedInstRegOperands` loop; operands `Imag16` instead of `add(GA)`.
- **The invariant guard:** grep the post-isel MIR for any `COPY` whose def or use is `Ac16`/`$a16` —
  there must be **zero**. (A quick `-stop-after=instruction-select` + `grep '= COPY'` check on the
  a16local/a16localx tests.)

## Verification (per step + final)

- **Every step:** 6502 corpus **7/7** (the aliasing guard) + the six 1a–1c a16* tests green + SDK
  builds + vendor↔patch round-trip clean.
- **Core (steps 3-4):** `a16local.c` and `a16localx.c` compile with `-verify-machineinstrs` clean (no
  coalescer crash, **the** regression that killed the prototype) and run correct on **both** MAME and
  bsnes-jg. A regression assert: the post-isel MIR has **no `Ac16` COPY**.
- **Smaller/faster:** the native 16-bit path beats the 8-bit narrowed output on the local-reuse kernel.

### Evidence (2026-06-14) — steps 1–4 PASS

**Step 1 (inert Imag16 ops):** tablegen builds; corpus 7/7; all six a16* peephole tests PASS on both
emulators (the new ops don't perturb the peephole). ✅

**Step 3 (`selectAdd16Native`, `a16local.c`):** the multi-use local add selects to one rep/sep
bracket, value in `Imag16` (`__rc2`/`__rc4`), no `Ac16` COPY:
```
rep #32 ; lda __rc4 ; clc ; adc __rc2 ; sta __rc2 ; sep #32
SMOKE: PASS got=0x1122 (MAME)   SMOKE: PASS got=0x1122 (bsnes-jg)
```

**Step 4 (the prototype-crashing case, `a16localx.c`):** 5 native s16 adds with reused locals
(heavy `Imag16` pressure + spills) — the exact shape that produced `$a16 = LDImm`:
```
PASS: compiled clean (-verify-machineinstrs), no coalescer crash
PASS: 5 native adc-zp ops present ; 3 rep #$20 brackets
SMOKE: PASS got=0x33A0 (MAME)   SMOKE: PASS got=0x33A0 (bsnes-jg)
```

**Non-breaking guard:** corpus **7/7**; a16/a16add/a16sub/a16bit/a16imm/a16chain all PASS on both
emulators. Patch `0002-321-accum16.patch` round-trips (applies on 0001, reproduces vendor exactly). ✅

### Step 5 (remaining) — extend native to sub / bitwise / immediates

`selectAdd16Native` handles ADD with two `Imag16` operands. Still narrowed (so still peephole-only or
8-bit): native s16 **sub** (`SBCImag16`, carry-in set), **bitwise** (`AND/ORA/EORImag16`), and the
**immediate-operand** native case (one operand a `G_CONSTANT` → `ADCImm16`/`ANDImm16`, mirroring the
1b immediate path; `selectAdd16Native` currently assumes both operands are `Imag16`). The legalizer
gate is deliberately restricted to non-±1 s16 **G_ADD** with register operands until these land.

## Out of scope (later)

- Loops + cross-block REP/SEP mode-tracking; the hardware-stack ABI / 16-bit calling convention.
- Unifying the 1b/1c peephole into the native path (the peephole stays as a fast-path for the
  all-global shapes; it is proven and green).
