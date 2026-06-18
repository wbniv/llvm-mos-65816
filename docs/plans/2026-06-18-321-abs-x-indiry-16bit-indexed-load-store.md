# #321 native s16 — 16-bit `abs,x` and `(zp),y` indexed load/store

**Date:** 2026-06-18 · **Status:** DONE 2026-06-18

Item (4) remainder in the agreed optimisation order.  The indirect `(zp)` form
([2026-06-15 plan](2026-06-15-321-native-16bit-indirect-load-store.md)) is done;
this increment adds the two indexed variants that were explicitly deferred there.

---

## What this fixes

After the indirect-load landing, three 16-bit pointer forms remain on the
byte-pair path:

| Access pattern | 8-bit byte-pair (current) | Native M=0 target |
|---|---|---|
| `arr[i]` where `i` byte-offset fits in X | `lda arr,x; sta lo; lda arr+1,x; sta hi` | `rep; lda arr,x; sep` |
| `*p` with an 8-bit Y offset | `lda (p),y; sta lo; iny; lda (p),y; sta hi; dey` | `rep; lda (p),y; sep` |

The deferred note from the indirect plan:
> **Indexed 16-bit load/store**: `abs,x` (array-sum loops:
> `ldy a,x; lda a+1,x` → `rep; lda a,x; sep`) and `(zp),y`.

With 8-bit index registers (no `+mos-xy16`), `abs,x` covers byte-offset-indexed
access to arrays/buffers up to 256 bytes; `(zp),y` covers struct-field and
small-stride access via a runtime pointer in ZP.

---

## Current codegen (the gap)

`legalizeLoadStore16` currently routes s16 G_LOAD/G_STORE to:
1. `G_LOAD16_ABS` / `G_STORE16_ABS` — when the address is absolute (global/constant)
2. `G_LOAD16_INDIR` / `G_STORE16_INDIR` — all other 16-bit pointers (indirect `(zp)`)

The "else" branch catches **everything** non-absolute, including indexed patterns:
- `G_PTR_ADD(global_arr, var_8bit_idx)` → falls to `G_LOAD16_INDIR` → materialises
  the whole `PTR_ADD` result into an Imag16 ZP pair → `lda (zp)` (misses `abs,x`)
- `G_PTR_ADD(zp_ptr, var_8bit_idx)` → same → materialises `ptr + Y` into a new
  Imag16 pair → `lda (zp)` (misses `(zp),y`, wastes an Imag16 materialisation)

---

## Design

### Step 1 — GISel generic pseudos (`MOSInstrGISel.td`)

Four new `G_*16_*_IDX` pseudos mirroring the 8-bit `G_LOAD_ABS_IDX`,
`G_STORE_ABS_IDX`, `G_LOAD_INDIR_IDX`, `G_STORE_INDIR_IDX`.  Add them next to
the existing `G_LOAD16_INDIR` / `G_STORE16_INDIR` block:

```td
// 16-bit abs,x load/store in M=0 mode — mirrors G_LOAD_ABS_IDX / G_STORE_ABS_IDX.
def G_LOAD16_ABS_IDX : MOSGenericInstruction {
  let Predicates = [HasAccum16];
  let OutOperandList = (outs type0:$dst);
  let InOperandList = (ins unknown:$base, type1:$index);
  let mayLoad = true;
}
def G_STORE16_ABS_IDX : MOSGenericInstruction {
  let Predicates = [HasAccum16];
  let OutOperandList = (outs);
  let InOperandList = (ins type0:$src, unknown:$base, type1:$index);
  let mayStore = true;
}

// 16-bit (zp),y load/store in M=0 mode — mirrors G_LOAD_INDIR_IDX / G_STORE_INDIR_IDX.
def G_LOAD16_INDIR_IDX : MOSGenericInstruction {
  let Predicates = [HasAccum16];
  let OutOperandList = (outs type0:$dst);
  let InOperandList = (ins ptype1:$base, type1:$index);
  let mayLoad = true;
}
def G_STORE16_INDIR_IDX : MOSGenericInstruction {
  let Predicates = [HasAccum16];
  let OutOperandList = (outs);
  let InOperandList = (ins type0:$src, ptype1:$base, type1:$index);
  let mayStore = true;
}
```

### Step 2 — Logical MC-pseudo forms (`MOSInstrLogical.td`)

Four new `MLow=1` / `Ac16` forms in the "#321 Increment 1b" block, after
`STAbs16` / before the Imag16 block.  They mirror the 8-bit `LDAAbsIdx`,
`STAbsIdx`, `LDIndirIdx`, `STIndirIdx` but with `Ac16` instead of `Ac` and
`MLow=1`:

```td
// LDA abs,x (16-bit) — load 16-bit from absolute_base + X (M=0).
def LDAbsIdx16 : MOSLoad, PseudoInstExpansion<(LDA_AbsoluteX addr16:$addr)> {
  let Predicates = [HasAccum16];
  let MLow = 1;
  dag OutOperandList = (outs Ac16:$dst);
  dag InOperandList = (ins addr16:$addr, Xc:$idx);
}

// STA abs,x (16-bit) — store 16-bit to absolute_base + X (M=0).
def STAbsIdx16 : MOSStore, PseudoInstExpansion<(STA_AbsoluteX addr16:$addr)> {
  let Predicates = [HasAccum16];
  let MLow = 1;
  dag InOperandList = (ins Ac16:$src, addr16:$addr, Xc:$idx);
}

// LDA (zp),y (16-bit) — load 16-bit via ZP pointer + Y offset (M=0).
// Mirrors 8-bit LDIndirIdx; PseudoInstExpansion maps $addr -> LDA_IndirectIndexed's
// $addr slot; Yc:$offset is kept as an explicit operand constraint (same pattern).
def LDIndirIdx16 : MOSLoad, PseudoInstExpansion<(LDA_IndirectIndexed addr8:$addr)> {
  let Predicates = [HasAccum16];
  let MLow = 1;
  dag OutOperandList = (outs Ac16:$dst);
  dag InOperandList = (ins Imag16:$addr, Yc:$offset);
}

// STA (zp),y (16-bit) — store 16-bit via ZP pointer + Y offset (M=0).
def STIndirIdx16 : MOSStore, PseudoInstExpansion<(STA_IndirectIndexed addr8:$addr)> {
  let Predicates = [HasAccum16];
  let MLow = 1;
  dag InOperandList = (ins Ac16:$src, Imag16:$addr, Yc:$offset);
}
```

**Design note** on `PseudoInstExpansion`:
- `LDAbs16` (already in tree) uses `PseudoInstExpansion<(LDA_Absolute addr16:$src)>` and
  `(ins addr16:$src)` — 1-to-1 mapping, works fine.
- `LDIndirIdx` (8-bit, already in tree) uses `PseudoInstExpansion<(LDA_IndirectIndexed addr8:$addr)>`
  with `(ins Imag16:$addr, Yc:$offset)` — the `$addr` maps positionally; `Yc:$offset` is an
  extra constraint operand not referenced in the expansion (LLVM preserves it as an extra use
  for RA).  We follow the same established pattern.
- `LDA_AbsoluteX` has `InOperandList = (ins addr16:$param)` (X implicit in the addressing
  mode string `"$param , x"`), so one explicit operand; `Xc:$idx` is the extra constraint.

### Step 3 — Legalizer (`MOSLegalizerInfo.h` + `.cpp`)

#### 3a. Declare the helper in `MOSLegalizerInfo.h`

```cpp
bool tryIndexedAddressing16(LegalizerHelper &Helper,
                             MachineRegisterInfo &MRI,
                             GLoadStore &MI) const;
```

#### 3b. Implement `tryIndexedAddressing16` in `MOSLegalizerInfo.cpp`

This combines the `tryAbsoluteIndexedAddressing` (abs,x detection) and
`selectIndirectAddressing` (constant or variable Y-offset detection) patterns,
but emits the 16-bit pseudos instead.

```
Algorithm:
  CurAddr = Ptr; ConstOffset = 0; VarIndex = 0.
  Loop:
    ConstBase (G_CONSTANT)?  → need VarIndex; emit G_LOAD16_ABS_IDX(imm, VarIndex); return.
    G_GLOBAL_VALUE?          → need VarIndex; emit G_LOAD16_ABS_IDX(global+ConstOffset, VarIndex); return.
    G_FRAME_INDEX (static)?  → need VarIndex; emit G_LOAD16_ABS_IDX(fi+ConstOffset, VarIndex); return.
    G_PTR_ADD(base, offset)?
        offset is constant   → ConstOffset += const; CurAddr = base; continue.
        offset is G_ZEXT(src) with src ≤ 8 bits, VarIndex==0 → VarIndex=src; CurAddr=base; continue.
        offset has known ≤8 active bits, VarIndex==0 → VarIndex=trunc8(offset); CurAddr=base; continue.
        else → return false.
    Non-absolute pointer (runtime/ZP):
        VarIndex set, ConstOffset==0 → emit G_LOAD16_INDIR_IDX(CurAddr, VarIndex).
        ConstOffset in [1,255], VarIndex==0 → emit G_LOAD16_INDIR_IDX(CurAddr, const8(ConstOffset)).
        else → return false.
```

Both `G_LOAD16_ABS_IDX` and `G_LOAD16_INDIR_IDX` carry a `MachineMemOperand`
(`cloneMemRefs` on the emitted instruction).  Erase the original `MI` on success.

#### 3c. Call it from `legalizeLoadStore16`

Insert BETWEEN the existing abs check and the `G_LOAD16_INDIR` fallback:

```cpp
// existing:
if (auto AbsOp = matchAbsoluteAddressing(MRI, Ptr)) {
    if (!AllUsesUnmerge) { ... emit G_LOAD16_ABS ...; return true; }
    // else fall through to narrowScalar
} else if (tryIndexedAddressing16(Helper, MRI, MI)) {   // ← NEW
    return true;
} else if (STI.has65C02()) {
    // existing G_LOAD16_INDIR / G_STORE16_INDIR emission
}
```

**AllUsesUnmerge policy**: not applied to the indexed forms (consistent with the
existing `G_LOAD16_INDIR` fallback; the regressing "allUsesUnmerge" shape is
specifically the `G_LOAD16_ABS`-fed equality-compare, which uses the absolute
path).

### Step 4 — Selector (`MOSInstructionSelector.cpp`)

#### 4a. Two new helper methods (beside `selectMem16Abs` / `selectMem16Indir`)

```
// G_LOAD16_ABS_IDX  (dst, base_op, idx_reg) → LDAbsIdx16(A16, base, idx) + STAImag16(dst, A16)
// G_STORE16_ABS_IDX (src, base_op, idx_reg) → LDAImag16(A16, src) + STAbsIdx16(A16, base, idx)
bool selectMem16AbsIdx(MachineInstr &MI);

// G_LOAD16_INDIR_IDX  (dst, base_ptr, idx_reg) → LDIndirIdx16(A16, base, idx) + STAImag16(dst, A16)
// G_STORE16_INDIR_IDX (src, base_ptr, idx_reg) → LDAImag16(A16, src) + STIndirIdx16(A16, base, idx)
bool selectMem16IndirIdx(MachineInstr &MI);
```

Operand layout (same pattern as `selectMem16Abs`):
- `G_LOAD16_ABS_IDX / G_LOAD16_INDIR_IDX`: op[0] = s16 dst, op[1] = base, op[2] = 8-bit idx
- `G_STORE16_ABS_IDX / G_STORE16_INDIR_IDX`: op[0] = s16 src, op[1] = base, op[2] = 8-bit idx

For loads:
```
A16 = new Ac16 vreg
Ld  = LDAbsIdx16(A16, base_op, idx_reg)   or LDIndirIdx16(A16, base_ptr, idx_reg)
Ld.cloneMemRefs(MI)
STAImag16(dst, A16)
```
For stores (re-uses `loadStoreValueIntoA16`):
```
A16 = loadStoreValueIntoA16(MI, src_vreg, New, FoldedLoad)
St  = STAbsIdx16(A16, base_op, idx_reg)   or STIndirIdx16(A16, base_ptr, idx_reg)
St.cloneMemRefs(MI)
```
Constrain, erase, return true.

#### 4b. Wire into `select()`

```cpp
case MOS::G_LOAD16_ABS_IDX:
case MOS::G_STORE16_ABS_IDX:
    return selectMem16AbsIdx(MI);
case MOS::G_LOAD16_INDIR_IDX:
case MOS::G_STORE16_INDIR_IDX:
    return selectMem16IndirIdx(MI);
```

Add just after the existing `G_LOAD16_ABS` / `G_STORE16_ABS` and
`G_LOAD16_INDIR` / `G_STORE16_INDIR` cases.

---

## Tests

### `examples/65816/a16absidx.c` — `lda abs,x` / `sta abs,x`

```c
// Native 16-bit abs,x load and store.
// `g_bytes` is a byte buffer; reading/writing 2 bytes at a time as unsigned short.
// The byte offset `off` is unsigned char (8-bit) → fits in the X register.
volatile unsigned char g_bytes[8] = {
  0x34, 0x12,   /* LE short 0x1234 at offset 0 */
  0x78, 0x56,   /* LE short 0x5678 at offset 2 */
  0xBC, 0x9A,   /* LE short 0x9ABC at offset 4 */
  0xF0, 0xDE,   /* LE short 0xDEF0 at offset 6 */
};
volatile unsigned short corpus_result;

int main(void) {
  unsigned char off = 4;
  /* Read 16-bit value at byte offset 4 → 0x9ABC */
  unsigned short val = *(volatile unsigned short *)(g_bytes + off);
  corpus_result = val;   /* expect 0x9ABC */
  for (;;) {}
}
```

`dev/a16absidx.sh` gates:
1. `corpus_result == 0x9ABC` on host (Python), MAME, bsnes-jg, both default and `+mos-a16`
2. Disasm gate: `rep #$20` (C2 20) immediately followed by `lda $XXXX,x` (opcode BD) — the
   native 16-bit abs,x form is present and no `lda $XXXX` / `lda $XXXX+1,x` byte-pair

**Why this pattern fires**: `off` is `unsigned char`; the pointer is `G_PTR_ADD(g_bytes, G_ZEXT(off))`
where `G_ZEXT(off)` has an 8-bit source — `tryIndexedAddressing16` detects the ZEXT and uses `off`
as the X index.  `g_bytes` is a global → abs base → `G_LOAD16_ABS_IDX` → `LDAbsIdx16`.

### `examples/65816/a16indiry.c` — `lda (zp),y` / `sta (zp),y`

```c
// Native 16-bit (zp),y load via a runtime pointer + 8-bit Y offset.
// A volatile pointer-to-volatile forces the value to be loaded from memory
// each time; the pointer itself is in a ZP Imag16 pair at runtime.
typedef struct { unsigned short a; unsigned short b; } Pair;
volatile Pair g_pair = {0x1234, 0x5678};
volatile Pair *volatile g_pptr = &g_pair;
volatile unsigned short corpus_result;

int main(void) {
  unsigned char y_off = 2;   /* byte offset to member .b */
  /* g_pptr is a runtime 16-bit pointer (in Imag16).
     g_pptr->b is at g_pptr+2.  Because y_off is unsigned char,
     the offset is G_ZEXT(y_off) → tryIndexedAddressing16 emits G_LOAD16_INDIR_IDX. */
  corpus_result = *(volatile unsigned short *)
                    ((volatile unsigned char *)g_pptr + y_off);  /* expect 0x5678 */
  for (;;) {}
}
```

`dev/a16indiry.sh` gates:
1. `corpus_result == 0x5678` on host, MAME, bsnes-jg, both default and `+mos-a16`
2. Disasm gate: `lda ($XX),y` (opcode B1) under `rep #$20 / sep #$20` — the native
   indirect-indexed 16-bit form is present and no `iny` / two-byte-load pair

**Why this pattern fires**: `g_pptr` is a volatile pointer → loaded into an Imag16 pair at runtime.
`y_off` is `unsigned char` → the address is `G_PTR_ADD(g_pptr_reg, G_ZEXT(y_off))` → the ZEXT
has an 8-bit source → `tryIndexedAddressing16` sets `VarIndex = y_off` and hits the non-absolute
base arm → `G_LOAD16_INDIR_IDX(g_pptr_reg, y_off)` → `LDIndirIdx16`.

---

## Byte savings (expected)

For `lda abs,x` in 16-bit mode vs byte-pair:
- Byte-pair: `lda abs,x; sta lo; lda abs+1,x; sta hi` ≈ 10+ bytes
- Native:    `rep #$20; lda abs,x; sep #$20` = 7 bytes (in ambient M=0: 3 bytes)
- **~3–7 bytes per indexed 16-bit load in byte-granularity array/buffer access**

For `lda (zp),y` vs materialise-then-indirect:
- Materialise: load ptr lo/hi to new Imag16 (~4 B) + `rep; lda (zp); sep` = 10–12 B
- Native: `ldy #N; rep; lda (zp),y; sep` = 7 B (in ambient M=0: 4 B)
- **~3–5 bytes per indexed field access via runtime pointer**

---

## Verification

1. Build clean: `dev/run.sh toolchain`; confirm `clang-23` mtime advanced.

```
==> done in 0m 30s: clang version 23.0.0git (...)
```

PASS — mtime advanced; 30 s incremental build.

2. `-verify-machineinstrs` clean on `a16absidx.c` and `a16indiry.c`.

```
(both exit 0 with -mllvm -verify-machineinstrs embedded in dev/a16absidx.sh / a16indiry.sh)
```

PASS

3. `dev/run.sh a16absidx` → opcode BF (abs_long,x) present under rep/sep; `corpus_result 0x9ABC`
   on MAME + bsnes-jg. (SNES globals use 24-bit addressing so `BD` → `BF`; gate updated to `b[df]`.)

```
  PASS: 1 rep #$20 bracket(s) — native 16-bit indexed access
  PASS: 1 lda abs[_long],x (16-bit indexed load, opcode BD or BF)
MAME:  SMOKE: PASS addr=0x7E0209 len=2 got=0x9ABC (ran 60 ticks)
jg:    SMOKE: PASS off=0x209 len=2 got=0x9ABC (ran 180 frames, bsnes-jg)
RESULT: PASS
```

PASS

4. `dev/run.sh a16indiry` → opcode B1 present under rep/sep; `corpus_result 0x5678`
   on MAME + bsnes-jg.

```
  PASS: 1 rep #$20 bracket(s) — native 16-bit indirect-indexed access
  PASS: 1 lda (zp),y (16-bit indirect-indexed load, opcode B1)
  PASS: no iny/dey (no 8-bit byte-pair sequence)
MAME:  SMOKE: PASS addr=0x7E0207 len=2 got=0x5678 (ran 60 ticks)
jg:    SMOKE: PASS off=0x207 len=2 got=0x5678 (ran 180 frames, bsnes-jg)
RESULT: PASS
```

PASS

5. Non-breaking: corpus 7/7 + all existing a16\* tests green; `dev/run.sh fuzz 50 1` →
   50/50, 0 mismatch/crash; `-verify-machineinstrs` clean over suite + fuzz set.

```
corpus: 7/7 passed
a16* suite: 55/56 PASS (a16spillr pre-existing FAIL, not a regression — verified by
            running the same test on unmodified main before changes)
fuzz 50/50 PASS, 0 known-issue (xfail)  (0 mismatch, 0 new-crash, 0 error)
```

PASS

6. `dev/regen-patch.sh` → `0002` round-trips (only `MOSLegalizerInfo`, `MOSInstructionSelector`,
   `MOSInstrGISel.td`, `MOSInstrLogical.td` changed; no foreign hunks).

```
wrote patches/llvm-mos/0002-321-accum16.patch (2967 lines, 21 files)
RESULT: PASS — 0002 round-trips (reapplied MOS dir == live vendor)
```

PASS

Abort condition: if `tryIndexedAddressing16` causes a verifier failure or test mismatch not
resolved within 3 debugging iterations, revert the legalizer change and record the failure
mode — must not ship a load/store miscompile.

---

## Land

- Regenerate `patches/llvm-mos/0002-321-accum16.patch`
- Update `TODO.md` (mark "(4) indexed/array access" fully done; move to Done)
- Commit on `main` with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

---

## Critical files

- `vendor/.../MOSInstrGISel.td` — 4 new `G_*16_*_IDX` pseudos (near `G_LOAD16_INDIR`)
- `vendor/.../MOSInstrLogical.td` — `LDAbsIdx16`, `STAbsIdx16`, `LDIndirIdx16`, `STIndirIdx16`
  (in the #321 Increment 1b block, after `STAbs16`)
- `vendor/.../MOSLegalizerInfo.h` — `tryIndexedAddressing16` declaration
- `vendor/.../MOSLegalizerInfo.cpp` — `tryIndexedAddressing16` implementation; call in
  `legalizeLoadStore16` between the abs check and the `G_LOAD16_INDIR` fallback
- `vendor/.../MOSInstructionSelector.cpp` — `selectMem16AbsIdx`, `selectMem16IndirIdx`;
  two new cases in `select()`
- `examples/65816/a16absidx.c`, `dev/a16absidx.sh`
- `examples/65816/a16indiry.c`, `dev/a16indiry.sh`
- `dev/run.sh` (wire in both new tests)
- `patches/llvm-mos/0002-321-accum16.patch`
- `TODO.md`
