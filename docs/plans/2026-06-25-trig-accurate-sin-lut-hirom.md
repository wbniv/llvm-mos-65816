# Accurate sin LUT for the trig test — a HiROM big-ROM SNES platform (Phase 1c)

**Status:** DONE + VERIFIED 2026-06-25 (worktree `wt/321-trig`). Stage A (HiROM platform) +
Stage C (accurate LUT) both pass; the blocking bug was root-caused to clang and **FIXED** (a one-spot
`CGExpr.cpp` change, in `patches/llvm-mos/0001`, round-trip verified). Builds on Phase 1
([2026-06-25-trig-functions-as-a-c-compiler-differential-test-1.md](2026-06-25-trig-functions-as-a-c-compiler-differential-test-1.md)).

## RESOLUTION (the clang fix)

`clang/lib/CodeGen/CGExpr.cpp` `EmitArraySubscriptExpr`/`EmitIdxAfterBase` promoted the GEP index to
the **default** `IntPtrTy` (AS0's 16-bit ptrdiff) for *every* address space. Fix: promote to the
**base pointer's per-address-space index width** — `getIntPtrType(getLLVMContext(), TargetAS)` where
`TargetAS` is the pointee/element's address space. Generically correct (identical for single-width
targets); for MOS far (AS2) the index stays 32-bit, so indices ≥ 32768 no longer truncate. Landed in
`patches/llvm-mos/0001-320-far-addrspace.patch` (round-trip PASS reapplying `0001..0007`).

**Verified after the fix:** `examples/65816/farindex.c` reads all three banks correctly
(`r0=0x0064`@$C1, `r1=0xB0E9`@$C2, `r2=0xFB06`@$C3); **Stage C** `k_trig32` accurate-LUT differential
`corpus_result == 0x87F0B404` on **MAME + bsnes-jg** (`dev/run.sh k_trig32lut`); accuracy
**cos 6.2e‑3→1.7e‑5 (360×), tan 3.1e‑2→2.0e‑4 (155×)**, sin 8.8e‑6. Regression-clean: `k_hopalong`
(near AS0 subscript) `0x1BBC`, `packed24` (AS3) `0xF3`, far suite (`far_indir/arith/call`) PASS.

**Reproducibility (full SDK build, 2026-06-25):** a clean `dev/run.sh build` with the fixed
toolchain **generates `platforms/snes-hirom`** (`mos-snes-hirom.cfg` + installed `link.ld`) from the
committed source — no manual placement. `dev/run.sh k_trig32lut` then **RESULT: PASS** through the
SDK-built platform, and `corpus` is **7/7** on the freshly fixed-clang-rebuilt ROMs (incl. `arrays`,
a near subscript). Two `dev/k_trig32lut.sh` driver bugs were fixed in passing: a `pipefail`+`grep -q`
SIGPIPE false-negative on the disasm gate, and tolerance of a stale root-owned `.o` from a prior
container run.

## FINDING — far indexed loads drop the offset's high bits (bank-crossing mis-addresses)

The earlier probe only verified disasm *shape*; running it exposed the real bug. A `const FAR`
array spanning HiROM banks, indexed so `index*2` crosses a 64 KiB boundary, reads the WRONG address:

| index | byte offset | want addr | got | expect | verdict |
|---|---|---|---|---|---|
| 100   | 200 (`$C8`)      | `$C100C8` (bank $C1) | `0x0064` | `0x0064` | ✓ correct |
| 50000 | 100000 (`$186A0`) | `$C286A0` (bank $C2) | `0x0000` | `0xB0E9` | ✗ wrong |
| 90000 | 180000 (`$2BF20`) | `$C3BF20` (bank $C3) | `0x5D5C` | `0xFB06` | ✗ wrong |

`r2`'s `0x5D5C` ≈ `lut[24464]` = the index **16-bit-truncated** (`90000 & 0xFFFF = 0x5F90 = 24464`),
and `r1` (`50000 = 0xC350`, int16-negative) underflows the bank to `$C0`. **Indices ≥ 32768 corrupt.**

**ROOT CAUSE — clang frontend (not the backend).** The LLVM IR for `tbl[idx]` already contains the bug:
```
%2 = shl i32 %idx, 16
%3 = ashr exact i32 %2, 15        ; %3 = sext_i16(idx) * 2   ← index truncated to 16 bits
%4 = getelementptr inbounds i8, ptr addrspace(2) @tbl, i32 %3
```
clang's array-subscript CodeGen casts the index to the **default 16-bit `IntPtrTy`** (AS0's ptrdiff)
instead of the far pointer's 32-bit index width — even though `MOSTargetInfo::getPointerWidthV(AS2)==32`
and the datalayout (`p2:32:8`) implies a 32-bit AS2 index. So this is a **clang fix** in
`EmitArraySubscriptExpr` / pointer-arith index scaling (use the address-space-aware index type for
AS2), NOT a backend/legalizer change. The backend's `G_PTR_ADD {PF,S32}` is correct; it's fed a
pre-truncated offset. Minimal repro: `examples/65816/farindex.c` on `snes-hirom`, bsnes-jg `r0` PASS
(bank $C1) / `r1`,`r2` FAIL (banks $C2/$C3). Compiler-changing increment (own `vendor/llvm-mos`
worktree + clang rebuild). The bank-$C1 read working proves the HiROM platform + far-load mechanism +
LUT data are all correct (disasm: `R_MOS_ADDR24_SEGMENT_LO/HI/BANK` + `lda [dp]`).

### What DID land (durable, working)
- `platforms/snes-hirom/link.ld` — HiROM platform; smoke boots `0x42` on **MAME + bsnes-jg**.
- `tools/snes-checksum.py --hirom` — HiROM header (map-mode $21, file $FFB0, size byte).
- Host-measured accuracy win (inline LUT, host oracle): **cos 6.2e‑3→1.7e‑5 (360×), tan 3.1e‑2→2.0e‑4
  (155×)**, sin 8.8e‑6 — confirming the LUT is worth it once the backend bug is fixed.

## Context

Phase 1's `k_trig32` uses libfixmath's **Taylor** `fix16_sin` (≈6e‑3 at the reduced-argument edges)
because I wrongly believed the ~200 KiB accurate LUT couldn't fit the ROM. It can: a SNES cartridge
reaches **4 MiB** (LoROM/HiROM) / **8 MiB** (ExHiROM) — 200 KiB is ~1.6 Mbit, smaller than nearly
every commercial game. The 32 KiB ceiling I cited was *this repo's two small linker scripts* (`snes`
32 KiB, `snes-far` 64 KiB), not the hardware.

Enabling libfixmath's `FIXMATH_SIN_LUT` is worth doing for **two** reasons:
1. **Accuracy:** the LUT is a near-full-resolution direct table → `sin/cos/tan` go from ~6e‑3 to
   ~**1e‑5** (≈1 fix16 LSB). (`atan/asin/acos` stay bound by libfixmath's atan2 polynomial — unchanged.)
2. **Compiler coverage:** a ~200 KiB `const` table in far ROM, indexed by a 17-bit value, exercises
   **large multi-bank `.far_rodata` placement + 24-bit indexed far loads** — squarely this fork's
   far/packed-24 focus, on real table data. This is a strong "test the C compiler" payload.

## What the probe established (core risk retired)

`examples/65816/` spelling: `#define FAR __attribute__((address_space(2)))`; far data =
`const FAR T x __attribute__((section(".far_rodata")))`. A probe (`+mos-a16`, `-verify` clean) of
`far_const_array[int32_index]` showed the backend computes the **full 24-bit address** — index ×2 via
`asl;rol;rol;rol` over 4 bytes, added to the far base through `R_MOS_ADDR24_SEGMENT_LO/HI .far_rodata`,
then a far load **`lda [dp]` (opcode A7)**. So indexing a table past 64 KiB already works; no backend
change is needed. Indexing a far *array* directly (not just a hand-built far pointer) works too — so
the libfixmath access `_fix16_sin_lut[tempAngle]` needs only a qualifier change on the declaration.

## Why HiROM (not LoROM)

A C array is contiguous in CPU-address space. **LoROM** maps only 32 KiB per bank ($xx8000–$xxFFFF),
non-contiguous — a >32 KiB array would run off ROM into RAM/registers at $xx0000. **HiROM** maps the
full 64 KiB of banks $C0–$FF contiguously ($C00000–$FFFFFF, up to 4 MiB), so a 200 KiB `.far_rodata`
table at $C0xxxx is contiguous ROM and the 24-bit far address resolves cleanly. So this needs a new
HiROM platform; `snes-far` (LoROM, one far bank) can't hold it.

## Design

- **New platform `platforms/snes-hirom/`** — a HiROM linker script (ROM banks $C0+, sized e.g. 512 KiB
  = $C00000–$C7FFFF; near code/vectors/header in the $C0 $8000–$FFFF window reachable via the $00
  reset-vector mirror; a large contiguous `.far_rodata` region for the LUT) + the HiROM header
  (map-mode byte **$21** vs LoROM's $20) + reuse of the existing SNES crt0/init chain. The SDK build
  auto-injects it (`dev/build.sh` loops `platforms/*/` → `cp -r` into the vendored SDK +
  `add_subdirectory`).
- **`tools/snes-checksum.py` → HiROM support:** the internal header lives at file **$FFB0–$FFFF**
  (bank $C0) for HiROM, not $7FB0; ROM-size byte for 256 KiB/512 KiB; map-mode $21. Keep LoROM intact.
- **LUT declaration (vendored `fix16_trig_sin_lut.h`):** add `const` + a conditional
  `FAR`/`section(".far_rodata")` qualifier so the table lands in far ROM on the target but stays a
  plain `const` array on the host oracle (x86 has no addrspace 2). A documented local change to the
  vendored file:
  ```c
  #if defined(__mos__)
  #  define LUT_FAR __attribute__((address_space(2)))
  #  define LUT_SEC __attribute__((section(".far_rodata")))
  #else
  #  define LUT_FAR
  #  define LUT_SEC
  #endif
  static const LUT_FAR uint16_t _fix16_sin_lut[102688] LUT_SEC = { ... };
  ```
  `_fix16_sin_lut[tempAngle]` then lowers to a far indexed load on target, a plain load on host —
  same values, so the differential stays bit-exact.
- **`k_trig32` LUT variant:** a `FIXMATH_SIN_LUT` build of the existing kernel against `snes-hirom`.
  Keep the Taylor build too (Phase 1) — testing both sin paths is more coverage, not less. Likely a
  `K_TRIG32_LUT=1` switch in `dev/k_trig32.sh` (or a sibling `dev/k_trig32lut.sh`) selecting the
  platform cfg + `-DFIXMATH_SIN_LUT`, with its own re-baselined golden.

## Stages (each independently verifiable)

- **Stage A — HiROM platform boots.** `platforms/snes-hirom/` + checksum support; build a smoke ROM
  (sentinel `0x42`) and pass it on **MAME + bsnes-jg**. This is the platform bring-up (the hard part:
  reset path, header map-mode, vector mirror). Add `dev/run.sh smoke-hirom` (or reuse smoke with a cfg
  override).
- **Stage B — far LUT crosses banks e2e.** A `const FAR` table **>64 KiB** in `.far_rodata`, indexed
  at a runtime (volatile) index in the upper banks, folded to `corpus_result`; 4-way differential
  (host == default-N/A → host == `+mos-a16` on MAME + bsnes-jg). Proves cross-bank far rodata on real
  silicon, not just disasm.
- **Stage C — libfixmath accurate LUT.** `fix16_trig_sin_lut.h` `const FAR` change; build `k_trig32`
  with `-DFIXMATH_SIN_LUT` against `snes-hirom`; re-baseline golden; 4-way differential PASS; accuracy
  table shows `sin/cos/tan` ≈ 1e‑5 (vs Taylor ~6e‑3), `atan/asin/acos` unchanged.

## Files

**Create:** `platforms/snes-hirom/link.ld` (+ any header/cfg the platform needs),
`examples/65816/farlut.c` + `dev/farlut.sh` (Stage B probe-as-test), `dev/k_trig32lut.sh` (or a switch
in `dev/k_trig32.sh`), this plan.
**Modify:** `tools/snes-checksum.py` (HiROM), `examples/65816/libfixmath/fix16_trig_sin_lut.h`
(`const FAR` + macro — documented vendoring change), `dev/build.sh` only if injection needs a tweak,
`TODO.md`, the Phase-1 plan's *Deferred* (mark Phase 1c underway).
**SDK rebuild:** the worktree's hardlinked `build/install` is read-only; adding a platform needs an
SDK rebuild — `cp -a` main's `vendor/llvm-mos-sdk` into the worktree, `rm -rf build/install` (break
the hardlink), `dev/run.sh build` regenerates the SDK (incl. `mos-snes-hirom.cfg`) using the
hardlinked toolchain. (No `vendor/llvm-mos` / compiler change — SDK-only.)

## Verification

1. `dev/run.sh smoke-hirom` — HiROM sentinel `0x42` on MAME + bsnes-jg (Stage A).
2. `dev/run.sh farlut` — cross-bank far LUT `corpus_result` host == `+mos-a16`, both emulators (Stage B).
3. `dev/run.sh k_trig32lut` — 4-way differential PASS on the accurate-LUT build; accuracy table prints
   `sin/cos/tan` ≈ 1e‑5 (Stage C).
4. Regression: `dev/run.sh k_trig32` (Taylor, unchanged golden), `k_hopalong`, `corpus` 7/7.

## Risks

- **HiROM bring-up is iterative** — reset path, header map-mode $21, the $00:FFxx→$C0:FFxx vector
  mirror, and where PBR/DBR sit at boot. Stage A is explicitly the de-risking milestone; budget
  emulator iteration. Fallback if HiROM proves stubborn: a multi-far-bank LoROM with the LUT split per
  bank — but that re-implements the access (deviates from "use the library"), so HiROM is preferred.
- **SDK rebuild in the worktree** breaks the read-only hardlink to `build/install`; do it deliberately
  (`rm -rf build/install` first) so main's SDK is untouched.
- **Settle budget** — the LUT build is *faster* than Taylor (one indexed load vs a 6-term series), so
  `SMOKE_SECONDS`/frames can likely drop; measure.
- **Emulator HiROM detection** — MAME/bsnes-jg infer the mapper from the header; a wrong map-mode/size
  byte makes them mis-map. The checksum tool owns those bytes; verify on both.
