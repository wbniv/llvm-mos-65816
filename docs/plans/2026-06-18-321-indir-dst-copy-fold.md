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

## Implementation plan (when triggered)

### Trigger condition

Before starting: compile the 7-corpus ROMs with `+mos-a16` and grep the disasm for the
`sta __IMAG16 / lda __IMAG16 / sta (zp)` round-trip fingerprint in indirect-store
contexts. If the pattern accounts for ≥ 4 B aggregate in ≥ 2 programs, proceed.

### Change: selector reorder in `selectMem16Indir`

**File:** `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstructionSelector.cpp`

In the `selectMem16Indir` store path, after `loadStoreValueIntoA16` returns the round-trip
(ZP-spill) form: check whether the only intervening MI between the value-load and the store
is an ordered ptr-load that:

1. Has no aliasing with the value-load's memory operand (different base pointers), and
2. Is the ptr-load for the store's pointer operand (the `dp_ptr` load).

If both conditions hold, call `PtrLoadMI->moveBefore(&*ValueLoadMI)`, then retry
`loadStoreValueIntoA16`. The retry should now succeed and emit the folded form:

```
rep #$20
lda abs_global          ; load value (now adjacent to store)
sta (dp)                ; fold: direct store via ptr
sep #$20
```

**Safety note:** Moving a volatile LOAD to an earlier position w.r.t. a non-volatile LOAD
is valid under LLVM's memory model. Volatile ordering is enforced only vs. _other_ volatile
accesses, not vs. non-volatile reads. The ptr-load is volatile (it reads from a volatile
pointer variable); the value-load is non-volatile. Moving ptr-load earlier does not
reorder two volatile accesses and does not introduce a data race.

### Micro-test update

Extend `examples/65816/a16indirdst.c` and `dev/a16indirdst.sh` to assert:
- Disasm gate: no `sta __IMAG16` / `lda __IMAG16` round-trip in the store path
- `corpus_result` unchanged (host == default == `+mos-a16`, MAME + bsnes-jg)
- Byte count: `+mos-a16` ≤ 24 B (from 28 B; gate for ~4 B improvement)

---

## Verification

Run after implementation:

1. **Toolchain rebuild**: `dev/run.sh toolchain`; confirm `clang-23` mtime advanced.

2. **Micro-test**: `dev/run.sh a16indirdst` → corpus_result == host == default == `+mos-a16`
   on MAME + bsnes-jg; disasm gate passes (no ZP round-trip in store path); byte count ≤ 24 B.

3. **Full a16 suite + kernels**:
   `for f in dev/a16*.sh dev/k_*.sh; do dev/run.sh "$(basename "$f" .sh)"; done` → all pass.

4. **Corpus**: `dev/run.sh corpus` → 7/7.

5. **Fuzzer**: `dev/run.sh fuzz 50 1` → 50/50, 0 mismatch, 0 crash.

6. **MIR verify**: compile `a16indirdst.c` with `-mllvm -verify-machineinstrs`; clean exit.

7. **Patch round-trip**: `dev/regen-patch.sh`; confirm no foreign symbols in
   `0002-321-accum16.patch`.

---

## References

- Spike measurement: [task7 plan](2026-06-17-321-task7-eq-residuals-indir-dst-xflag-varshift.md) §8, item 5
- Indirect store implementation: [indirect load/store plan](2026-06-15-321-native-16bit-indirect-load-store.md)
- TODO bullet: `#321 native s16 memory-access follow-ups` item (a)
