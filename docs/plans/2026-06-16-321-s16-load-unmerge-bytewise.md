# #321 — s16 load consumed only as bytes: keep it byte-wise (EQ-as-value prologue fix)

**Date:** 2026-06-16
**Status:** implemented (partial win for M2 item (c)); verification in progress
**ROADMAP:** step 5 (M2) · **TODO:** M2 "16-bit comparison follow-ups" item (c)

## Context

M2 item (c) is "native s16 equality-as-value (`b = (a == c)`)": today it narrows to the 8-bit cpx/cpy
chain instead of a native 16-bit compare. Investigating the actual codegen surfaced two distinct issues:

1. **A `+mos-a16` REGRESSION (cheap to fix — this plan).** Under `+mos-a16` the s16 operand *loads*
   were emitted as native 16-bit loads (`G_LOAD16_ABS` → `lda abs → A16; sta imag16`) and then the
   8-bit-narrowed compare immediately `G_UNMERGE`d them back into bytes — a wasteful 16-bit-load→spill→
   re-read round-trip the default (non-a16) build never does (it loads the bytes directly). This makes
   `+mos-a16` EQ-as-value *worse* than default.

2. **The native EQ-as-value itself (deferred — see TODO).** Making the compare native (one
   `rep; lda; cmp; sep` + materialize Z→0/1) needs a fused compare-**select** mechanism the backend
   doesn't have — see "Deferred" below.

## Fix (this plan) — `MOSLegalizerInfo.cpp::legalizeLoadStore16`

When an s16 **load** is consumed **only** by `G_UNMERGE` (every use is a byte split), skip the native
16-bit `G_LOAD16_ABS` and fall back to the existing byte-wise `narrowScalar` (two 8-bit loads — exactly
the default codegen). A value used only byte-wise should be loaded byte-wise; forming the 16-bit load
just to read the bytes back is pure overhead. Stores are unaffected (always native); the
**indirect**-load variant is left native for now (see Deferred).

Result: `+mos-a16` `b = (a == c)` now loads its operands with direct 8-bit `ldx`/`lda` + `cmp`/`cpx`
(matching default for the compare); the only remaining 16-bit `rep`/`sep` is the native store of the
`unsigned short` result — not the compare. Brings EQ-as-value back to parity with default (it was a
regression); the full native compare is the separate deferred win.

## Verification

1. `+mos-a16` `b = (a == c)` disasm: operands load byte-wise (`ldx`/`lda`/`cpx`/`cmp`), **no**
   `rep; lda abs; sta imag16` operand round-trip; `-verify-machineinstrs` clean. **PASS** — the first
   8-bit compare is at offset `0x11`, the first `rep #$20` is far later (the result store); verify exit 0.
2. Value: `examples/65816/a16eqval.c` + `dev/a16eqval.sh` — `host == default == +mos-a16` on MAME +
   bsnes-jg. **PASS** — `RESULT: PASS`; `corpus_result == 0x0101`, `SMOKE: PASS` default + a16 (MAME) +
   bsnes-jg, plus the no-prologue gate ("first 8-bit compare precedes any rep #$20").
3. Non-breaking: full a16 suite + corpus 7/7 + `fuzz 50 1` 50/50. **PASS** — `==== suite: 42 PASS, 0
   FAIL ====` (now 43 with `a16eqval`), `==> corpus: 7/7 passed`, `==> fuzz: 50/50 PASS, 0 xfail (0
   mismatch, 0 new-crash, 0 error)`.
4. `dev/regen-patch.sh` round-trips (`0002`). **PASS** — `RESULT: PASS — 0002 round-trips`.

**Status: all verification PASS (2026-06-16); landed in commit `7c0fe56`.**

## Deferred (TODO entries)

- **Full native s16 EQ-as-value (the original item (c)).** A native equality-as-value would be one
  `rep; lda; cmp; sep` then materialize **Z**→0/1. The backend has **no compare that produces N/Z as a
  value** — every flag-as-value path is carry-based, and N/Z are only ever branch-fused (the 8-bit
  EQ-as-value computes equality into C via `sec`/`clc`; the 16-bit Z path only exists as the fused
  compare-*branch* `CmpBrImag16`/`CmpBrImm16`). Making it native needs a new fused compare-**select**
  pseudo (`CmpSelImag16`/`CmpSelImm16`) + expansion (mirror `expandCmpBr16` but end in
  `beq/bne; ldx #1/stz`), folded into the `SelectImm` selection via the existing `m_CmpNZ*16` matchers,
  plus relaxing the `NativeS16EqBranch` gate. Deliberately deferred by the 2026-06-15 equality work for
  exactly this reason. Substantial; modest win on a rare pattern.
- **Indirect s16 load consumed only as bytes.** This plan gates only the **absolute** load
  (`G_LOAD16_ABS`); an indirect s16 load (`G_LOAD16_INDIR`) whose uses are all `G_UNMERGE` still takes
  the native 16-bit form and round-trips. Same `AllUsesUnmerge` guard would apply; lower priority
  (rarer, and the byte-wise indirect lowering `(zp),y` is less clearly a win).
