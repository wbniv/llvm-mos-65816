# #321 — indirect s16 load consumed only as bytes: extend the byte-wise guard

**Date:** 2026-06-16
**Status:** planned (low priority; investigation-gated — the win is not yet proven)
**ROADMAP:** step 5 (M2) · **TODO:** M2 "16-bit comparison follow-ups"
**Predecessor:** [s16-load-unmerge byte-wise fix](2026-06-16-321-s16-load-unmerge-bytewise.md)
(commit `7c0fe56`) — this is its one remaining follow-up.

## Context

The byte-wise-load fix taught `MOSLegalizerInfo::legalizeLoadStore16` that an s16 **load** whose every
use is `G_UNMERGE` (the value is only ever split into bytes — e.g. an s16 global feeding an
8-bit-narrowed compare) should keep its byte-wise lowering instead of forming a native 16-bit load that
the consumer immediately unmerges back (`lda → A16; sta imag16; … read bytes`).

That fix gates **only the absolute load** (`G_LOAD16_ABS`). The **indirect** load — a runtime 16-bit
pointer → `G_LOAD16_INDIR` (`lda (zp)` in M=0, the `else if (STI.has65C02())` branch at
`MOSLegalizerInfo.cpp:1759`) — is still taken native unconditionally, so an indirect s16 load whose uses
are all `G_UNMERGE` (e.g. `b = (*p == c)`, `b = (a[i] == c)`) still round-trips through `A16`.

Unlike the absolute case, the win here is **not obvious**:

- **Native (today):** `lda (zp)` (one 16-bit indirect load) → `sta imag16` (spill) → the `G_UNMERGE`
  consumers read the two `imag16` bytes.
- **Byte-wise (`narrowScalar`):** two `lda (zp),y` (`y=0`, `y=1`) indexed-indirect loads straight into
  the byte values — but needs `Y` set up (and possibly preserved/reloaded), so it is **not clearly
  fewer cycles/bytes** than the native load+spill. (The absolute case was a clear win: two plain
  `lda abs` with no index, no spill.)

So this is an **investigation-led** optimization, not a mechanical extension.

## Approach

1. **Measure first.** Build a representative indirect-s16-load-then-unmerge body (e.g. `b = (*p == c)`
   and `b = (a[(unsigned)i & 7] == c)`, the result stored as a value) and compare, under `+mos-a16`:
   native `G_LOAD16_INDIR` + unmerge vs. the byte-wise `narrowScalar` (`(zp),y` ×2). Count
   instructions/cycles. Only proceed if byte-wise is a clear win (or at least never worse) across the
   shapes; if it's a wash or context-dependent, **document and skip** (record the measurement).

2. **If it wins — one-line gate.** `AllUsesUnmerge` is already computed at the top of
   `legalizeLoadStore16`; just guard the indirect branch the same way the absolute branch is guarded:

   ```cpp
   } else if (STI.has65C02()) {
     if (!AllUsesUnmerge) {
       ... G_LOAD16_INDIR / G_STORE16_INDIR ...   // existing
       return true;
     }
     // else: all-uses-unmerge load -> fall through to byte-wise narrowScalar below
   }
   ```

   Stores are unaffected (`AllUsesUnmerge` is load-only). `narrowScalar` of an indirect s16 load is the
   existing fallback (it already handles `<65C02`/far/non-a16), so it is well-tested.

## Verification (if implemented)

1. Indirect EQ-as-value (`b = (*p == c)`) disasm under `+mos-a16`: operands load byte-wise via `(zp),y`,
   no `lda (zp) → A16 → sta imag16` round-trip; `-verify-machineinstrs` clean — **and** instruction
   count ≤ the native form (the gating measurement, captured in this plan).
2. Value: a micro-test (`examples/65816/a16eqvalp.c` or extend `a16eqval.c` with an indirect operand)
   `host == default == +mos-a16` on MAME + bsnes-jg.
3. Non-breaking: full a16 suite + corpus 7/7 + `fuzz 50 1` 50/50 (the change touches every
   indirect-s16-load-then-unmerge site).
4. `dev/regen-patch.sh` round-trips (`0002`).

## Why low priority

- The pattern (an *indirect* s16 load whose result is consumed *only* byte-wise) is rarer than the
  absolute case.
- The win is uncertain (see Context) — it may be neutral, so the measurement step may conclude "skip".
- Correctness is already fine (the native indirect load is correct; this is purely about avoiding the
  round-trip). No bug, just a possible size/speed nudge.
