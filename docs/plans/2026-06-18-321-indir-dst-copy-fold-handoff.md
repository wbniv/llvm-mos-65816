# Handoff: indir-dst copy fold (`*p = gg`, `*q = *p`)

**Date:** 2026-06-18  
**Branch:** `main` · **Worktree:** `/home/will/SRC/llvm-mos-65816`  
**Plan:** [`docs/plans/2026-06-18-321-indir-dst-copy-fold.md`](2026-06-18-321-indir-dst-copy-fold.md)

---

## Status: CLOSED — WON'T-DO (corpus trigger check failed 2026-06-18)

Corpus check ran 2026-06-18: compiled all 6 corpus programs (`arith`, `arrays`, `control`,
`funcs`, `globals`, `structs`) with `+mos-a16` and checked for the round-trip fingerprint.
**Result: 0/6 programs, 0 B aggregate** — no `sta (zp)` in any 16-bit context, no
`__IMAG16` round-trip pattern anywhere.

No corpus program uses the `volatile T *volatile p_var` pattern that triggers the block;
the −13 B from natural 16-bit mode is already captured. Selector reorder not justified.
TODO bullet `#321 native s16 memory-access follow-ups` moved to Done.

---

## Step 0: corpus trigger check

Compile the 7-corpus programs with `+mos-a16` and look for the Imag16 round-trip
fingerprint in indirect-store contexts. The round-trip looks like:

```
sta abs+1     ; spill value hi to __IMAG16
sta abs       ; spill value lo to __IMAG16
lda abs       ; reload value from __IMAG16 into A16
sta (zp)      ; store via pointer
```

In practice, search for back-to-back `sta __IMAG16 / lda __IMAG16 / sta (zp)` in the disasm
of each corpus ROM. A quick corpus disasm run (after `dev/run.sh corpus` confirms 7/7):

```bash
# Build all 7 corpus ROMs with +mos-a16 (the corpus script already does this)
dev/run.sh corpus

# Disassemble each +mos-a16 ROM and grep for the round-trip pattern
for rom in build/corpus/a16/*.sfc; do
  echo "=== $rom ===" 
  llvm-objdump -d "$rom" 2>/dev/null | grep -c "sta (zp)" || true
done
```

Alternatively, compile each corpus `.c` file directly and inspect the `.text` byte counts
vs. a notional folded form. **Proceed only if the pattern appears in ≥ 2 programs and
accounts for ≥ 4 B aggregate.**

If the pattern is absent or marginal → mark the TODO bullet `[x]` as WON'T-DO with the
corpus evidence, and close this plan.

---

## What you're implementing (when triggered)

### The bug

`selectMem16Indir` in `MOSInstructionSelector.cpp` (grep `selectMem16Indir`) calls
`loadStoreValueIntoA16` to fold the value source directly into the store. That fold
requires the value-load MI and the store MI to be adjacent (`shouldFoldMemAccess`). When
the **dst-pointer load** sits between them as a volatile-ordered memref, the fold bails and
emits the round-trip through `__IMAG16` (ZP-spill).

### The fix: one MI reorder

In the store path of `selectMem16Indir`, after `loadStoreValueIntoA16` returns the
round-trip form, check whether the **sole** intervening MI is the ptr-load for this store's
pointer operand. If it satisfies both conditions below, move it before the value-load and
retry:

```
Condition 1: PtrLoadMI aliases nothing in the value-load's memory operands
             (different base pointers — they don't read the same memory)
Condition 2: PtrLoadMI is the load feeding the pointer operand of this store
             (i.e., its result register is the store's pointer base register)
```

```cpp
// In selectMem16Indir, store path, after the round-trip fallthrough:
if (MachineInstr *PtrLoadMI = solyBlockingPtrLoad(ValueLoadMI, StoreMI, MRI)) {
  PtrLoadMI->moveBefore(&*ValueLoadMI);  // move ptr-load before value-load
  if (loadStoreValueIntoA16(...))        // retry the fold
    return true;
  // if retry still fails, undo (or just fall through to round-trip — functionally correct)
}
```

**Safety:** Moving a volatile LOAD before a non-volatile LOAD is valid under LLVM's memory
model. Volatile ordering is enforced only against *other* volatile accesses, not against
non-volatile reads. The ptr-load (reading a volatile pointer variable) moving earlier does
not reorder two volatile accesses and cannot introduce a data race.

### Expected output

Before (round-trip):
```
lda abs_global     ; load value lo
sta __IMAG16_lo    ; spill lo
lda abs_global+1   ; load value hi  
sta __IMAG16_hi    ; spill hi
lda dp_ptr         ; load volatile ptr  ← was blocking the fold
rep #$20
lda __IMAG16       ; reload value from ZP
sta (zp)           ; store via ptr
sep #$20
```

After (folded):
```
lda dp_ptr         ; ptr-load moved earlier (safe)
rep #$20
lda abs_global     ; value load now adjacent to store
sta (zp)           ; direct store via ptr, no ZP round-trip
sep #$20
```

---

## Micro-test

The spike test is `examples/65816/a16indirdst.c` (already exists from the task7 spike).
Extend it and `dev/a16indirdst.sh` to assert:

- **Disasm gate:** no `sta __IMAG16` / `lda __IMAG16` pattern in the store path
- **Corpus result:** host == default == `+mos-a16` on MAME + bsnes-jg
- **Byte count gate:** `+mos-a16` `.text` ≤ 24 B (down from 28 B before the reorder)

Use `dev/a16eqval.sh` + `examples/65816/a16eqval.c` as the template for the gate structure.

---

## Build / verify commands

```bash
dev/run.sh toolchain     # rebuild after vendor/ edit — confirm clang-23 mtime advanced
                          # (clang symlink is stale; clang-23 is the real binary)
dev/run.sh a16indirdst   # micro-test: corpus_result + disasm gate + byte count

# Host MIR verify (no container):
build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 \
  -Os -mllvm -verify-machineinstrs -c examples/65816/a16indirdst.c -o /tmp/x.o

# Full a16 suite + kernels:
for f in dev/a16*.sh dev/k_*.sh; do dev/run.sh "$(basename "$f" .sh)"; done

dev/run.sh corpus        # 7/7
dev/run.sh fuzz 50 1    # 50/50, 0 mismatch, 0 crash
```

---

## Commit discipline

One logical change → one commit on `main` (no worktree needed for this task).

- **Stage only your files.** Never stage `vendor/` (gitignored) or `docs/transcripts/`.
- **Regenerate the patch** after the vendor/ edit: `dev/regen-patch.sh`
- **Sanity-check the patch** didn't absorb foreign hunks:
  ```bash
  grep -c "PtrLoadMI\|solyBlocking" patches/llvm-mos/0002-321-accum16.patch
  ```
- **Co-Authored-By line:**  
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- **Do NOT push to `origin/main`** — coordinate with user first.
- After committing, triage any `## Inbox` items the `audit-plan-deferrals` hook adds to
  `TODO.md` and re-commit if needed.

---

## If corpus check fails (expected outcome)

Update the TODO bullet under `#321 native s16 memory-access follow-ups` item (a) with the
negative corpus evidence and demote the plan status to WON'T-DO. Short note in the bullet:

> **corpus check 2026-XX-XX:** pattern absent / < 4 B aggregate in corpus — WON'T-DO.

Then remove the TODO bullet's `indir-dst fold plan` link or annotate it done.

---

## References

- Plan: [`docs/plans/2026-06-18-321-indir-dst-copy-fold.md`](2026-06-18-321-indir-dst-copy-fold.md)
- Spike measurements: [task7 plan](2026-06-17-321-task7-eq-residuals-indir-dst-xflag-varshift.md) §8 item 5
- Indirect store selector: `selectMem16Indir` in `MOSInstructionSelector.cpp` (grep anchor)
- TODO bullet: `#321 native s16 memory-access follow-ups` item (a)
