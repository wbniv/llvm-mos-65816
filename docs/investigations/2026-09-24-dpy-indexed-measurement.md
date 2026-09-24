# `[dp],Y` (`b7`/`97`) indirect-long indexed — Phase 1 measurement · **GO**

**Asked:** the [#320 far-addressing completeness audit](2026-09-24-mos24-far-addressing-completeness-audit.md#2-codegen--instruction-selection--done-for-correctness-measured-gaps-in-coverage)
found `[dp],Y` is *never* selected — a far pointer plus a runtime index always materialises a
32‑bit pointer add followed by a plain `lda [dp]`. Per governing lesson 2 ("a native long form is
**not** automatically smaller"), **measure before implementing**: does folding the index into the
addressing mode actually win on real code shape, in bytes *and* cycles?

**Date:** 2026‑09‑24 · **Branch:** `throwaway/dpy-indexed-measure` (worktree
`/home/will/llvm-mos-65816-dpy-indexed-measure`, host‑only hardlink recipe per
[howto-feature-worktree](../howto-feature-worktree.md)) · **Scope:** measure + report.
**No compiler source was changed** — every "current" number is the shipped toolchain's own output,
every "`[dp],Y`" number is hand-written assembly run through `llvm-mc`.

**Visible surface:** none (a codegen measurement). No mockups section.

**Reproduce:** `dev/measure-dpy-indexed.sh` (host-only; fixtures in `dev/dpy-shapes/`).

---

## Verdict — **GO**, with a narrower target than the audit implied

`[dp],Y` wins decisively on every shape measured, and there is **no measured configuration in
which folding the index loses reuse**. But the win is *not* where the audit pointed:

- **`farindex.c` is not a customer for the full fold.** Its indices are deliberately
  `volatile int32_t` reaching byte offsets up to `$2BF20` (179,488) — far past the 16‑bit range
  `[dp],Y` can express. `[dp],Y` adds a **Y‑width** displacement (8‑bit under `X=1`, 16‑bit under
  `+mos-xy16`) to a 24‑bit pointer, carrying into the bank. A >64 KiB runtime offset cannot be
  folded at all.
- **`farindex.c` *is* a customer for the zero-risk sub-case** — multi-byte access off an
  already-built far pointer, where `Y` walks `0,1,2,3`. That needs **no range proof whatsoever**
  and removes a 14‑byte `inc/bne` carry chain per extra byte.
- **The general fold's real customers** are far arrays indexed by a value provably ≤ the Y width:
  `uint8_t`/`uint16_t` indices, loop induction variables, and the very common SNES idiom
  "far ROM table → WRAM at a runtime offset".

Phase 2 (real instruction selection behind a conservative gate) is **separate, re-ranked T4 work
and is NOT part of this dispatch.** Nothing was implemented here.

---

## 1. The audit's open question — does `b7`/`97` fire outside `examples/65816/`?

**Answer: no. Zero genuine selections anywhere.**

The audit's census covered only `examples/65816/*.c`. I censused the **built SNES corpus**:
**487 prebuilt `*.sfc.elf` ROM images** in `build/` — the whole `examples/snes/` demo + corpus
set, linked against the SDK, so SDK library code is in scope too (~1.72 M disassembled
instructions).

Raw first-byte frequency across all 487 ROMs turned up 2× `b7`, 2× `97`, 1× `9f` — **all five are
disassembly desync in the ROM header / crt0 preamble before `<main>`**, not instructions. Each one
sits inside a run where `llvm-objdump` is clearly mid-stream on data:

```
bitweave.sfc.elf      8065: a0 00 84   ldy #$8400        <- desynced
                      8068: 03 a0      ora $a0,s
                      806a: 97 84      sta [$84],y       <- the "hit"
                      806c: 04 a0      tsb $a0
fft_repro.sfc.elf     8068: 71 84      adc ($84),y
                      806c: b7 84      lda [$84],y       <- the "hit", 4 bytes before <main>
```

Filtering to post-`<main>` instructions:

```
==> 1) SNES-corpus census: genuine b7/97/9f selections in prebuilt ROMs
  scanning 487 ROM images
  genuine (post-<main>) b7/97/9f selections: 0
```

**The long-form arithmetic opcodes are the same story.** `ef`=69, `6f`=54, `cf`=43 across the
corpus look like real hits, but every one is inside `svx_decode_payload_wram_asm` — **hand-written
assembly** (`examples/snes/*-fast.s`), not codegen:

```
apollo-reel.sfc.elf   8142: af 02 00 00  lda mos24($2)    <- __rc2, hand-written .s
                      8146: cf 04 00 00  cmp mos24($4)
                      814a: f0 1f        beq …
```

So the audit's gap **holds and widens**: `b7`/`97`/`9f` and the long-form arithmetic are selected
by *nothing the compiler emits*, on micro-fixtures **or** on the real SNES corpus. This does not
change the answer — it removes the caveat that might have.

---

## 2. What codegen emits today

All fixtures compiled with the shipped toolchain
(`build/llvm-mos-install/bin/mos-clang`, `-mcpu=mosw65816 -Os`, `+mos-a16`).
Sources: `dev/dpy-shapes/red.c`, `dev/dpy-shapes/loop.c`.

| fixture | shape | bytes |
|---|---|---|
| `fa` | `out = b[i]` , `uint16_t i` , far `uint8_t[]` | 50 |
| `fb` | `out = b[i]` , `uint8_t i` | 46 |
| `fc` | `out = w[i]` , `uint16_t i` , far `uint16_t[]` | 99 |
| `fd` | 16‑iteration sum over far bytes | 110 |
| `fe` | `out = b[i]` , `uint32_t i` (farindex class) | 61 |
| `blit` | 64‑byte far→WRAM copy at a runtime 16‑bit offset | 86 |

The universal pattern, e.g. `fb` (8‑bit index — the *cheapest* current case):

```
   0: ae 00 00   ldx  k8              ; index
   3: 86 00      stx  __rcA
   5: a9 00      lda  #lo(b)          ;  ── 32-bit pointer add, 4 bytes wide,
   7: 18         clc                  ;     because an AS2 pointer is s32
   8: 65 00      adc  __rcA
   a: 85 00      sta  __rcP+0
   c: a9 00      lda  #hi(b)
   e: 69 00      adc  #0
  10: 85 00      sta  __rcP+1
  12: 64 00      stz  __rcT
  14: a9 00      lda  #bank(b)
  16: 69 00      adc  #0
  18: 85 00      sta  __rcP+2
  1a: a9 00      lda  #0
  1c: 69 00      adc  #0
  1e: 85 00      sta  __rcP+3         ;  ──┘  (the 4th byte is pure padding)
  20: a7 00      lda  [__rcP]         ; the actual load
  22: 85 00      sta  __rcR
```

Two structural observations, both load-bearing below:

1. **The AS2 pointer is 32‑bit**, so the add is a four-byte `adc` chain even though the machine
   only has 24 address bits. One quarter of it is dead work.
2. **`+mos-xy16` changes nothing here.** `blit` is **86 bytes under both** `+mos-a16` and
   `+mos-a16 +mos-xy16` — the index-folding opportunity is not being taken at either XY width.

---

## 3. Measurement A — single access, 8-bit index (`+mos-a16`, `X=1`)

Both sequences hand-written and assembled by `llvm-mc`
(`dev/dpy-shapes/cur8.s`, `dev/dpy-shapes/dpy8.s`). `cur8.s` is a literal transcription of the
compiler's `fb` output above; `dpy8.s` is the same access folded into `b7`.

**Current — `cur8` = 36 bytes, 50 cycles**

```
  0: ae 34 12   ldx $1234      4      a: 85 21   sta $21        3
  3: 86 20      stx $20        3      c: a9 80   lda #$80       2
  5: a9 00      lda #$00       2      e: 69 00   adc #$00       2
  7: 18         clc            2     10: 85 22   sta $22        3
  8: 65 20      adc $20        3     12: 64 20   stz $20        3
                                     14: a9 c1   lda #$c1       2
                                     16: 69 00   adc #$00       2
                                     18: 85 23   sta $23        3
                                     1a: a9 00   lda #$00       2
                                     1c: 69 00   adc #$00       2
                                     1e: 85 24   sta $24        3
                                     20: a7 21   lda [$21]      6
                                     22: 85 25   sta $25        3
```

**Folded — `dpy8` = 19 bytes, 28 cycles**

```
  0: ac 34 12   ldy $1234      4      9: 85 22   sta $22        3
  3: a9 00      lda #$00       2      b: a9 c1   lda #$c1       2
  5: 85 21      sta $21        3      d: 85 23   sta $23        3
  7: a9 80      lda #$80       2      f: b7 21   lda [$21],y    6
                                     11: 85 25   sta $25        3
```

| | bytes | cycles |
|---|---|---|
| current (add + `lda [dp]`) | 36 | 50 |
| folded (`lda [dp],y`) | **19** | **28** |
| **Δ** | **−17 (−47 %)** | **−22 (−44 %)** |

Cycle counts are W65C816S native-mode, `M=1`, `X=1`, `DL=0` (llvm-mos puts DP at `$0000` on SNES,
so no `+1` direct-page penalty). `lda [dp]` and `lda [dp],y` are both **6 cycles** — the indexed
form is *free*; the entire saving is the add chain that disappears.

It also uses **one fewer zero-page byte** (a 3-byte DP pointer instead of a 4-byte AS2 pointer)
and **no `__rc` scratch** for the add — so ZP pressure improves, it does not worsen.

---

## 4. Measurement B — realistic 16-bit-ambient loop (`dev/dpy-shapes/loop.c`)

Per governing lesson 1, measured on a loop in ambient `+mos-a16` context, not an isolated leaf.
The shape is the common SNES idiom — copy a 64-byte run out of a far ROM table into WRAM at a
runtime offset:

```c
void blit(void){
  uint16_t o = base;                                   // volatile
  for (uint8_t j = 0; j < 64; j++) dst[j] = tab[o + j];
}
```

**Current codegen — 86 bytes total, loop body `0x11..0x55` = 68 bytes, ~101 cycles/iteration.**
The whole 32-bit add is **inside** the loop, re-executed 64 times, together with four `rep`/`sep`
mode flips and a `phy`/`ply` pair, to load one byte:

```
  11: c2 20   rep #$20      3     29: a9 00   lda #$00       2     3e: 69 00  adc #$00   2
  13: a5 00   lda __rc      4     2b: a4 00   ldy __rc       3     40: 85 00  sta __rc   3
  15: 18      clc           2     2d: c0 01   cpy #$01       2     42: a9 00  lda #$00   2
  16: e2 20   sep #$20      3     2f: 7a      ply            4     44: 69 00  adc #$00   2
  18: 5a      phy           3     30: 65 00   adc __rc       3     46: 85 00  sta __rc   3
  19: a0 01   ldy #$01      2     32: 85 00   sta __rc       3     48: a7 00  lda [__rc] 6
  1b: b0 02   bcs …         2     34: a5 00   lda __rc       3     4a: 99 …   sta dst,y  5
  1d: a0 00   ldy #$00      2     36: 86 00   stx __rc       3     4d: c8      iny       2
  1f: 84 00   sty __rc      3     38: 65 00   adc __rc       3     4e: c0 40  cpy #$40   2
  21: c2 20   rep #$20      3     3a: 85 00   sta __rc       3     50: f0 03  beq …      2
  23: 65 00   adc __rc      4     3c: a9 00   lda #$00       2     52: 4c …   jmp loop   3
  25: 85 00   sta __rc      4
  27: e2 20   sep #$20      3
```

**Hand-built `[dp],Y` — 32 bytes total, loop body 10 bytes, 18 cycles/iteration**
(`dev/dpy-shapes/blitdpy.s`). `tab + o` is loop-invariant, so it is computed once in the
prologue; `j` lives in `Y`:

```
   0: c2 20      rep #$20            13: a0 00   ldy #$00
   2: ad 34 12   lda base          L:
   5: 18         clc                 15: b7 20   lda [$20],y   6
   6: 69 00 80   adc #lo16(tab)      17: 99 00 05 sta dst,y    5
   9: 85 20      sta $20  (16-bit)   1a: c8      iny           2
   b: e2 20      sep #$20            1b: c0 40   cpy #$40      2
   d: a9 c1      lda #bank(tab)      1d: d0 f6   bne L         3
   f: 69 00      adc #$00            1f: 60      rts
  11: 85 22      sta $22
```

### Isolating the addressing mode from the hoist

Part of that win is loop-invariant-hoisting the add, which is a *different* optimisation. To
measure the addressing mode **on its own**, `dev/dpy-shapes/blithoist.s` is the same hoisted
prologue but keeping plain `lda [dp]` plus the pointer-advance carry chain codegen actually uses:

```
L: 15: a7 20   lda [$20]    6      1e: e6 21   inc $21      5
   17: 99 …    sta dst,y    5      20: d0 02   bne 1f       3
   1a: e6 20   inc $20      5      22: e6 22   inc $22      5
   1c: d0 06   bne 1f       3   1: 24: c8      iny          2   …
```

| variant | total bytes | loop-body bytes | cycles/iter | ×64 iterations |
|---|---|---|---|---|
| current codegen (`blit`, `+mos-a16`) | 86 | 68 | ~101 | ~6,464 |
| add hoisted, **no** index fold (`blithoist`) | 42 | 20 | 26 | 1,664 |
| **`[dp],Y` folded (`blitdpy`)** | **32** | **10** | **18** | **1,152** |

- **Addressing mode alone** (hoist held constant, `blithoist` → `blitdpy`):
  **−50 % loop bytes, −31 % cycles/iteration.**
- **End to end vs what ships today:** **68 → 10 bytes** in the hot loop, **~5.6× fewer cycles.**

---

## 5. The amortisation question — *does folding the index lose reuse of the add?*

This is the exact operand-residency/schedule trap governing lesson 2 warns about, so it was
checked specifically. **Answer: no, in every measured shape.**

1. **The add is not amortised today, at all.** In `blit` the complete 32-bit add sits **inside**
   the 64-iteration loop body (bytes `0x11`–`0x47`), recomputed every iteration. `fd` (the
   16-iteration sum) is the same. There is no LICM, no strength reduction, and therefore **no
   reuse for a fold to destroy.**
2. **Where a pointer genuinely *is* reused, the reuse mechanism is a carry chain that `[dp],Y`
   strictly dominates.** Multi-byte access off one far pointer — `fc`, and `farindex.c` itself —
   keeps the pointer and advances it:

   ```
   farindex.o  5d: e6 00  inc __rc4      fc.o  3b: e8      inx
               5f: d0 0a  bne +                3c: d0 09   bne +
               61: e6 00  inc __rc5            3e: c8      iny
               63: d0 06  bne +                3f: d0 06   bne +
               65: e6 00  inc __rc6            41: e6 00   inc __rc
               67: d0 02  bne +                43: d0 02   bne +
               69: e6 00  inc __rc7            45: e6 00   inc __rc
               ──────────── 14 bytes           47..52: 14 bytes re-homing X/Y into DP
                                               ──────────── 26 bytes
   ```

   Against `iny` — **1 byte, 2 cycles**. `farindex.o` (`-c`, `+mos-a16`) contains 6× `a7` and
   **2 such carry chains totalling 28 bytes**; a third advance is the register-based `inx/iny`
   variant above. Every one of them is replaceable by `iny`, and this sub-case needs **no range
   analysis at all** — `lda [dp],y` with `Y=0` is exactly `lda [dp]`.
3. **Even under a hypothetical perfect LICM**, `[dp],Y` still wins 50 % of loop bytes
   (`blithoist` → `blitdpy`, §4). So the fold is not merely a proxy for a missing hoist.

**The one real loss vector is Y-register residency**, not the add. `[dp],Y` pins the index into
`Y`; if `Y` is already live at the load, the fold costs `phy`/`ply` + `ldy` ≈ **6 bytes / 11
cycles** — still far inside the −17 B / −22 cy it saves in the single-access case, but it is the
axis a conservative gate must respect.

---

## 6. Constraints Phase 2 must gate on (recorded here so they are not rediscovered)

1. **Y's width is governed by `X`, not `M`.** Under `+mos-a16` alone (`X=1`) `Y` is 8-bit, so the
   foldable displacement is `0..255`. A 16-bit index needs `+mos-xy16`. This is precisely why the
   audit's census saw `bf` (`lda long,X`) *only* under `+mos-xy16`.
2. **The gate is on the *scaled* byte offset**, `index × sizeof(elem)`, unsigned, not on the index.
   A far `uint16_t[]` under `+mos-xy16` needs `index < 32768`.
3. **The zero-/small-constant-displacement sub-case (`Y ∈ {0,1,2,3}`) needs no proof** and is the
   highest-confidence, lowest-risk slice: it is a pure replacement of the `inc/bne` carry chain.
   Recommended as Phase 2's first increment.
4. **Require `Y` free or already index-resident at the load**, per §5.
5. **Misclassification must only ever miss a win.** Every constraint above is a *may-fold*
   predicate: failing it falls back to today's add + `lda [dp]`, which is already correct.
6. **`9f` (`sta long,X`) and the long-form arithmetic are a different question** — they need
   their own measurement and are *not* covered by this verdict. §1 establishes only that they are
   unselected; nothing here says whether selecting them wins.
7. **Watch the AsmPrinter gap.** Per the parent audit §6, the printer cannot express a 65816 long
   address in text, so any new long form must be validated on the `-c` path (or via `mos24(...)`)
   — a `-save-temps` round-trip will silently narrow it.

---

## 7. Disposition

- **Phase 1: complete. Verdict GO.** The TODO item moves to `## Done`.
- **Phase 2 is separate follow-up work, re-ranked T4**, gated as §6 describes. It was deliberately
  **not started** in this dispatch even though the numbers are good.
- Durable artifacts merged back to `main`: this document, `dev/measure-dpy-indexed.sh`, and the
  hand-built shapes in `dev/dpy-shapes/`. The worktree is disposable.
