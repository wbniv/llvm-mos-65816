# #321 — indirect s16 load consumed only as bytes: extend the byte-wise guard

**Date:** 2026-06-16
**Status:** **measured (2026-06-16) → recommend SKIP / document** (revised after a second measurement).
The first pass used isolated leaf functions and showed a clean −6 B win — but that pinned the
accumulator at 8-bit (M=1). Re-measuring in realistic **16-bit-ambient** code (where `+mos-a16` spends
most of its time) shows the win is **schedule-dependent, not universal**: byte-wise wins −6 B only when
the load is *adjacent* to its byte-compare, and is a **+2 B regression** when 16-bit arithmetic is
scheduled between the load and the compare (common, since the `==` result usually feeds more 16-bit
math). The blanket `AllUsesUnmerge` gate can't tell those apart, so per the decision bar (*not
meaningfully worse elsewhere*) it **no longer clears the bar**. The real fix is native 16-bit
EQ-as-value (the deferred `CmpSelImag16`), which removes the unmerge — and the dilemma — entirely.
**Decision bar (per review):** a *modest* win — even one confined to realistic circumstances — justifies
implementing, **as long as byte-wise is not meaningfully worse in the other cases**; it now fails that.
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
are all `G_UNMERGE` (e.g. `b = (*p == c)`, `b = (p[i] == c)`) still round-trips through `A16`.

The two sides, with the mode-switch cost included (corrected after review — the predecessor framing had
dropped it):

- **Native (today):** `rep #$20` (enter 16-bit A — the indirect 16-bit load needs M=0, and the ambient
  mode for an 8-bit-narrowed compare is M=1) → `lda (zp)` (one 16-bit indirect load) → `sta imag16`
  (spill) → `sep #$20` (back to 8-bit) → the `G_UNMERGE` consumers read the two `imag16` bytes. The
  `rep`/`sep` pair (≈3+3 cyc, 2+2 B) is pure overhead the byte path never pays.
- **Byte-wise (`narrowScalar`):** byte loads through the zp pointer (expected `(zp),y` with `y=0`/`y=1`,
  but the exact emission — `iny` vs two `ldy`, or a pointer increment — **must be read from the disasm,
  not assumed**) straight into the byte values, in 8-bit mode (no `rep`/`sep`). Needs `Y` set up (and
  possibly preserved/reloaded if `Y` is otherwise live). (The absolute case was a clear win: two plain
  `lda abs` — no index, no spill, no mode switch.)

So once the mode switch is counted, the native side is heavier than the predecessor framing implied —
byte-wise is **plausibly a modest win when `Y` is free**; the genuinely open question is the `Y`-busy
case (save/restore around the byte loads). Hence: **measure both.** This stays an investigation-led
optimization, not a mechanical extension.

*(Alternative not pursued: a cheaper **native** byte extraction via `xba` instead of the `sta imag16`
spill. Likely impractical — preserving the compare's flags across `xba` is awkward, which is presumably
why the backend spills — but noted so byte-wise isn't treated as the only alternative to the round-trip.)*

## Approach

1. **Measure first** (revised after review — the original `a[i]` shape and the cost model both had gaps):

   0. **Confirm the path.** Each candidate body must actually legalize to `G_LOAD16_INDIR`, not
      `G_LOAD16_ABS`/abs-indexed. Verify with `-mllvm -print-after=legalizer`. A *global* array `a[i]`
      is absolute-indexed → it takes the abs path (already gated by `7c0fe56`) and is **not** this case.
      Use genuinely-indirect shapes: a pointer-parameter deref `*p`, `p[i]` where `p` is a `uint16_t *`
      (a pointer, not an array), or a struct-/list-pointer walk.

   1. **Capture native** disasm + byte/cycle/instruction counts (baseline). Should show the `rep`/`sep`
      + `lda (zp)` + `sta imag16` round-trip.

   2. **Capture byte-wise:** apply the throwaway guard (gate the indir branch on `!AllUsesUnmerge`),
      rebuild, disasm. **Confirm the actual addressing** narrowScalar emits (don't assume `(zp),y`×2).

   3. **Compare bytes / cycles / instructions** — decide on **bytes** (the `-Os` target), cycles as
      tiebreaker. Measure in **both** contexts: (i) `Y` otherwise free, (ii) `Y` already live across the
      load (worst case for byte-wise: e.g. an indexed 8-bit store `out[i] = (*p == c)`).

   4. **Revert** the throwaway guard (measurement scratch only).

2. **If it wins (per the decision bar) — one-line gate.** `AllUsesUnmerge` is already computed before
   both branches in `legalizeLoadStore16` (line 1739); guard the indirect branch the same way the
   absolute branch is guarded:

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

   **Caveat on "conditional" wins:** the gate is *blanket* — the legalizer runs before register
   allocation, so it cannot see `Y` pressure. A "wins when `Y`-free, loses when `Y`-busy" result can
   only be captured by always-byte-wise; it justifies implementing only if the `Y`-free case dominates
   and the `Y`-busy case is ≈neutral. If the measurement comes back genuinely mixed, surface the numbers
   for a decision rather than auto-implementing.

## Verification (if implemented)

1. Indirect EQ-as-value (`b = (*p == c)`) disasm under `+mos-a16`: operands load byte-wise through the
   zp pointer, no `rep; lda (zp) → A16; sta imag16; sep` round-trip; `-verify-machineinstrs` clean —
   **and byte count ≤ the native form** (the gating measurement, captured in this plan; cycles as
   tiebreaker).
2. Value: a micro-test (`examples/65816/a16eqvalp.c` or extend `a16eqval.c` with an indirect operand)
   `host == default == +mos-a16` on MAME + bsnes-jg.
3. Non-breaking: full a16 suite + corpus 7/7 + `fuzz 50 1` 50/50 (the change touches every
   indirect-s16-load-then-unmerge site). NB: fuzz/corpus are *non-regression* guards — they likely don't
   *generate* this exact pattern, so the step-2 micro-test is the real positive coverage.
4. `dev/regen-patch.sh` round-trips (`0002`).

## Why low priority

- The pattern (an *indirect* s16 load whose result is consumed *only* byte-wise) is rarer than the
  absolute case.
- The win, once mode-switch overhead is counted, is plausibly a modest one in the `Y`-free case (see
  Context) but may be neutral-or-worse when `Y` is busy — the measurement decides. Per the decision bar
  a modest/conditional win still justifies implementing.
- Correctness is already fine (the native indirect load is correct; this is purely about avoiding the
  round-trip). No bug, just a possible size/speed nudge.

## Measurement — pass 1: leaf functions (M=1 ambient — later found optimistic)

> ⚠️ These bodies are isolated leaf functions, so the accumulator ambient is 8-bit and the **full**
> `rep`/`sep` is charged to the native load. That is the *best* case for byte-wise. The realistic
> 16-bit-ambient re-measurement is in the next section and changes the conclusion — read both.

**Method.** Built `shapes.c` (four functions below) with the from-source toolchain under `+mos-a16 -Os`;
`-print-after=legalizer` to confirm each load's path; native baseline first, then the byte-wise form via
the throwaway guard (gate the indir branch on `!AllUsesUnmerge`, rebuild `dev/run.sh toolchain`, revert
after). Bytes = linked function size (the `-Os` decision metric). Cycles = 65816 native-mode, DP=0,
whole-function equal/fall-through path, hand-counted — the native-vs-byte-wise **delta** is insensitive
to the DP penalty (both sides use the same DP ops).

```c
uint16_t shape_deref(const uint16_t *p, uint16_t c)              { return *p == c; }         // Y-free
uint16_t shape_idx  (const uint16_t *p, uint8_t i, uint16_t c)   { return p[i & 7] == c; }   // indexed
void     shape_ybusy(const uint16_t *p, uint16_t c, uint8_t *o, uint8_t i){ o[i]=(*p==c); }  // Y-busy
uint16_t shape_value(const uint16_t *p, uint16_t c)              { return *p + c; }           // control
```

**Path confirmation (review pt 1).** All three EQ shapes legalize to `G_LOAD16_INDIR` — including the
pointer-indexed `p[i&7]` (`p` is a *pointer*, not a global array; a global array would be abs-indexed and
is **not** this case). The control `*p + c` (genuine 16-bit use) also starts as `G_LOAD16_INDIR` and
correctly **stays native** under the gate (it is not all-uses-unmerge) — the gate is precise.

**narrowScalar's actual emission (review pt 3).** Better than the plan assumed: it loads the offset-0
byte with the plain 65C02 `lda (zp)` and only the offset-1 byte with `lda (zp),y`/`y=1` — so just **one**
`ldy`, not two. Addressing verified correct against symbolic `-S` (incl. `p[i&7]`, which reuses
`tax`→`txy` to index the low byte off the base while the high byte uses `p+2k` with `y=1`).

| shape | addressing | native B | bytewise B | ΔB | native cyc | bytewise cyc | Δcyc |
|---|---|--:|--:|--:|--:|--:|--:|
| `*p == c` (Y-free) | `*p` | 38 | 32 | **-6 (-16%)** | 55 | 45 | **-10 (-18%)** |
| `p[i&7] == c` | indexed | 45 | 45 | **0** | 77 | 77 | **0** |
| `out[i]=(*p==c)` (Y-busy) | `*p`, Y live | 35 | 29 | **-6 (-17%)** | 58 | 48 | **-10 (-17%)** |
| `*p + c` (control) | 16-bit use | 24 | 24 | 0 (untouched) | — | — | — |

**Native vs byte-wise, the load region (`*p == c`):**

```
; native (today):                       ; byte-wise (narrowScalar):
  rep #$20                                ldy #1
  lda (p)      ; 16-bit indirect load     lda (p),y      ; high byte
  sta imag16   ; spill A16                cmp c_hi
  sep #$20                                bne ne
  ldx imag16   ; read byte                lda (p)        ; low byte (no index)
  cpx c_hi                                cmp c_lo
  ldx imag16 ; cpx c_lo                   bne ne
```

**Mechanism / why the indexed case is a wash.** The cost the win targets is the `rep`/`sep` + `sta
imag16` round-trip the native indirect load forces (it needs M=0; the ambient compare is M=1). For a
plain `*p` there is no pointer arithmetic, so byte-wise eliminates the mode switch entirely → −6 B / −10
cyc. For `p[i&7]` the 16-bit pointer add `p + 2k` **already** needs `rep`/`sep`, so byte-wise can only
drop the spill — and the instructions it removes (`lda (zp)`₁₆ + `sta`₁₆ + two `ldx/cpx` imag reads =
22 cyc / 12 B) exactly equal the ones it adds (`tax` + `ldy #1` + two fused `(zp),y` load-compares =
22 cyc / 12 B). Exact wash, robust to the per-op timing model.

**Y-busy is still a win.** `out[i]=(*p==c)` keeps `Y=i` live for the indexed store. Byte-wise clobbers Y
(needs `y=1`) and must reload `ldy i` before the store (+1 insn) — yet still wins −6 B / −10 cyc, because
one `ldy` reload is far cheaper than the `rep`/`sep` + spill it removes. **The review's worry that the
contended case might be *worse* is refuted by measurement.**

## Measurement — pass 2: 16-bit-ambient code (the realistic regime — 2026-06-16)

`+mos-a16` code is **predominantly 16-bit (M=0)**; it drops to 8-bit only to touch hardware. So the
leaf measurement's ambient was unrepresentative. Re-measured with the EQ-as-value indirect load embedded
in sustained 16-bit arithmetic (`ambient.c`), byte sizes from the section headers:

| context | body | native B | bytewise B | ΔB |
|---|---|--:|--:|--:|
| M=0, load **adjacent** to compare | `loop_deref` (loop-invariant `*p==c`, hoisted) | 100 | 94 | **-6 (win)** |
| M=0, 16-bit math **interleaved** | `mixed_deref` (`eq` combined with `a±b`, shifts) | 87 | 89 | **+2 (LOSS)** |

**The win is schedule-dependent, not universal.** Two facts from the disasm:

1. **Even in M=0 ambient the native load keeps its own `rep`/`sep` island** — the byte unmerge forces a
   16→8 boundary immediately after the load, so its 16-bit region never merges with the surrounding
   16-bit math (`mixed_deref` native: load island `0x4–0xa`, then a *fresh* `rep` at `0xe` for the
   arithmetic). So byte-wise *can* still eliminate that island — **but only when the bytes flow straight
   into the compare** (`loop_deref`: −6 B, matching the leaf case).

2. **When 16-bit work is scheduled between the load and the byte-compare, byte-wise loses.** It must
   carry the loaded value across that region as **two bytes** (two `sta`/`ldx` spill+reload pairs),
   whereas the native 16-bit load spills it **once** as a word (`mixed_deref`: byte-wise does
   `lda (zp); sta; ldy #1; lda (zp),y; sta` = two byte-spills → +2 B). This interleaving is common in
   real 16-bit code, because the point of EQ-as-value is to feed the 0/1 into further arithmetic.

The blanket `AllUsesUnmerge` gate **cannot distinguish** these (scheduling happens after legalization),
so implementing it would help the adjacent case and regress the interleaved one.

## Recommendation: SKIP (document) — not a clean win; the real fix is native 16-bit EQ

Revised from the leaf-only IMPLEMENT. Against the decision bar (*a modest win is fine as long as
byte-wise is not meaningfully worse elsewhere*), byte-wise **fails**: it is a **+2 B regression** in the
interleaved-16-bit case, which is exactly the common shape in the M=0 regime where `+mos-a16` runs. The
−6 B win survives only for an adjacent load→compare (leaf functions, loop-invariant or immediately-used
tests), and the blanket gate can't target just those.

The underlying inefficiency is that EQ-as-value **narrows to an 8-bit compare at all** — that is what
creates the unmerge, the 8-bit island, and the spill-vs-byte-spill dilemma on *both* paths. The proper
fix is **native s16 EQ-as-value** (the deferred `CmpSelImag16`/`CmpSelImm16` work — see the predecessor
plan's "Deferred"), which keeps the value 16-bit end-to-end: one 16-bit load feeding one 16-bit compare,
no byte split, no island — dominating both the native-today and byte-wise forms. **Recommend closing
this follow-up as won't-implement and folding the effort into the native-EQ item.**
