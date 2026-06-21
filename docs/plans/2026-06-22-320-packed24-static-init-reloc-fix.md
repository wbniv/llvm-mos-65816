# #320 packed-24 — static-init relocation fix (the realistic table use case)

**Date:** 2026-06-22 · **Status:** IN PROGRESS · **Worktree:** `wt/320-packed24-incB` ·
**Parent:** [packed-24 productionization handoff](2026-06-21-320-packed24-productionization-handoff.md) Task A/B.

## The finding (Task A measurement surfaced it)

packed-24 Increment B (0006) is verified for the **runtime** store/load/deref path (`packed24_e2e.c`), but
the **realistic use case — a statically-initialized table of packed far pointers** (a compact jump/asset
table, the entire justification for the feature) — **does not link**:

```
ld.lld: error: .rodata.table+0x0: relocation R_MOS_ADDR8 out of range:
        -32768 is not in [-128, 255]; references section '.far_rodata'
```

Measured win (object level, `dev/measure-packed24.sh` / `packed24_table.c`): packed beats far by ≈N bytes at
every table size (break-even N≥1) — the indexed-walk access code is equal (far even loads only 3 of its 4
bytes; the ×3-vs-×4 stride is a constant), so the feared "×3-index + byte-2" cost does **not** apply to
indexed table access. But the win is **unrealizable** for static tables until the link error is fixed.

## Root cause

A static `(AS_FarPacked*)&far_sym` initializer is a `ConstantExpr(addrspacecast)`. The generic
`AsmPrinter::emitGlobalConstantImpl` leaf does `ME = lowerConstant(CV); OutStreamer->emitValue(ME, Size)` with
`Size = sizeof(p3) = 3`. But `MCFixup::getDataKindForSize(3)` is `llvm_unreachable` (only 1/2/4/8 exist); in
the release toolchain that UB degrades to `FK_Data_1` → `R_MOS_ADDR8` — a single 1-byte reloc on the low byte
(the high 2 bytes are unrelocated zero), which both overflows and drops the bank. `0006` only handled the
runtime GISel path, never the AsmPrinter static-data path.

The runtime path already proves lld resolves the **`R_MOS_ADDR24_SEGMENT_LO` / `_SEGMENT_HI` / `_BANK`**
triple, and lld writes **exactly one byte per** segment/bank reloc (vs `R_MOS_ADDR24` which does a 4-byte
`write32le` and would overrun a 3-byte slot). So the triple is the correct, robust lowering.

## The fix

1. **Generic AsmPrinter hook** (fork edit, captured by the extended `regen-patch-0006.sh`): a virtual
   `emitNonStandardSizedConstant(CV, ME, Size)` (default `return false`) called in the
   `emitGlobalConstantImpl` leaf before the `emitValue(ME, Size)` fallback. Targets with an odd-sized
   relocated pointer emit the bytes themselves.
2. **`MOSAsmPrinter::emitNonStandardSizedConstant`**: gated strictly on `Size==3 &&
   pointee-AS == MOS::AS_FarPacked`, emit `ME` three times wrapped in `VK_ADDR24_SEGMENT_LO/_HI/_BANK`
   (1 byte each) → the full 24-bit address, bank intact. Everything else falls through unchanged.
3. **`regen-patch-0006.sh`**: add the two generic AsmPrinter files to `PACKED_FILES` so a regen captures the
   hunks (the script overlays a file list, not the whole MOS dir).

Strict `AS_FarPacked` gate ⇒ a misclassification is impossible (only p3 fires); default / non-p3 codegen is
provably byte-identical (the fuzzer guarding the default build is the gate).

## Verification (the bar)

1. `dev/run.sh packed24_table` — static packed table (8×3=24 B vs far 8×4=32 B) **links**, boots, walks 8
   bank-`$01` entries, sums → `0xA5` on MAME (bank byte survives each static 3-byte entry). bsnes-jg via xcheck.
2. `dev/run.sh packed24` (the runtime e2e) still green.
3. Non-breaking: `dev/run.sh corpus` 7/7; far suite green; `dev/run.sh fuzz 50 1` 0-mismatch;
   `-verify-machineinstrs` clean. Default codegen byte-identical (the fuzzer is the gate for the generic
   AsmPrinter touch).
4. Regen `0006` (`dev/regen-patch-0006.sh`), round-trip-verify, stage only my files, land.

## Risk / cap

Per the handoff §5 (packed-24 is a speculative opt): if lld or the emission fights back beyond ~3 attempts,
record the precise blocker + verdict and stop. The fix is small + reuses proven relocs, so this is expected
to land; the generic AsmPrinter touch is the only non-MOS surface (minimal: one virtual + one guarded call).

## Outcome — DONE + verified + landed (2026-06-22)

Two-attempt fix (the first attempt wrapped the symbol in `MOSMCExpr::create(VK,…)`, whose
`evaluateAsRelocatableImpl` drops the specifier on a relocatable result → still `R_MOS_ADDR8`; the working
form puts the specifier on the `MCSymbolRefExpr` itself, mirroring the jump-table low/high-byte emission —
`retagFarByte`). Landed on `main` as the updated **`0006-320-packed24.patch`** (387 lines / 10 files; the new
files are `MOSAsmPrinter.cpp`, the generic `AsmPrinter.h`/`AsmPrinter.cpp` hook — added to
`regen-patch-0006.sh`'s `PACKED_FILES`).

### Verification (the bar) — all PASS

**1. Static packed table links + correct on BOTH emulators.**
```
dev/run.sh packed24_table:
  storage gate PASS: packed=24 B vs far=32 B  (saved 8 B, 25%)
  disasm gate  PASS: far deref via LDA IndirectLong (a7)
  MAME      : SMOKE: PASS off=0x7E0200 got=0xA5 (8 bank-$01 reads via the static packed table)
  bsnes-jg  : SMOKE: PASS off=0x200 len=1 got=0xA5 (180 frames)   [build/jgxcheck packed24_table.sfc]
```
Object relocs are now the correct triple per 3-byte entry:
```
.rodata.table+0: R_MOS_ADDR24_SEGMENT_LO a0   +1: R_MOS_ADDR24_SEGMENT_HI a0   +2: R_MOS_ADDR24_BANK a0  …
```
(was a single `R_MOS_ADDR8` per entry → link error).

**2. Non-breaking.** `dev/run.sh packed24` (runtime e2e) PASS `0xF3`; `dev/run.sh corpus` **7/7**;
`dev/run.sh fuzz 50 1` → **45/50 PASS, 0 mismatch / 0 crash** (5 GC'd skips) — the csmith differential is the
gate for the generic AsmPrinter touch (default codegen unperturbed; the hook only fires for
`Size==3 && AS_FarPacked`, which csmith never emits); `-verify-machineinstrs` clean.

**3. Reproducible.** `dev/regen-patch-0006.sh` round-trips (`0001..0006` reproduces every packed-24 file,
incl. the two generic AsmPrinter files now in `PACKED_FILES`).

### Task A verdict (measured, `dev/run.sh measure-packed24`)

packed-24 wins **≈N bytes at every table size, break-even N≥1** — in an indexed table walk the access code is
equal (far loads only 3 of its 4 entry bytes; the ×3-vs-×4 stride is a constant), so the feared "×3-index +
byte-2-long" cost does **not** apply to indexed table access (only to direct single-slot access — handoff
Task B). With the static-init fix, that win is now **realizable** for the realistic jump/asset-table shape.

| N | far (tbl+code) | packed (tbl+code) | net |
|---:|---:|---:|---:|
| 4 | 16+36 | 12+36 | −4 B |
| 16 | 64+54 | 48+53 | −17 B |
| 64 | 256+52 | 192+51 | −65 B |
