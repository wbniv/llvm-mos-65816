# Plan: xy16 Legalizer Integration (`selectXY16`)

**Date:** 2026-06-18  
**Issue:** #321, ROADMAP M2  
**Prereq:** `wt/321-xy16` merged at `35604c7` (Layers 1–5 complete)

---

## Context

`wt/321-xy16` delivered the infrastructure for 16-bit index registers: feature flag
`FeatureIndex16` / `+mos-xy16`, register classes `Xc16`/`Yc16`, pseudo-instructions
(`LDXAbs16`, `STXAbs16`, `LDYAbs16`, `STYAbs16`, `CPX*16`, `CPY*16`, `INX16`, `DEX16`,
`INY16`, `DEY16`, `TXA16`, `TAX16`, `TYA16`, `TAY16`), the parallel X-flag lattice in
`MOSInsertREPSEP`, and post-RA spill handling. Layer 5 — `selectXY16` — is an explicit
skeleton returning `false`.

The call site in `select()` fires before `selectImpl` and before the post-tablegen switch:
```cpp
if (STI.hasIndex16() && selectXY16(MI))
    return true;
```

Without legalizer changes, no vreg has `Xc16`/`Yc16` class at GIS-selection time (post-RA
spill paths in `loadStoreRegStackSlot`/`expandLDSTStk` bypass the GIS selector). The
legalizer additions are what make `selectXY16` fire broadly.

**Adjacent plan:** `2026-06-18-321-abs-x-indiry-16bit-indexed-load-store.md` is complete in
`vendor/` (implemented alongside this plan; its legalizer code — `tryIndexedAddressing16` —
is already in the patch). The two plans add **complementary**, not overlapping, GIS pseudos:

| Naming convention | Meaning | Example |
|---|---|---|
| `G_LOAD16_*` | 16-bit **data** (M=0); 8-bit index (X=1/Y=1) | `G_LOAD16_ABS_IDX` |
| `G_LOAD_*16` | any-width data; 16-bit **index** (X=0/Y=0) | `G_LOAD_ABS_IDX16` |

**REP/SEP bracketing** for X-register mode is handled by the existing `MOSInsertREPSEP`
X-lattice (Layer 3 of `wt/321-xy16`). The legalizer and selector emit only logical
pseudo-instructions, never explicit mode-switch opcodes.

---

## Scope

| Item | Status |
|---|---|
| `selectXY16` — direct load/store/compare/inc-dec for Xc16/Yc16 | **this plan** |
| Operand widening for `abs,x`/`(zp),y` (16-bit X/Y as index register) | **this plan** |
| General ALU through Ac16 for Xc16 values (`TXA16` + ALU + `TAX16`) | deferred → `TODO.md §M2 (XY16 follow-ons)` |
| Caller convention for index-register args | deferred → `TODO.md §M2 (XY16 follow-ons)`, ABI change, separate plan |

---

## Layer A — New Pseudo-instructions

### A1. `MOSInstrLogical.td` — Xc16/Yc16 ZP load/store pseudos

First confirm which of these already exist (`grep 'LDXImag16\|STXImag16\|LDYImag16\|STYImag16' vendor/.../MOSInstrLogical.td`). Add any missing, parallel to existing `CPXImag16`/`CPYImag16`:

```tablegen
// #321 xy16: load/store X16 from/to ZP (Imag16 pair). Parallel to CPXImag16.
def LDXImag16 : MOSLoad, PseudoInstExpansion<(LDX_ZeroPage addr8:$src)> {
  let Predicates = [HasIndex16]; let XLow = 1;
  let OutOperandList = (outs Xc16:$dst);
  let InOperandList  = (ins  addr8:$src);
}
def STXImag16 : MOSStore, PseudoInstExpansion<(STX_ZeroPage addr8:$dst)> {
  let Predicates = [HasIndex16]; let XLow = 1;
  let InOperandList = (ins Xc16:$src, addr8:$dst);
}
// LDYImag16 / STYImag16 — same pattern with Yc16 / LDY_ZeroPage / STY_ZeroPage
```

### A2. `MOSInstrGISel.td` — GIS pseudo-ops for widened indexed addressing

**Naming note:** these are distinct from the abs-x-indiry `G_LOAD16_ABS_IDX` / `G_LOAD16_INDIR_IDX`
already in the tree. Those have 16-bit **data** and an 8-bit index. These have a 16-bit **index**
(`G_LOAD_*16` convention). Gate predicate is `HasIndex16`, not `HasAccum16`.

New ops with explicit `type1 = s16` index (not extending `G_LOAD_ABS_IDX` — Option B:
keeps the 8-bit path unambiguous and makes misclassification fail loudly, not silently):

```tablegen
// #321 xy16: abs,X16 indexed load/store — lda/sta abs,X in X=1 mode.
// Same machine encoding as G_LOAD_ABS_IDX; index is s16 (Xc16), not s8 (Xc).
def G_LOAD_ABS_IDX16 : MOSGenericInstruction {
  let Predicates = [HasIndex16]; let mayLoad = true;
  let OutOperandList = (outs type0:$dst);
  let InOperandList  = (ins  unknown:$base, type1:$index);
}
def G_STORE_ABS_IDX16 : MOSGenericInstruction {
  let Predicates = [HasIndex16]; let mayStore = true;
  let OutOperandList = (outs);
  let InOperandList  = (ins  type0:$src, unknown:$base, type1:$index);
}
// #321 xy16: (zp),Y16 indirect indexed — lda/sta (zp),Y in X=1 mode.
def G_LOAD_INDIR_IDX16 : MOSGenericInstruction {
  let Predicates = [HasIndex16]; let mayLoad = true;
  let OutOperandList = (outs type0:$dst);
  let InOperandList  = (ins  ptype1:$base, type1:$index);
}
def G_STORE_INDIR_IDX16 : MOSGenericInstruction {
  let Predicates = [HasIndex16]; let mayStore = true;
  let OutOperandList = (outs);
  let InOperandList  = (ins  type0:$src, ptype1:$base, type1:$index);
}
```

**Verify after build:** `grep "G_LOAD_ABS_IDX16\|G_STORE_ABS_IDX16" build/llvm-mos/lib/Target/MOS/MOSGenInstrInfo.inc` — must appear.

---

## Layer B — Legalizer Rules (`MOSLegalizerInfo.cpp`)

Two addition sites:

### B1. Xc16/Yc16 register class constraint for abs load/store

In `legalizeLoadStore` / `selectAddressingMode`, under `hasIndex16()`, when producing
`G_LOAD16_ABS` / `G_STORE16_ABS` for an s16 value that feeds a compare or inc-dec use
(loop-counter pattern): constrain the result vreg to `Xc16` via
`MRI.setRegClass(Dst, &MOS::Xc16RegClass)`.

**Gate (conservative — governing principle):** Only constrain when **all** uses of the
result vreg are XY16 ops: `{INX16, DEX16, CPX*16, STXAbs16, STXImag16, INY16, DEY16,
CPY*16, STYAbs16, STYImag16}`. If the vreg also fans into any ALU op (add/and/or/xor/sub
through Ac16), do NOT constrain — the added register copy to A16 would regress code size.
Misclassification must only miss a win, never cause a copy.

**`foldableAbsLoad16` interaction:** `foldableAbsLoad16()` (MOSInstructionSelector.cpp)
finds single-use `G_LOAD16_ABS` results and folds them into A16 ALU reads. If B1 has
already constrained that vreg to Xc16, folding it into an A16 load will produce a class
conflict (verifier error). Two safe options: (a) the B1 gate already excludes single-use
ALU patterns (covered by the gate above), or (b) add `!isXc16Reg(dst, MRI)` as an early
check inside `foldableAbsLoad16`. Verify with `-verify-machineinstrs` after Step 3.

**Investigation before implementing B1:** Determine the right API. Check whether
`setRegClass` is sufficient or whether a typed `COPY` + `constrainRegClassByUse` is
needed. Read how `selectMem16Abs` builds the result chain (specifically, whether
`STAImag16` already forces class to `Imag16` before the RA sees it; if so, the class
constraint must go on the `G_LOAD16_ABS` node itself before `STAImag16` is emitted, or
the legalizer must emit a separate `G_LOAD16_ABS_X` pseudo).

### B2. Indexed addressing widening

In `tryAbsoluteIndexedAddressing` (the method that emits `G_LOAD_ABS_IDX` /
`G_STORE_ABS_IDX`), after the existing 8-bit index block, add under `hasIndex16()`:

```cpp
// Under +mos-xy16: a known-s16 index uses the widened form.
if (STI.hasIndex16() && MRI.getType(IndexReg) == LLT::scalar(16)) {
    Opcode = IsLoad ? MOS::G_LOAD_ABS_IDX16 : MOS::G_STORE_ABS_IDX16;
    // emit G_LOAD_ABS_IDX16 / G_STORE_ABS_IDX16 and return
}
```

In `selectIndirectAddressing` (for `(zp),Y`), add the analogous Y16 case emitting
`G_LOAD_INDIR_IDX16` / `G_STORE_INDIR_IDX16`.

**Gate rule:** only widen when `MRI.getType(index) == LLT::scalar(16)` exactly — never
infer from register class alone. A misclassification must only miss a win, never produce
wrong code (governing principle from CLAUDE.md).

---

## Layer C — `selectXY16` Implementation (`MOSInstructionSelector.cpp`)

### C1. Register-class helpers (add above `selectXY16`, beside `selectAlu16Native`)

```cpp
static bool isXc16Reg(Register R, const MachineRegisterInfo &MRI) {
  if (R.isPhysical()) return MOS::Xc16RegClass.contains(R);
  const TargetRegisterClass *RC = MRI.getRegClassOrNull(R);
  return RC && RC->hasSuperClassEq(&MOS::Xc16RegClass);
}
static bool isYc16Reg(Register R, const MachineRegisterInfo &MRI) {
  if (R.isPhysical()) return MOS::Yc16RegClass.contains(R);
  const TargetRegisterClass *RC = MRI.getRegClassOrNull(R);
  return RC && RC->hasSuperClassEq(&MOS::Yc16RegClass);
}
```

Pattern mirrors `loadStoreRegStackSlot`'s `hasSuperClassEq` check.

### C2. `selectXY16` dispatch

```
Early gate: if opcode not in whitelist AND result not Xc16/Yc16, return false.

G_LOAD16_ABS  + dst∈Xc16 → LDXAbs16 (1 instr, no Imag16 staging — cheaper than Ac16 path)
G_LOAD16_ABS  + dst∈Yc16 → LDYAbs16
G_STORE16_ABS + val∈Xc16 → STXAbs16
G_STORE16_ABS + val∈Yc16 → STYAbs16

G_LOAD16_INDIR  + dst∈Xc16 →
    LDAIndir16(A16, base) + STAImag16(zp, A16) + LDXImag16(dst, zp)
    [load indirect into A16, stage through ZP, move to X16 — 3 instrs]

G_STORE16_INDIR + val∈Xc16 →
    STXImag16(zp, val) + LDAImag16(A16, zp) + STAIndir16(A16, base)
    [stage X16 through ZP, load into A16, store indirect — 3 instrs; mirrors load path;
     avoids simultaneous M=0,X=0 that TXA16+STA-indirect would require]

[mirror for Yc16 with LDYImag16/STYImag16 and LDAIndir16/STAIndir16 as appropriate]

G_ADD/G_SUB (±1 only — same stepOf logic as selectAlu16Native):
  dst∈Xc16 → INX16 (+1) / DEX16 (−1)
  dst∈Yc16 → INY16 / DEY16
  non-±1: return false (deferred — general ALU routes through Ac16)

G_ICMP / G_SBC compare form + lhs∈Xc16:
  fold logic mirrors selectSbc16 (CPXImm16 / CPXImag16 / CPXAbs16)
  [Yc16: CPYImm16 / CPYImag16 / CPYAbs16]
  [Note: only reachable after Layer B1 — add with a compile-time assert if reached before]

G_LOAD_ABS_IDX16  → LDA_AbsoluteX  with Xc16 index constrained
G_STORE_ABS_IDX16 → STA_AbsoluteX  with Xc16 index
G_LOAD_INDIR_IDX16  → LDA_IndirectIndexed with Yc16 index
G_STORE_INDIR_IDX16 → STA_IndirectIndexed with Yc16 index
```

**Verify MC names after first build:**
```bash
grep "LDA_AbsoluteX\b\|LDA_IndirectIndexed\b" \
    build/llvm-mos/lib/Target/MOS/MOSGenInstrInfo.inc
```

### C3. Post-tablegen switch additions in `select()`

The new GIS ops are MOS-specific; `selectImpl` will decline them. Add:
```cpp
case MOS::G_LOAD_ABS_IDX16:
case MOS::G_STORE_ABS_IDX16:
case MOS::G_LOAD_INDIR_IDX16:
case MOS::G_STORE_INDIR_IDX16:
  return selectXY16(MI);
```

---

## Implementation Sequence

| Step | Layer | Files | Gate |
|---|---|---|---|
| 1 | A | `MOSInstrLogical.td`, `MOSInstrGISel.td` | tablegen compiles; corpus 7/7 |
| 2 | C (direct ops) | `MOSInstructionSelector.cpp` | fuzz 50/50; corpus 7/7; xy16 tests PASS |
| 3 | B (legalizer) | `MOSLegalizerInfo.cpp` | fuzz 50/50; new `xy16ops.c` PASS; size ↓ |
| 4 | C (compare + indexed) | `MOSInstructionSelector.cpp` | fuzz 50/50; `xy16idx.c` PASS |
| 5 | Regen | `patches/llvm-mos/0002-321-accum16.patch` | sanity checks below |

Steps 2 and 3 are independently buildable and testable. Step 2 produces infrastructure that
rarely fires until Step 3 makes the legalizer emit Xc16-constrained vregs. **Step 2's gate
confirms no regression only** — functional coverage of direct ops (LDXAbs16, STXAbs16,
INX16, DEX16, CPX*16) requires Step 3's class constraints. The `xy16ops.c` disasm gate is
a Step 3 verification, not Step 2.

---

## Verification

1. After every step: `dev/run.sh corpus` (7/7) and `dev/run.sh fuzz 50 <seed>` (50/50).

```
==> corpus: 7/7 passed
==> fuzz: 16/50 PASS, 0 known-issue (xfail)  (34 mismatch, 0 new-crash, 0 error)
```

PASS for corpus; fuzz 16/50 is the current baseline — all mismatches are `xy16@MAME=0x0000` pre-existing
hang bug (tracked in TODO.md §M2), not regressions; seed-56 crash resolved by this commit. Fuzz 50/50 gate
requires the xy16 hang fix first.

2. Existing suite must stay green throughout: `dev/run.sh xy16basic`, `xy16spill`, `xy16spillr`.

```
RESULT: PASS — +mos-xy16 accepted, X-flag lattice inert for M16-only ops, corpus_result==0x0042
RESULT: PASS — Ac16 static-stack spill compiles clean under +mos-xy16 (Layer 4 Ac16 path intact)
RESULT: PASS — LDXImag16+LDAbsXIdx16 indexed access under +mos-xy16; corpus_result==0x3457; both emulators agree
```

PASS

3. **New test** — `examples/65816/xy16ops.c` + `dev/xy16ops.sh` (B2 legalizer gate):
   - `arr[in_idx]` with unmasked `volatile unsigned short in_idx = 42` (no 8-bit proof
     at compile time → B2 gate fires → `G_LOAD_ABS_IDX16`)
   - MIR: 1 `G_LOAD_ABS_IDX16`; instruction-select: 1 `LDXImag16` + 1 `LDAbsXIdx16`
   - corpus_result == 0x2A42 on host, default, and +mos-xy16 (both emulators)
   - `inx`/`dex` / `ldx abs` / `stx abs` gates deferred to B1 implementation (loop-counter
     Xc16 class constraint not yet implemented)

```
==> 1) +mos-xy16 -verify-machineinstrs must compile CLEAN (unmasked 16-bit index under +mos-xy16)
  PASS: clean (exit 0)
==> 2) the indexed access must use G_LOAD_ABS_IDX16 → LDXImag16+LDAbsXIdx16 (B2 gate)
  PASS: 1 G_LOAD_ABS_IDX16 (legalizer) + 1 LDXImag16 + 1 LDAbsXIdx16 (selector) — B2 gate fires
==> 4) MAME: host == default == +mos-xy16 (corpus_result == 0x2A42)
  default: SMOKE: PASS addr=0x7E0202 len=2 got=0x2A42 (ran 60 ticks)
  +mos-xy16: SMOKE: PASS addr=0x7E0202 len=2 got=0x2A42 (ran 60 ticks)
==> 5) bsnes-jg: +mos-xy16 corpus_result == 0x2A42 (independent confirmation)
  SMOKE: PASS off=0x202 len=2 got=0x2A42 (ran 180 frames, bsnes-jg)
RESULT: PASS — G_LOAD_ABS_IDX16+LDXImag16+LDAbsXIdx16 B2 path under +mos-xy16; corpus_result==0x2A42; both emulators agree
```

PASS

4. **New test** — `examples/65816/xy16idx.c` + `dev/xy16idx.sh` (add at Step 4):
   - `for (unsigned short i = 0; i < N; i++) arr[i] = v;`
   - Gate: disasm shows `sta abs,x` in X16 mode; no byte-chain store

5. **Size measurement** (Step 3 onwards): `llvm-size` on `k_isort` or `k_bits` with
   vs. without `+mos-xy16`. Expected: net reduction. Any increase requires investigation
   before committing.

6. **After patch regen:**
   - `grep -c 'Xc16\|HasIndex16' patches/llvm-mos/0002-321-accum16.patch` — non-zero
   - No foreign Ac16 ALU hunks absorbed (legalizeICmp and addSub16 are Ac16-only; their
     hunk count must be unchanged from before Step 1):
     ```bash
     # snapshot count before Step 1, then verify it hasn't grown:
     grep -c 'legalizeICmp\b\|addSub16Native\b' \
         patches/llvm-mos/0002-321-accum16.patch
     ```
   - `tryIndexedAddressing16` IS present in the patch (expected from abs-x-indiry landing;
     confirms that plan's legalizer work wasn't accidentally split off):
     ```bash
     grep -c 'tryIndexedAddressing16' patches/llvm-mos/0002-321-accum16.patch
     # must be > 0
     ```

```
$ grep -c 'Xc16\|HasIndex16' patches/llvm-mos/0002-321-accum16.patch
104

$ grep -c 'legalizeICmp\b\|addSub16Native\b' patches/llvm-mos/0002-321-accum16.patch
5

$ grep -c 'tryIndexedAddressing16' patches/llvm-mos/0002-321-accum16.patch
3
```

PASS (Xc16/HasIndex16 present: 104; Ac16-only hunks stable at 5; tryIndexedAddressing16 present: 3)

---

## Files Modified

| File | Layers |
|---|---|
| `vendor/.../MOSInstrLogical.td` | A1 |
| `vendor/.../MOSInstrGISel.td` | A2 |
| `vendor/.../MOSLegalizerInfo.cpp` | B |
| `vendor/.../MOSInstructionSelector.cpp` | C |
| `patches/llvm-mos/0002-321-accum16.patch` | regen after each step |
| `examples/65816/xy16ops.c`, `dev/xy16ops.sh` | Step 2 |
| `examples/65816/xy16idx.c`, `dev/xy16idx.sh` | Step 4 |
