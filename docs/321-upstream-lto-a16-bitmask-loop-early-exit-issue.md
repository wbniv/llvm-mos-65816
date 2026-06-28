# Upstream issue — LTO + `+mos-a16`: 32-bit bitmask loop exits early for shift amounts ≥ 16

> ## ⛔ RETRACTED — MISDIAGNOSIS. **DO NOT POST.**
> Verified 2026-06-28 by a controlled rebuild + disassembly experiment
> ([plan](plans/2026-06-28-321-verify-lto-a16-bitmask-early-exit-diagnosis.md)). The `cmp #$10` this issue
> reads as "compare shift counter `r` with 16" is actually the loop's **second guard,
> `q->n < UPQ_MAX_JOBS`**, where `UPQ_MAX_JOBS = 16 = 0x10`. Proof: overriding the macro with
> `-DUPQ_MAX_JOBS=20` changed the constant to `cmp #$14` — it **tracks the macro**, so the compared value is
> `q->n` (the upload-queue depth), **not** `r`. The real `r < 28` bound (`cpy #$1c`) is present and correct.
> The `jmp rts` is the **intended per-vblank DMA-budget exit** (≤16 jobs/frame; 28 rows flush over 2 frames),
> not a row-skipping miscompile. The annotation labeling stack slot `$2c` as "loop counter r" was the error —
> it held `q->n`. **The root cause below is wrong; there is no row-16 shift-split miscompile.**
>
> The original demo stall is a *separate, still-unverified* question (a possible 32-bit `== 0` miscompile
> under LTO, or a frame-ordering bug). If pursued and confirmed, it warrants a **fresh, correctly-characterized
> issue with a real reproducer** — not this one. The `3ab028e` delay-counter workaround stands regardless.
>
> Everything below is preserved verbatim as the original (incorrect) draft.

---

**Post command** (user-triggered):
```sh
gh issue create \
  --repo llvm-mos/llvm-mos \
  --title "[65816][+mos-a16][LTO] 32-bit bitmask loop: early JMP-RTS for shift amounts ≥ 16" \
  --body-file docs/321-upstream-lto-a16-bitmask-loop-early-exit-issue.md \
  --label "bug"
```

---

## Summary

Under `+mos-a16` with LTO enabled, a loop that iterates over bits of a `uint32_t` field using
`(uint32_t)1u << r` (where `r` is a `uint8_t` counter) miscompiles: the function exits with `JMP
RTS` on the first iteration where `r >= 16`, silently skipping all high bits (16–31) of the mask.

## Environment

- **Compiler:** llvm-mos clang 23.0.0git (`c798c31416f72b395c658b5502d281a162387ab1`)
- **Target feature:** `+mos-a16` (16-bit accumulator mode, WDC 65816)
- **Flags:** `mos-clang --config mos-snes.cfg -Xclang -target-feature -Xclang +mos-a16`
  (`mos-snes.cfg` pulls in `-flto -mlto-zp=224 -mcpu=mosw65816`; the bug requires LTO)

## Minimal reproducer

```c
#include <stdint.h>

#define N_ROWS   28u
#define MAX_JOBS 15u

typedef struct { uint8_t n; } Queue;
extern void push_row(Queue *q, uint8_t r);

/* Iterates over 28 bits of a uint32_t bitmask.
 * Bits 16–27 require shift amounts ≥ 16 (upper half of uint32_t). */
void emit(uint32_t *dirty_rows, Queue *q) {
    for (uint8_t r = 0u; r < (uint8_t)N_ROWS && q->n < MAX_JOBS; r++) {
        if (!(*dirty_rows & ((uint32_t)1u << r))) continue;
        push_row(q, r);
        *dirty_rows &= ~((uint32_t)1u << r);
    }
}
```

## Expected behaviour

The loop visits all 28 iterations. When a bit is set at position `r` (including r = 16–27), the
row is processed and the bit is cleared from `*dirty_rows`.

## Actual behaviour

The loop processes rows 0–15 correctly. At `r = 16`, the function exits prematurely — a `JMP RTS`
is reached before any bit-test or work is done for that row. Rows 16–27 are never visited even
when their dirty bits are set.

## Disassembly evidence

From the linked LTO binary (llvm-mos SNES demo #20, commit `7bb4f86`), `_fact_emit` at SNES
address `0x911d` (file offset `0x111d` in the `.sfc`):

```
; rc2c = loop counter r (loaded at start of each iteration from stack slot)
9167:  a5 2c        lda $2c           ; A = r
9169:  c9 10        cmp #$10          ; compare r with 16
916b:  90 03        bcc $9170         ; if r < 16 → bit-test + DMA path
916d:  4c 2a 93     jmp $932a         ; if r ≥ 16 → *** JMP TO RTS ***
9170:  ...                            ; (normal bit-test / __ashlsi3 call / dirty-bit clear)
...
932a:  60           rts
```

The `jmp $932a` at `0x916d` jumps directly to the function epilogue (`rts`), abandoning the loop
entirely. `__ashlsi3` (the 32-bit shift library function, also linked at `0x9342`) is never called
for `r ≥ 16`.

The non-LTO compilation (`-fno-lto`) of the same source generates correct code (no `cmp #$10; jmp
rts` pattern; all 28 iterations handled with 32-bit shift paths).

## Root cause hypothesis

The `+mos-a16` LTO codegen appears to split the `(uint32_t)1u << r` expression into two paths:

- **r < 16:** result fits in 16 bits; native-16 fast path (`rep #$20`, 16-bit shift, `sep #$20`)
- **r ≥ 16:** result has non-zero bits only in the upper half; this path was incorrectly compiled
  as a direct jump to the function exit instead of falling through to the 32-bit `__ashlsi3` call

The carry-set from `cmp r, #16` is the decision bit. For r ≥ 16 the compiler should generate the
32-bit library call path; instead it generates a tail-call to the function's `rts`.

## Runtime impact

In the SNES demo this manifested as the application stalling permanently: `dirty_rows` started at
`0x0FFFFFFF` (all 28 rows marked dirty) but bits 16–27 were never cleared (rows 16–27 never
processed), so the "all rows flushed" sentinel (`dirty_rows == 0`) was never reached and the
compute loop stalled at its first result.

**Workaround:** Replace the `dirty_rows == 0` sentinel with a fixed delay counter (avoid the
32-bit zero-comparison whose upstream cause is this miscompile). Committed as `3ab028e` in the
downstream fork.

## Notes

- The bug requires LTO: `-fno-lto` produces correct code for the same source.
- Both `verify-machineinstrs` and `verify-coalescing` pass on the LTO binary — the error is in
  the code-generation phase, not the verifier-visible MIR layer.
- `__ashlsi3` itself (at `0x9342`, 16 bytes) appears correct in the linked binary; the bug is
  that it is never called for shift amounts ≥ 16.
- Compiler version at time of discovery: `c798c31416f72b395c658b5502d281a162387ab1` (the
  llvm-mos tree this fork is based on).
