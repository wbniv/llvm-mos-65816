# #321 — Indir-dst copy fold (`*p = gg`, `*q = *p`)

**Date:** 2026-06-18 · **Status:** WON'T-DO — corpus trigger check failed 2026-06-18  
**Corpus evidence:** 0/6 programs generated `sta (zp)` in 16-bit context; 0 B `__IMAG16` round-trip pattern (threshold: ≥ 4 B in ≥ 2 programs). Pattern absent — selector reorder not justified.  
**Handoff:** [`docs/plans/2026-06-18-321-indir-dst-copy-fold-handoff.md`](2026-06-18-321-indir-dst-copy-fold-handoff.md)

---

## Problem

The 16-bit indirect-store fold in `selectMem16Indir` only fires when the value-load MI and
the store MI are adjacent — i.e. `shouldFoldMemAccess` can see through all intervening
instructions. When the **dst-pointer load** sits between the value-load and the store as an
ordered (volatile) `memref`, the fold conservatively bails and emits the round-trip:

```
// *volatile_ptr_var = global16
lda abs_global          ; load value into A
sta __IMAG16_lo         ; spill lo to ZP
lda abs_global+1        ; load value hi
sta __IMAG16_hi         ; spill hi to ZP
lda dp_ptr              ; load dst ptr lo  ← the volatile memref separates load from store
sta …                   ; … etc.
rep #$20
lda __IMAG16            ; reload value from ZP
sta (dp)                ; store via ptr
sep #$20
```

The fix: in the selector, when the sole blocker is an intervening ordered ptr-load that
doesn't alias the value source, move the ptr-load MI _before_ the value-load MI (making
them adjacent) and retry the fold.

---

## Current state (spike, 2026-06-17 task7)

Micro-test `examples/65816/a16indirdst.c` — pattern `*volatile_ptr_var = global16`:

| Build        | `.text` bytes |
|--------------|--------------|
| default      | 41 B         |
| `+mos-a16`   | 28 B         |
| delta        | **−13 B** (already; natural 16-bit mode, no selector reorder) |

The −13 B is already captured by the existing natural-16-bit codegen: `+mos-a16` keeps the
accumulator in M=0, so the two-byte indirect store costs one `rep/sta(zp)/sep` vs the
default's two-byte pair. The selector reorder (moving the volatile ptr-load before the
value-load) would fold the global load into `cmp abs` / `lda abs; sta (zp)` form and save
approximately **~4 B more**.

Corpus-level impact of those additional 4 B is **unverified** — the pattern needs to appear
in at least one corpus program at a frequency that shows up in the 7-ROM byte counts before
the implementation is justified.

---

## Implementation plan (NOT EXECUTED — WON'T-DO)

_Corpus trigger check failed 2026-06-18: 0/6 programs, 0 B aggregate. Preserved below
for reference if the pattern eventually appears in a larger corpus._

### Trigger condition

Compile corpus programs with `+mos-a16` and grep for `sta __IMAG16 / lda __IMAG16 / sta
(zp)` round-trip fingerprint in indirect-store contexts. Threshold: ≥ 4 B in ≥ 2 programs.

### Change: selector reorder in `selectMem16Indir`

**File:** `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstructionSelector.cpp`

In the `selectMem16Indir` store path, after `loadStoreValueIntoA16` returns the round-trip
(ZP-spill) form: check whether the only intervening MI between the value-load and the store
is an ordered ptr-load that:

1. Has no aliasing with the value-load's memory operand (different base pointers), and
2. Is the ptr-load for the store's pointer operand (the `dp_ptr` load).

If both conditions hold, call `PtrLoadMI->moveBefore(&*ValueLoadMI)`, then retry
`loadStoreValueIntoA16`.

**Safety note:** Moving a volatile LOAD to an earlier position w.r.t. a non-volatile LOAD
is valid under LLVM's memory model — volatile ordering is enforced only vs. _other_ volatile
accesses, not vs. non-volatile reads.

---

## References

- Spike measurement: [task7 plan](2026-06-17-321-task7-eq-residuals-indir-dst-xflag-varshift.md) §8, item 5
- Indirect store implementation: [indirect load/store plan](2026-06-15-321-native-16bit-indirect-load-store.md)
- TODO bullet: `#321 native s16 memory-access follow-ups` item (a)
