# #320 Increment 3 — runtime far-pointer codegen

**Date:** 2026-06-20 · **Status:** PLAN  
**Milestone:** M1 extension  
**Builds on:** [Inc 2b](2026-06-14-320-increment-2b-multi-bank-rom-far-read.md) (cross-bank static far read, PASS)

---

## Goal

Extend the existing far-pointer codegen (constant/global absolute-long only) to support **runtime far
pointers** — a `__attribute__((address_space(2)))` pointer value computed at runtime, stored in a
register, and dereferenced with `lda [dp]` / `sta [dp]` (the 65816 indirect-long instruction).

Covers three sub-items:

| | Feature | IR node |
|---|---|---|
| **3a** | Runtime far-pointer dereference | `G_LOAD`/`G_STORE` on AS2 non-const pointer → `lda [dp]`/`sta [dp]` |
| **3b** | Near→far addrspacecast | `G_ADDRSPACE_CAST` AS0→AS2 → zero-extend 16-bit ptr to 32-bit (bank=$00) |
| **3c** | Far-pointer arithmetic | `G_PTR_ADD` on AS2 ptr → 32-bit add (bank byte auto-carries across 64 KB) |

Not in scope: far calls (JSL/RTL) — planned separately as Inc 4 once this lands.

---

## Address-space layout (confirmed, no upstream gating needed)

```
AS0 — 16-bit absolute        (6502 default; unchanged)
AS1 —  8-bit direct page     (ZP; unchanged)
AS2 — 32-bit far             (24-bit address in low 3 bytes, 32-bit storage; opt-in, not default)
AS3 — packed-24 (deferred)   (LLVM requires power-of-2 pointer sizes; niche; no concrete use case)
AS4 — zero-bank  (deferred)  (AS0 covers bank-$00 data; defer until a need surfaces)
```

The `0 = 32-bit far default` proposal (@asiekierka #320) is not adopted — it would penalize all
normal 16-bit-bank-local code and diverge from both WDC816CC and ORCA-C (which use explicit
`near`/`far`). The design note (drafted, ready to post) explains this choice to upstream.

---

## 3a — `lda [dp]` / `sta [dp]` (runtime far-pointer dereference)

### The instruction

`LDA [dp]` (opcode `$A7`) and `STA [dp]` (opcode `$87`) — 65816 indirect-long — read/write through a
**3-byte address** stored at the direct-page location `dp`: bytes at `dp`, `dp+1`, `dp+2` are
`addr_lo`, `addr_hi`, `bank`. This is the hardware mechanism for reaching any byte in the 65816's
full 24-bit address space via a runtime pointer.

A 32-bit AS2 far pointer stores its 24-bit address little-endian in the low 3 bytes (byte 0 = low
addr, byte 1 = high addr, byte 2 = bank), with byte 3 = padding ($00). If the 4 bytes live in
**consecutive ZP locations** `__rcN .. __rcN+3`, then `lda [__rcN]` reads bytes N, N+1, N+2 as the
24-bit address — exactly correct with no byte-swapping.

### Representation gap

`Imag16` (the existing 2-byte ZP class for 16-bit near pointers) isn't wide enough. We need a
**4-byte ZP class** (`Imag32`) so the register allocator places all 4 bytes consecutively in ZP, and
the `[dp]` instruction can reference the first byte as the start of the 3-byte address.

This mirrors the `Imag8`→`Imag16` pattern exactly: define `Imag32` as 4 consecutive `__rs*` bytes in
`MOSRegisterInfo.td`, alongside the existing `Imag16` entries.

### Files to touch

1. **`MOSRegisterInfo.td`** — add `Imag32` register class (4 consecutive ZP bytes, e.g. `RS1_4 =
   {__rs1, __rs2, __rs3, __rs4}`; use `__rs*` not `__rc*` to leave the 16-bit imaginary range
   intact). Pattern: search for `Imag16`, mirror the structure at double width.

2. **`MOSInstrInfo.td`** — add `LDA_IndirectLong` / `STA_IndirectLong` MC instruction defs under
   `HasW65816`. The `IndirectLong` addressing mode already exists (`MOSInstrFormats.td:411`); these
   are just missing 65816-specific LDA/STA forms:
   ```
   let Predicates = [HasW65816] in {
     def LDA_IndirectLong : Inst16<"lda", Opcode<0xA7>, IndirectLong>;  // lda [dp]
     def STA_IndirectLong : Inst16<"sta", Opcode<0x87>, IndirectLong>;  // sta [dp]
   }
   ```

3. **`MOSInstrLogical.td`** — add logical pseudos that expand to those MC instructions, taking
   `Imag32` as the ZP address:
   ```
   // lda [dp]: far-pointer indirect-long load.
   def LDIndirLong : MOSLoad,
       PseudoInstExpansion<(LDA_IndirectLong addr8:$addr)> {
     let Predicates = [HasW65816];
     dag OutOperandList = (outs Ac:$dst);
     dag InOperandList  = (ins Imag32:$addr);
   }
   // sta [dp]: far-pointer indirect-long store.
   def STIndirLong : MOSStore,
       PseudoInstExpansion<(STA_IndirectLong addr8:$addr)> {
     let Predicates = [HasW65816];
     dag InOperandList = (ins Ac:$src, Imag32:$addr);
   }
   ```

4. **`MOSInstrGISel.td`** — add GISel pseudos `G_LOAD_FAR_INDIR` / `G_STORE_FAR_INDIR`, analogous
   to `G_LOAD_FAR_ABS` / `G_STORE_FAR_ABS` (search `G_LOAD_FAR_ABS` for the template):
   ```
   // G_LOAD_FAR_INDIR — far load via runtime far pointer in ZP.
   // The address operand is an Imag32 ZP register holding the 24-bit address
   // (low, high, bank, pad) at consecutive bytes [dp..dp+3].
   def G_LOAD_FAR_INDIR : MOSGenericInstruction { ... }
   def G_STORE_FAR_INDIR : MOSGenericInstruction { ... }
   ```

5. **`MOSLegalizerInfo.cpp` — `tryFarIndirectAddressing`**: in the `case 32:` block, after
   `tryFarAbsoluteAddressing` returns false (non-constant pointer), fall through to a new
   `tryFarIndirectAddressing` that:
   - Creates an `Imag32` virtual register
   - Inserts a `G_STORE` to write the 32-bit far pointer value into the `Imag32` ZP slots
   - Replaces the `G_LOAD`/`G_STORE` with `G_LOAD_FAR_INDIR`/`G_STORE_FAR_INDIR` taking the `Imag32`

6. **`MOSInstructionSelector.cpp`** — add `G_LOAD_FAR_INDIR → MOS::LDIndirLong` / `G_STORE_FAR_INDIR
   → MOS::STIndirLong` in the load/store opcode switch (alongside the existing `G_LOAD_FAR_ABS` case
   at line 3139).

7. **`MOSLegalizerInfo.h`** — declare `tryFarIndirectAddressing`.

### Verification gate

```c
// examples/65816/far_indir.c
// A far pointer is computed at runtime (not a compile-time constant) and
// dereferenced; the result round-trips through both emulators.
#include <stdint.h>
__attribute__((address_space(2))) volatile uint8_t *make_far_ptr(uint32_t a) {
    return (__attribute__((address_space(2))) volatile uint8_t *)a;
}
int main(void) {
    // Read ROM byte at bank $01 address $8000 via a runtime far pointer.
    uint32_t addr = (1UL << 16) | 0x8000;
    uint8_t v = *make_far_ptr(addr);
    return v == EXPECTED ? 0 : 1;
}
```

Expected disasm: `lda [__rsN]` (opcode `a7 NN`) present in the output (not `lda $018000` — the
absolute-long path).  
Expected execution: MAME + bsnes-jg both return exit 0.

---

## 3b — Near→far addrspacecast (AS0→AS2)

### The IR node

`G_ADDRSPACE_CAST` from AS0 (16-bit pointer) to AS2 (32-bit far pointer) zero-extends the 16-bit
value to 32 bits: bank byte = $00, high addr = upper byte, low addr = lower byte. This is correct
for SNES data in bank $00 (ROM $8000–$FFFF, WRAM mirror $0000–$1FFF).

For other banks (e.g. WRAM at $7E0000), the user ORs in the bank byte manually:
```c
uint32_t wram_far = (0x7EUL << 16) | (uint16_t)near_ptr;
```
No compiler magic is needed for that — it's integer arithmetic.

### Files to touch

1. **`MOSLegalizerInfo.cpp`** — in `legalizeIntrinsic` or the generic legalizer dispatch, handle
   `G_ADDRSPACE_CAST` where source type is `LLT::pointer(0, 16)` and dest type is
   `LLT::pointer(2, 32)`: emit a `G_ZEXT` from 16 to 32 bits. The result is the far pointer with
   bank byte = $00.

   Check whether `G_ADDRSPACE_CAST` between AS0 and AS2 already legalizes as a no-op zext or needs
   an explicit case. If it already works (the 16-bit value zero-extends naturally to 32-bit), no
   change is needed — just add a test.

### Verification gate

```c
// examples/65816/far_cast.c
// Near pointer in bank $00, cast to far pointer and dereferenced.
#include <stdint.h>
static const uint8_t data[] = { 0xAB };
int main(void) {
    const uint8_t *near = data;
    __attribute__((address_space(2))) const uint8_t *far =
        (__attribute__((address_space(2))) const uint8_t *)near;
    return *far == 0xAB ? 0 : 1;
}
```

Expected: near→far cast compiles; `lda [dp]` (or `lda long` if the optimizer constant-folds) in
the disasm; MAME + bsnes-jg both return exit 0.

---

## 3c — Far-pointer arithmetic (G_PTR_ADD on AS2)

### What should happen

`G_PTR_ADD` on a 32-bit AS2 pointer adds an integer offset. The legalizer treats AS2 pointers as
s32 for arithmetic purposes — the 32-bit add carries through the bank byte if the offset crosses
a 64 KB boundary. This is the correct flat-address-space behavior.

### Likely no-op

`G_PTR_ADD` on AS2 may already legalize correctly as a 32-bit integer add (the legalizer's
existing widening path). Verify first — if `int32 + offset` already works, no codegen change is
needed.

If the arithmetic is emitted as 16-bit (the pointer width class mis-matches), add an explicit
`G_PTR_ADD` legalization for pointer type `LLT::pointer(2, 32)` → widen to s32 add.

### Verification gate

```c
// examples/65816/far_arith.c
// A far pointer is incremented and dereferenced; result must equal adjacent byte.
#include <stdint.h>
static const uint8_t arr[] = { 0x11, 0x22, 0x33 };
int main(void) {
    __attribute__((address_space(2))) const uint8_t *fp =
        (__attribute__((address_space(2))) const uint8_t *)arr;
    fp++;
    return *fp == 0x22 ? 0 : 1;
}
```

Expected: far pointer incremented by 1; `lda [dp]` at the right offset; MAME + bsnes-jg exit 0.

---

## Implementation order

1. **Check 3c first** (5 minutes): write the `far_arith.c` test, compile, see if it already works
   or fails loudly. If it fails, add the legalizer case.
2. **Check 3b next** (10 minutes): write the `far_cast.c` test, see if `G_ADDRSPACE_CAST` AS0→AS2
   already zero-extends or needs an explicit case.
3. **Implement 3a** (the real work): the `Imag32` class, `LDA_IndirectLong` / `STA_IndirectLong` MC
   defs, `LDIndirLong`/`STIndirLong` pseudos, `G_LOAD_FAR_INDIR`/`G_STORE_FAR_INDIR` GISel ops,
   `tryFarIndirectAddressing`, selector cases.

Each sub-item is independently verifiable. Land them together in one commit once all three gate
programs pass on both emulators.

---

## Worktree

Run on `throwaway/320-far-runtime` off `main` HEAD. No build needed in the worktree — inherit from
`main`'s `build/llvm-mos-install/bin/` via `CLANG`/`OBJDUMP` env overrides (host-only test
programs only; no Docker needed here).

---

## Verification steps

**Step 1.** After implementing 3a: compile `far_indir.c` with `+mos-a16` (the 65816 target);
confirm `lda [__rs...]` (opcode `$a7`) appears in the disasm.

```
# Command TBD — fill in after worktree setup
```

**Step 2.** Run `far_indir.c` on MAME; confirm exit 0.

**Step 3.** Run `far_indir.c` on bsnes-jg; confirm exit 0.

**Step 4.** Run `far_cast.c` on MAME + bsnes-jg; confirm exit 0.

**Step 5.** Run `far_arith.c` on MAME + bsnes-jg; confirm exit 0.

**Step 6.** `dev/run.sh xcheck` (full differential gate); all existing tests still PASS.

**Step 7.** Regen `0001-320-far-addrspace.patch`; confirm it contains only #320 far-pointer hunks
(no #321 codegen).
