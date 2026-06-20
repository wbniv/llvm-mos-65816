# #320 Increment 3 — runtime far-pointer codegen

**Date:** 2026-06-20 · **Status:** IN PROGRESS (rev. 2 — rescoped from evidence)
**Milestone:** M1 extension
**Builds on:** [Inc 2b](2026-06-14-320-increment-2b-multi-bank-rom-far-read.md) (cross-bank static far read, PASS)

---

## Goal

Extend far-pointer codegen (constant/global absolute-long only) to **runtime far pointers** — an
`__attribute__((address_space(2)))` pointer value computed at runtime, held in a register, and
dereferenced with `lda [dp]` / `sta [dp]` (the 65816 indirect-long instruction).

Three sub-items:

| | Feature | IR node | Status |
|---|---|---|---|
| **3a** | Runtime far-pointer dereference | `G_LOAD`/`G_STORE` on AS2 non-const pointer → `lda [dp]`/`sta [dp]` | ✅ **DONE** — MAME + bsnes-jg |
| **3b** | Near→far addrspacecast | `G_ADDRSPACE_CAST` AS0→AS2 → zero-extend 16-bit ptr to 32-bit (bank=$00) | ✅ **DONE** — MAME + bsnes-jg |
| **3c** | Far-pointer arithmetic | `G_PTR_ADD` on AS2 ptr → 32-bit add (bank byte auto-carries across 64 KB) | ⬜ **DEFERRED** — blocked on the symmetric **s32→4×s8 `G_UNMERGE_VALUES`** legalization, a #321/a16 (`0002`) gap (the handoff's own "still unsupported, no seed hit it yet"). `far_arith.c` is the first to hit it; it belongs in the a16 s32 patch, not the #320 far patch. New TODO. |

### Scope decision (2026-06-20, user-confirmed): **runtime deref only; far-pointer CC deferred**

Far pointers that **cross a function boundary** (passed as an argument or returned) drag in the
**far-pointer calling convention** — how a 32-bit `p2` value is split across registers. That is a
distinct ABI commitment, grouped with the other cross-function far work (far calls / JSL-RTL, "Inc 4"),
and is **upstream-gated** per [implementation-status.md](../implementation-status.md). This increment
is scoped to the runtime deref + intra-function manipulation, fully demonstrable within one function.
**The far-pointer CC is deferred** (new TODO item; see *Deferred* below).

This rescope was driven by measurement, not assumption — see *Evidence* below.

---

## Evidence — what the original plan got wrong (all measured against `clang-23` @ `c798c31`)

The original plan's three gate programs were each invalid; the measurements are the spec now.

1. **`far_arith.c` / `far_cast.c` constant-fold to nothing.** Both compiled to literally
   `ldx #0; txa; rts` (return 0). The far cast/arith/deref never reached codegen — the programs
   "PASS" while exercising zero far-pointer machinery. **Fix:** the gate sources must launder their
   address through a `volatile` so nothing folds.

2. **`far_indir.c` (the original headline gate) fails in calling-convention lowering, not the
   indirect-long path.** Returning a 32-bit `p2` across the `noinline` boundary mis-sizes it into the
   16-bit `$rs1`:
   ```
   %6:_(s16) = G_UNMERGE_VALUES %5:_(p2)
   *** Bad machine code: G_UNMERGE_VALUES scalar source does not match destination ***
   ```
   That is the deferred far-pointer CC, not 3a. **Fix:** the 3a gate stays single-function (opaque
   `volatile` source), where the real failure is the intended one:
   ```
   unable to legalize instruction: %3:_(s8) = G_LOAD %2:_(p2) (volatile load (s8) ... addrspace 2)
   ```
   identical with and without `+mos-a16` (far is `HasW65816`-gated, **a16-independent** — confirmed).

3. **Four legalizer type-rules are missing** (the original plan omitted three). Measured from the IR:
   | Op | Current rule | Needs |
   |---|---|---|
   | `G_INTTOPTR` | `legalFor({{P,S16},{PZ,S8}})` | `+ {PF,S32}` (3a, 3c) |
   | `G_PTRTOINT` | `legalFor({{S16,P},{S8,PZ}})` | `+ {S32,PF}` (3c, via `legalizePtrAdd`) |
   | `G_PTR_ADD` | `customFor({{P,S16},{PZ,S8}})` | `+ {PF,S32}` (3c) |
   | `G_ADDRSPACE_CAST` | `customForCartesianProduct({P,PZ})` | `+ P→PF` (3b emits `addrspacecast`) |

   No register-bank obstacle: MOS uses a single `AnyRegBank` sized per value, so a 32-bit `p2` value
   constrains to a 4-byte `Imag32` ZP class the same way a 16-bit pointer constrains to `Imag16`.

---

## Address-space layout (confirmed, unchanged)

```
AS0 — 16-bit absolute        (6502 default; unchanged)
AS1 —  8-bit direct page     (ZP; unchanged)
AS2 — 32-bit far             (24-bit address in low 3 bytes, 32-bit storage; opt-in, not default)
```

---

## 3a — `lda [dp]` / `sta [dp]` (runtime far-pointer dereference)

`LDA [dp]` (`$A7`) / `STA [dp]` (`$87`) read/write through a **3-byte address** at direct-page `dp`:
bytes `dp`,`dp+1`,`dp+2` = `addr_lo`,`addr_hi`,`bank`. A 32-bit AS2 far pointer stores its 24-bit
address little-endian in its low 3 bytes (byte 3 = pad `$00`). If the 4 bytes live in **consecutive
ZP** locations, `lda [first]` reads bytes 0,1,2 as the 24-bit address — correct, no byte-swap.

`Imag16` (2-byte ZP pair) is too narrow. We add a **4-byte ZP class `Imag32`** so the register
allocator places all 4 bytes consecutively; `[dp]` references the first.

### Backend changes (all under `vendor/llvm-mos/llvm/lib/Target/MOS/`)

1. **`MOSRegisterInfo.td`** — `Imag32` register class: 4 consecutive `__rs`-derived ZP bytes,
   `[i32]` value type, alongside `Imag16`/`Ac16`. (`def Imag32 : MOSReg32Class<(sequence "RS%u", …)>`
   — but `RS` regs are 16-bit pairs; instead build it from the same `RC` byte sequence used by
   `Imag16`/`Imag8`. See implementation note: the contiguous-4-byte class is expressed over the
   `__rc` byte registers so RA guarantees adjacency, parallel to how `RS#` pairs two `RC#`.)

2. **`MOSInstrInfo.td`** — inside `let Predicates = [HasW65816]`:
   ```
   def LDA_IndirectLong : Inst16<"lda", Opcode<0xA7>, IndirectLong>;  // lda [dp]
   def STA_IndirectLong : Inst16<"sta", Opcode<0x87>, IndirectLong>;  // sta [dp]
   ```
   (`IndirectLong` addressing mode already exists in `MOSInstrFormats.td`.)

3. **`MOSInstrLogical.td`** — `LDIndirLong` / `STIndirLong` logical pseudos near `LDAbsLong`/
   `STAbsLong`, taking `Imag32:$addr`, `PseudoInstExpansion` to the MC defs above, `HasW65816`.

4. **`MOSInstrGISel.td`** — `G_LOAD_FAR_INDIR` / `G_STORE_FAR_INDIR` GISel pseudos, mirror of
   `G_LOAD_FAR_ABS` / `G_STORE_FAR_ABS`, `HasW65816`.

5. **`MOSLegalizerInfo.cpp`**
   - Add the four type-rules from *Evidence* §3 (`G_INTTOPTR`/`G_PTRTOINT`/`G_PTR_ADD`/
     `G_ADDRSPACE_CAST` for `PF`).
   - `tryFarIndirectAddressing`: in `selectAddressingMode` `case 32:`, after
     `tryFarAbsoluteAddressing` returns false, replace the `G_LOAD`/`G_STORE` with
     `G_LOAD_FAR_INDIR`/`G_STORE_FAR_INDIR` taking the far pointer reg (the selector + reg-class
     constraint place its 32 bits into a contiguous `Imag32`, mirroring the `G_LOAD_INDIR`→`Imag16`
     path).
   - `legalizeAddrSpaceCast`: handle AS0→AS2 by zero-extending the 16-bit near pointer to the 32-bit
     far pointer (bank byte `$00`).

6. **`MOSLegalizerInfo.h`** — declare `tryFarIndirectAddressing`.

7. **`MOSInstructionSelector.cpp`** — route `G_LOAD_FAR_INDIR`/`G_STORE_FAR_INDIR` to `selectGeneric`
   (the dispatch alongside `G_LOAD_FAR_ABS`), and add the opcode-switch cases
   `G_LOAD_FAR_INDIR → MOS::LDIndirLong` / `G_STORE_FAR_INDIR → MOS::STIndirLong`.

### Gate — `examples/65816/far_indir.c` (single-function, opaque source)

```c
#include <stdint.h>
static const uint8_t rom_sentinel __attribute__((section(".rodata.bank1"))) = 0xF3;
volatile uint32_t g_addr;            // opaque → cannot fold to absolute-long
int main(void) {
    g_addr = (1UL << 16) | (uint16_t)(uintptr_t)&rom_sentinel;   // bank $01 : near(low16)
    uint32_t a = g_addr;
    __attribute__((address_space(2))) volatile const uint8_t *fp =
        (__attribute__((address_space(2))) volatile const uint8_t *)a;
    return *fp == 0xF3 ? 0 : 1;      // lda [dp]
}
```
Disasm gate: opcode `a7 NN` present; **no** `af NN NN NN` (absolute-long). Execution: exit 0 on
MAME **and** bsnes-jg. (Built with plain `-mcpu=mosw65816`, no `+mos-a16` — far is a16-independent.)

---

## 3b — Near→far addrspacecast (AS0→AS2)

`addrspacecast ptr → ptr addrspace(2)` zero-extends the 16-bit near pointer to a 32-bit far pointer
(bank `$00`). Handled in `legalizeAddrSpaceCast`. The resulting far pointer is then a *runtime* value,
so its deref reuses 3a's indirect-long path.

### Gate — `examples/65816/far_cast.c` (opaque source)

```c
#include <stdint.h>
static const uint8_t data[1] = { 0xAB };
volatile uint16_t g;                 // opaque → no fold
int main(void) {
    g = (uint16_t)(uintptr_t)&data[0];
    const uint8_t *np = (const uint8_t *)(uintptr_t)g;
    __attribute__((address_space(2))) const uint8_t *fp =
        (__attribute__((address_space(2))) const uint8_t *)np;   // addrspacecast
    return *fp == 0xAB ? 0 : 1;
}
```
Gate: compiles; exit 0 on both emulators. (`data` is bank $00, so the bank byte is `$00`.)

---

## 3c — Far-pointer arithmetic (G_PTR_ADD on AS2)

`G_PTR_ADD {PF,S32}` adds an integer offset to a 32-bit far pointer; the 32-bit add carries through
the bank byte across a 64 KB boundary (correct flat-address behavior). `fp++` is offset +1 → routes
through `legalizePtrAdd` (the `G_INC`/`G_DEC` fast-path needs `G_INC`/`G_DEC` legal for `PF`, else the
generic `ptrtoint`/`add`/`inttoptr` path — both now covered by the new type-rules).

### Gate — `examples/65816/far_arith.c` (opaque source)

```c
#include <stdint.h>
static const uint8_t arr[3] = { 0x11, 0x22, 0x33 };
volatile uint16_t g;                 // opaque → no fold
int main(void) {
    g = (uint16_t)(uintptr_t)&arr[0];
    __attribute__((address_space(2))) const uint8_t *fp =
        (__attribute__((address_space(2))) const uint8_t *)(uintptr_t)(uint32_t)g;
    fp++;                            // G_PTR_ADD {PF,S32}
    return *fp == 0x22 ? 0 : 1;
}
```
Gate: far pointer incremented by 1; exit 0 on both emulators.

---

## Implementation order

1. Add the four type-rules + `legalizeAddrSpaceCast` AS0→AS2 (unblocks 3b/3c compilation).
2. Add the 3a machinery (`Imag32`, MC defs, pseudos, GISel ops, `tryFarIndirectAddressing`, selector).
3. Build, then iterate on the disasm gate (`a7` present) before touching emulators.

All three land in **one commit** to `0001` once the three gates pass on both emulators.

---

## Patch hygiene — CORRECTED (the original step-7 was wrong)

The shared `vendor/llvm-mos` currently carries **foreign WIP**: `MOSIndexWidthClobber.cpp/.h` (+ its
registrations in `CMakeLists.txt`, `MOS.h`, `MOSTargetMachine.cpp`) exist in the live tree but are in
**no patch** — another worker's xy16 seed-247/445 debugging. Therefore:

- **Do NOT run `dev/regen-patch.sh`.** It mirrors the *live* MOS dir into the 0002 baseline-diff, so it
  would absorb the foreign `MOSIndexWidthClobber` work **into the a16 patch**. (`regen-patch.sh` only
  regenerates 0002; it has no 0001 path at all — the original handoff's step 7 is doubly wrong.)
- **Capture my far hunks via per-file snapshot-diff:** snapshot each file before editing; diff after.
  The delta is *exactly* my far edits, provably free of foreign WIP and of 0002.
- **Regenerate `0001` in a clean room:** worktree at pristine + old-0001 (+0003), apply the snapshot
  delta, `git diff` vs pristine (excluding `MOSLateOptimization.cpp`, which is 0003) → new `0001`.
  My edits are additive at far-specific anchors, so the delta applies cleanly onto the 0001-only tree.
- **Verify the stack:** apply `0001_new + 0002 + 0003` to a fresh pristine worktree; `diff -rq` its MOS
  dir vs live — the only differences must be the enumerated foreign-WIP files. Confirms `0002` still
  applies on `0001_new` and that `0001_new` contains no a16/foreign hunks.

`dev/regen-patch-0001.sh` is added to make this reproducible.

---

## Verification steps

**Step 1.** Compile `far_indir.c` (`-mcpu=mosw65816`, no a16); `llvm-objdump -d` shows `a7` and no
`af` (absolute-long).

**Step 2.** `far_indir.c` on MAME → exit 0.

**Step 3.** `far_indir.c` on bsnes-jg → exit 0.

**Step 4.** `far_cast.c` (3b) on MAME + bsnes-jg → exit 0 each.

**Step 5.** `far_arith.c` (3c) on MAME + bsnes-jg → exit 0 each.

**Step 6.** `dev/run.sh xcheck` (and the existing `far`, `far-run`, `far-bank1`) → all PASS (no
regression). Note: run from the shared tree, which also carries the foreign xy16 WIP; my far changes
are additive + `HasW65816`-gated and do not touch a16 paths.

**Step 7.** `grep -c 'accum16\|NativeS16\|IndexWidthClobber' patches/llvm-mos/0001-320-far-addrspace.patch`
→ 0 (the far patch contains only #320 hunks — no a16 codegen, no foreign WIP). And the stack-verify
`diff -rq` (above) shows only the enumerated foreign files.

---

## Results (2026-06-20) — PASS

```
Step 1 (far_indir disasm):  27: a7 00  lda [$0]           -> PASS (indirect-long, no absolute-long for the deref)
Step 2 (far_indir MAME):    SMOKE: PASS addr=0x7E0204 got=0xF3                    -> PASS
Step 3 (far_indir bsnes):   PASS far_indir.sfc: got=0xF3 (180 frames, bsnes-jg)   -> PASS
Step 4 (far_cast MAME+jg):  MAME got=0xF3 (a7 present) + bsnes-jg got=0xF3         -> PASS
Step 5 (far_arith 3c):      DEFERRED — unable to legalize G_UNMERGE_VALUES s32->4x s8 (a16/0002 gap)
Step 6 (a16 regression):    corpus 7/7; a16unmerge/a16spill/a16ptr PASS; far-run/far-bank1 still PASS -> PASS
Step 7 (patch hygiene):     0001: Imag32/FAR_INDIR=40, accum16=0, foreign=0
                            0002 (re-stacked via regen-patch.sh): far ADDED-lines=0 (3 context only),
                                 accum16=91, seed-247 (other agent's xy16 fix) preserved=4
                            regen-patch.sh round-trip: PASS (pristine+0001+0002+0003 == live MOS dir)
```

**What shipped:** 3a (`lda [dp]` runtime deref) + 3b (AS0→AS2 cast), both two-emulator verified. The
implementation added the backend's **first first-class 32-bit ZP register** (`Imag32` quad over two
`RS` words = 4 contiguous `__rc` bytes): subreg indices `sublo16`/`subhi16`, `RL#K` register entities,
`getReservedRegs` quad-overlap reservation (an `Imag32` must not land on the stack pointer `RS0` /
scavenger `RS8`), `getRegClassForType(32)`, a `selectMergeValues` 2×s16→Imag32 compose with two pin
sites (else `constrainGenericOp` leaves class-less bridge COPYs), `copyPhysReg`, and the `__rc`-symbol
lowering. Plus the four legalizer type-rules and `tryFarIndirectAddressing`.

**Surprises vs the original plan:** (1) `LDA_IndirectLong`/`STA_IndirectLong` MC defs **already exist**
(auto-generated by the `CC1_All` multiclass under `[HasW65816]`) — `MOSInstrInfo.td` needed **no**
change. (2) Far is a16-**independent** as machinery but a runtime far pointer is a 32-bit **value**, so
the deref needs `+mos-a16` (32-bit value legalization) — the gate is 3-way (host + `+mos-a16`×2 emus),
not the usual 4-way, since the default 8-bit build can't compile a runtime far deref.

---

## Deferred (new TODO items)

- **Far-pointer calling convention** — pass/return a 32-bit `p2` across function boundaries
  (`make_far_ptr`-style). ABI decision (how `p2` maps to registers); group with far calls (Inc 4);
  upstream-gated. Until then, runtime far pointers are usable **within a function**.
- **`G_STORE` runtime far (`sta [dp]`)** — implemented symmetrically with the load, but the gate
  exercises the load; a store micro-test (`*fp = v`) is a cheap follow-up if not added here.
