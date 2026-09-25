# `long,X` (`bf`/`9f`) on a far global base — Phase 1 measurement · **GO**

**Asked:** the [#320 far-addressing audit §2](2026-09-24-mos24-far-addressing-completeness-audit.md#2-codegen--instruction-selection--done-for-correctness-measured-gaps-in-coverage)
found that `lda long,X` (`bf`) fires once in the whole fixture corpus and `sta long,X` (`9f`) never.
[`[dp],Y` Phase 1 §6 constraint 6](2026-09-24-dpy-indexed-measurement.md#6-constraints-phase-2-must-gate-on-recorded-here-so-they-are-not-rediscovered)
left both, and the long-form ALU opcodes, **outside** its GO verdict. So the question is: when the base is a
far **global** (`tbl[i]`, with `tbl` at a link-time 24-bit address) plus a runtime index, does
absolute-long indexed addressing win on real code shape, in bytes *and* cycles? Governing lesson 2 says
a native long form is not automatically smaller.

**Date:** 2026‑09‑25 · **Branch:** `throwaway/longx-global-measure` (worktree
`/home/will/llvm-mos-65816-longx-measure`, host-only hardlink recipe per
[howto-feature-worktree](../howto-feature-worktree.md)) · **Scope:** measure and report.
**No compiler source was changed.** Every "current" number is the shipped toolchain's own output, and
every "`long,X`" number is hand-written assembly run through `llvm-mc`.

**Toolchain measured:** `build/llvm-mos-install/bin/clang-23` of the main checkout (hardlinked into the
worktree), sha256 `d06097b58e71b708…`, mtime 2026‑09‑25 07:35 (this includes `[dp],Y` increment 1).

**Visible surface:** none. This is a codegen measurement, so there is no mockups section.

**Reproduce:** `ELFDIR=/home/will/llvm-mos-65816/build dev/measure-longx-global.sh` (host-only). The
fixtures are in `dev/longx-shapes/`, and `dev/longx-shapes/cycles.py` is the static cycle estimator. Its
timing model is in its header: W65C816S native mode, DL=0, page-crossing penalties ignored, one path with
forward branches not taken and the loop back-edge taken. It reproduces the `[dp],Y` doc's
hand-counted `cur8` 50 cy, `dpy8` 28 cy and `blitdpy` 18 cy/iter exactly.

---

## Verdict — **GO** for `bf`/`9f` · **NO-GO** for non-indexed long ALU · indexed `adc long,X` is a small add-on

- **`lda`/`sta long,X` wins on every shape measured, with no losing configuration against today's code.**
  Today a far-global subscript does not use the global's address directly. It materialises a
  **full 32-bit pointer** (`lda #lo / clc / adc idx / … / lda #bank / adc #0 / … / lda #0 / adc #0`) into
  a DP quad and then does `lda [dp]`. This is the same shape as the far-*pointer* case, and `+mos-xy16`
  changes nothing: the output is byte-identical under both modes. `long,X` removes the pointer entirely.
  - Single access, clean isolation (byte element, so no load-width effect): **46 → 21 B (−54 %),
    71 → 36 cy (−49 %)** for a load and **44 → 15 B, 68 → 26 cy** for a store.
  - Loops: **86 → 25 B** (`blit`), **153 → 20 B** (`copyw`), **162 → 20 B** (`fillw`), and
    **168 → 24 B** (`sumw`). Per iteration, **104 → 20 cy** and **179–200 → 15–21 cy**.
- **The index-width trap is real for X, as it was for Y** (§4). Ambient X is **8-bit under both
  `+mos-a16` and `+mos-xy16`**. With an 8-bit X, only a scaled offset of 255 or less folds for free. A
  16-bit index needs `+mos-xy16` plus a local `rep/sep #$10` bracket (+4 B / +6 cy, still far inside the
  win). Under `+mos-a16` alone, a 16-bit index cannot fold at all.
- **Long-form ALU:** the compiler selects none of them. For a far **scalar** operand, `eor/cmp/adc long`
  buys **exactly 0 B / 0 cy** over a 16-bit `lda long` followed by a near op. The real waste there is
  the byte-split load (§5), so this is **NO-GO as its own item**. The **indexed** form `adc long,X` (`7f`)
  is a genuine but second-order win (−4 B body, −8 cy/iter on a running sum). It rides on `bf` and belongs
  inside Phase 2, not in a standalone item.

**Phase 2** (real instruction selection behind a conservative gate) is **separate follow-up work, which
should be ranked T4.** It is **not** part of this dispatch, and nothing was implemented here.

---

## 1. Census — does `bf`/`9f`/long-ALU fire anywhere?

**Answer: zero genuine far-global selections anywhere. The only codegen hit is one `bf` on a *near*
global under a 16-bit X.**

### 1a. `examples/65816/*.c`, re-run in three modes (the audit's corpus)

```
==> 2) examples/65816/*.c census (the #320 audit's corpus)
  default  compiled  93  hits:
  a16      compiled 113  hits:
  xy16     compiled 113  hits:  1 legalindexdom:bf
```

This matches the audit, with 113 fixtures now against 112 then. The one `bf` is in `legalindexdom.c`, and
it indexes `came`, a **near** `uint8_t[240]`, not a far global:

```
  10: c2 30        rep  #$30
  ...
  19: a6 00        ldx  __rc6
  1b: bf 00 00 00  lda  mos24(came),x     ; near global, 16-bit X
  1f: e2 10        sep  #$10
```

So the one `bf` the audit counted is not a far-global subscript. Codegen picked the 4-byte long form
where a 3-byte `lda abs,X` would address the same byte if DBR is the data bank. I did not chase why,
because it is out of scope. It is recorded here only so the census number is not mistaken for evidence
that the far path exists.

### 1b. Built SNES corpus — 493 prebuilt `*.elf`, opcode bytes attributed to the enclosing symbol

The `[dp],Y` census kept only post-`<main>` bytes. That filter also drops real code placed *before*
`main`. Here every byte is kept and attributed to its symbol instead:

```
==> 1) SNES-corpus census: bf/9f/long-ALU opcode bytes in prebuilt ROM images
  scanning 493 ROM images
  total opcode-byte hits: 366
  by opcode:   7 0f 5 1f 4 4f 1 5f 72 6f 3 7f 1 9f 119 bf 55 cf 1 df 93 ef 5 ff
  by enclosing symbol:
        139 svx_decode_payload_asm
        115 svx_decode_payload_wram_asm
         66 svx_decode_payload_wram_key_asm
         30 __copy_zp_data
          5 dpbank_window_b
          5 __copy_data
          4 nmi
          1 __zero_zp_bss
          1 __zero_bss
```

| symbol(s) | hits | what it is |
|---|---|---|
| `svx_decode_payload_*_asm` | 320 | **hand-written assembly** (`examples/snes/snes-video-codec-fast.s`) |
| `dpbank_window_b` | 5 | **inline asm**, emitted as `.byte $af/$cf …` (`examples/snes/dpbank.c:105`) |
| `__copy_zp_data`, `__copy_data`, `__zero_*` | 37 | **disassembly desync.** `llvm-objdump` decodes crt0 with the wrong M/X width (for example `ldx #$a000` and then `ora $a0,s`) |
| `nmi` | 4 | **disassembly desync** inside an inline-asm NMI handler (`sbc $e22d85,x` straddles `sta $2d; sep #$20`) |

**Result: 0 of 366 are compiler selections.** The audit's gap holds on real programs as well as on
micro-fixtures. These ROMs are the build products on disk (dated 2026‑08‑06 … 2026‑09‑25), not a fresh
rebuild. No codegen path emits these opcodes for AS2 globals (§2), so a rebuild cannot change the count.

---

## 2. What codegen emits today for `tbl[i]`

`MOSLegalizerInfo::selectAddressingMode`, `case 32`, tries `tryFarAbsoluteAddressing` (constant or global,
**no index**), then `tryFarIndirectIndexedAddressing` (increment 1: a small constant off a runtime
pointer), and then `tryFarIndirectAddressing`. The near cases (`case 8`/`16`) have
`tryAbsoluteIndexedAddressing` for global plus index. **The far case has no counterpart**, so a far
global plus a runtime index falls through to "build a pointer, `lda [dp]`".

`ga` (`out = tb[i]`, `uint8_t i`, far byte table, the cheapest case): **46 B, 71 cy**. The same bytes
come out under `+mos-a16` and `+mos-a16 +mos-xy16`:

```
   0: ae 00 00   ldx  k8
   3: 86 00      stx  __rcA
   5: a9 00      lda  #lo(tb)       ; ── 32-bit pointer add into a DP quad
   7: 18         clc
   8: 65 00      adc  __rcA
   a: 85 00      sta  __rcP+0
   c: a9 00      lda  #hi(tb)
   e: 69 00      adc  #0
  10: 85 00      sta  __rcP+1
  12: 64 00      stz  __rcT
  14: a9 00      lda  #bank(tb)
  16: 69 00      adc  #0
  18: 85 00      sta  __rcP+2
  1a: a9 00      lda  #0
  1c: 69 00      adc  #0
  1e: 85 00      sta  __rcP+3       ; ──┘ (4th byte is padding)
  20: a7 00      lda  [__rcP]
  22: 85 00      sta  __rcR
  24: c2 20      rep  #$20
  26: a5 00      lda  __rcR
  28: 8d 00 00   sta  out
  2b: e2 20      sep  #$20
  2d: 60         rts
```

**Hand-built `ga_lx`: 21 B, 36 cy.** The epilogue is identical, and only the address arithmetic changed:

```
   0: ae 00 00     ldx  k8
   3: bf 00 00 00  lda  mos24(tb),x      ; 5 cy — the whole address computation
   7: 85 20        sta  $20
   9: 64 21        stz  $21
   b: c2 20        rep  #$20
   d: a5 20        lda  $20
   f: 8d 00 00     sta  out
  12: e2 20        sep  #$20
  14: 60           rts
```

The loop fixtures show a worse version of the same thing. The whole 32-bit add is rebuilt **inside**
every iteration, even when the index is a plain `uint8_t` induction variable.

---

## 3. Measurement — current codegen vs hand-built `long,X`

Fixtures: `dev/longx-shapes/single.c`, `dev/longx-shapes/loop.c` (current) and `dev/longx-shapes/*_lx.s`
(hand-built). `-Os`, `-mcpu=mosw65816`. "Current" is the same under `+mos-a16` and `+mos-a16 +mos-xy16`.

### 3a. Single access

| fixture | shape | X width the fold needs | current B / cy | `long,X` B / cy | Δ B | Δ cy |
|---|---|---|---|---|---|---|
| `ga` | `out = tb[i]`, `uint8_t i`, byte | **8** (free) | 46 / 71 | **21 / 36** | −25 | −35 |
| `gb` | `out = tb[i]`, `uint16_t i`, byte | 16 (`+mos-xy16` bracket) | 50 / 80 | **25 / 43** | −25 | −37 |
| `gc` | `out = tw[i]`, `uint8_t i`, word | 16 (2·i ≤ 510) | 64 / 107 | **20 / 34** ¹ | −44 | −73 |
| `gd` | `out = tw[i]`, `uint16_t i`, word | 16 **and** i < 32768 | 67 / 115 | **17 / 32** ¹ | −50 | −83 |
| `sa` | `wb[i] = v`, `uint8_t i`, byte store (`9f`) | **8** (free) | 44 / 68 | **15 / 26** | −29 | −42 |
| `sb` | `ww[i] = v`, `uint16_t i`, word store (`9f`) | 16 **and** i < 32768 | 69 / 116 | **17 / 32** ¹ | −52 | −84 |

¹ Word elements: the hand-built form also does the access as a single `M=0` 16-bit load or store. Current
codegen does two byte accesses (`lda [dp]` followed by `ldy #1; lda [dp],y`). Part of that Δ is access
width, not addressing mode. **`ga`, `gb` and `sa` are free of this confound:** byte element, same epilogue,
and they show the addressing-mode effect by itself, −25 to −29 B.

### 3b. Loops (realistic 16-bit-ambient, `+mos-a16`)

| fixture | source | current B · body B · cy/iter | `-enable-misched=false` | `long,X` B · body B · cy/iter |
|---|---|---|---|---|
| `blit` | `dst[j] = tab[o + j]`, 64× | 86 · 70 · 104 | 86 · 70 · 104 | **25 · 14 · 20** (`+mos-xy16`) |
| `sumw` | `s += tw[j]`, 32× | 168 · 137 · 199 | 126 · 95 · 147 | **24 · 11 · 17** (`adc long,X`) |
| | | | | 29 · 15 · 25 (`bf` only) |
| `copyw` | `dstw[j] = tw[j]`, 32× | 153 · 134 · 200 | 116 · 97 · 159 | **20 · 13 · 21** |
| `fillw` | `ww[j] = x`, 32×, far store | 162 · 134 · 179 | 111 · 83 · 127 | **20 · 10 · 15** (`sta long,X`) |

`sumw_lx`, the shape Phase 2 is aiming for:

```
   0: c2 20         rep  #$20
   2: a9 00 00      lda  #mos16(0)
   5: a2 00         ldx  #0
L: 7: 18            clc                    2
   8: 7f 00 00 00   adc  mos24(tw),x       6
   c: e8            inx                    2
   d: e8            inx                    2
   e: e0 40         cpx  #$40              2
  10: d0 f5         bne  L                 3   = 17 cy/iter
  12: 8d 00 00      sta  out
  15: e2 20         sep  #$20
  17: 60            rts
```

`blit_lx`, which is legal because the index wraps at 16 bits (see §4):

```
   0: c2 10          rep  #$10
   2: ae 00 00       ldx  base               ; X = o (16-bit)
   5: a0 00 00       ldy  #mos16(0)          ; Y = j
L: 8: bf 00 00 00    lda  mos24(tab),x       5
   c: 99 00 00       sta  dst,y              5
   f: e8             inx                     2   ; wraps at $FFFF exactly like the C `o + j`
  10: c8             iny                     2
  11: c0 40 00       cpy  #mos16($40)        3
  14: d0 f2          bne  L                  3   = 20 cy/iter
  16: e2 10          sep  #$10
  18: 60             rts
```

### 3c. The scheduler cliff: checked, and it does not change the verdict

Per the brief, every current shape was re-measured with `-mllvm -enable-misched=false`. The pre-RA
scheduler carry-pressure cliff (its own `[T4]` item) inflates the current **loop** baselines by
37–51 B (`sumw` 168 → 126, `copyw` 153 → 116, `fillw` 162 → 111). It moves single-access shapes by
2 B or less, and `blit` not at all. **Against the scheduler-free baseline, `long,X` still saves
91–102 B per loop.** The cliff only makes today's code look worse, and it cannot hide a regression here,
because the hand-built shapes have no carry chains for the scheduler to interleave. Phase 2 must still
compare its compiler-produced before and after **with and without** misched, as `[dp],Y` increment 1
did. Otherwise a win on a multi-access shape can show up as a regression.

### 3d. Head-to-head against the sibling `[dp],Y` for a global base

| shape | `long,X` | `[dp],Y` | note |
|---|---|---|---|
| `copyw` (index = IV `j`) | **20 B · 13 · 21 cy** | 31 B · 11 · 22 cy | `long,X` builds no DP pointer. `lda long,X` is 5+m cy against 6+m for `[dp],Y`. |
| `blit` (`tab[o + j]`) | **25 B · 14 · 20 cy** | *not legal* | `blitdpy.s` computes `(tab+o)+j`, which is wrong when `o+j` wraps ([hoist §5.2](2026-09-25-farptr-hoist-measurement.md#5-the-dpy-interaction--flagged)) |

**For a far *global* base, `long,X` dominates `[dp],Y`.** It builds no pointer, uses 3–4 fewer ZP bytes,
and costs one cycle less per access. `[dp],Y` stays the right form for a **runtime** far pointer.
Phase 2 must therefore run its matcher **before** any `[dp],Y` increment-2 matcher on a
`G_GLOBAL_VALUE` base, or increment 2 will take these accesses first and lose ~10 B each.

---

## 4. The X-width constraint, verified independently

1. **Ambient X is 8-bit under both `+mos-a16` and `+mos-a16 +mos-xy16`.** `+mos-xy16` does not make X
   16-bit everywhere. It allows 16-bit index ops inside a local `rep #$10` … `sep #$10` bracket, and
   `legalindexdom`'s xy16 disasm above shows it (`rep #$30 … sep #$10`). The width that bounds the
   `long,X` displacement is **X's**, not M's, exactly as Y's width bounded `[dp],Y`.
2. **8-bit X (both modes, no bracket):** foldable iff the **scaled** byte offset is provably ≤ 255. That
   covers a `uint8_t` (or zero-extended i8) index into a **byte** table from type range alone, with no
   analysis (`ga`, `sa`). A word table with a `uint8_t` index reaches 510, so it needs either a 16-bit X
   or a trip-count proof (the `j < 32` loops reach 62).
3. **16-bit X (`+mos-xy16` only):** the bracket costs **+4 B / +6 cy** per region. Compare `gb_lx` with
   `ga_lx`: +4 B, +7 cy, where the extra cycle is `ldx abs` at X=16. That is small against a −25 B win,
   and one bracket covers a whole loop. The scaled offset must still fit 16 bits: a `uint16_t` index into a
   word table needs **i < 32768** (`gd`, `sb`). Otherwise `asl` drops the carry, whereas the pointer add
   carries it into the bank.
4. **Under `+mos-a16` alone, a 16-bit index cannot fold at all.** The backend never raises X there, so
   `gb`/`gd`/`sb`/`blit` keep today's code. That code is *correct* for them, but it is not cheap.
5. **The index must be unsigned (zero-extended).** X is an unsigned displacement. A sign-extended index
   such as `int8_t i` or `int16_t i` can be negative and cannot be folded without a non-negativity proof.
6. **Wrap semantics come for free where they matter.** `lda long,X` adds X to the 24-bit base *with
   carry into the bank*, which is the same as the pointer add for an object that straddles a bank. For a
   16-bit-wrapping index (`tab[o + j]`), a 16-bit X incremented with `inx` wraps at `$FFFF` exactly as the
   C expression does. That makes `long,X` the **only** cheap legal form for `blit`, as the
   [hoist investigation §4](2026-09-25-farptr-hoist-measurement.md#4-where-the-motivating-shapes-win-actually-is)
   predicted.
7. **The `sep #$10` high-byte hazard.** Narrowing X zeroes X/Y's high bytes. This caused the 2026‑06‑29
   xy16 memmove miscompile. Any 16-bit-X `long,X` must go through the existing `MOSInsertREPSEP` X-width
   machinery, not a hand-placed bracket.

---

## 5. Long-form arithmetic/compare (secondary)

**Census:** there are zero compiler selections of `0f/2f/4f/6f/cf/ef` or of their `,X` forms
`1f/3f/5f/7f/df/ff` in either corpus (§1). The 320 SNES hits are hand-written `.s`.

**Non-indexed, far scalar operand** (`x ^ fg`, `x == fg`, `x + fg`, with `fg` a far `uint16_t`):

| fixture | current | ALU fold (`eor`/`cmp long`) | no fold: 16-bit `lda long` + near op |
|---|---|---|---|
| `xe` (`x ^ fg`) | 31 B / 52 cy | 21 B / 38 cy | **21 B / 38 cy** |
| `xc` (`x == fg`) | 35 B / 45 cy | 24 B / 34 cy | **24 B / 34 cy** |
| `xa` (`x + fg`) | 32 B / 54 cy | not built (same shape as `xe`) | not built |

**The fold is worth exactly nothing.** `lda $20` + `eor long` and `lda long` + `eor $20` cost the same
number of bytes and cycles. The 10–11 B that *is* on the table comes from somewhere else: today a far
16-bit scalar is loaded as **two `M=1` `lda long` bytes, each spilled to DP and reassembled**
(`af … sta; af … sta; rep; lda dp; eor dp`), not as one `M=0` `lda long`. That is a load-width issue in
the far-scalar path, not an ALU-addressing one. **Verdict: NO-GO for the non-indexed long ALU forms as a
standalone item.** Close them. The byte-split far-scalar load is a separate small observation, noted
below as a possible follow-up.

**Indexed, running accumulator** (`adc long,X`, `7f`): in `sumw` the fold keeps the sum in A instead of
spilling it to DP each iteration. That is **29 → 24 B total, 15 → 11 B body, 25 → 17 cy/iter (−32 %)**.
This is a genuine win, but it only exists once `bf` selection does, so it belongs in Phase 2 as a later
increment (an ALU op whose memory operand is a far global plus X). It should not be its own item.

---

## 6. Loss vectors (governing lesson 2), and the gate Phase 2 needs

Nothing measured loses against today's code. Governing lesson 2 is about operand residency and schedule,
so these are the places a blanket fold *could* lose, and the gate has to respect them:

1. **X residency.** The fold pins the index into X. In this backend, X often carries the high byte of an
   `A:X` 16-bit value (the return and argument convention). If X is live at the access, the fold costs
   `phx/plx` (2 B, 7 cy at X=8) or a re-home. That is still far inside the ~25 B saved, but it is the
   axis to gate on: **require X free, or already holding the index.**
2. **Two index registers in one loop.** When the source index and the destination index differ (`blit`),
   `long,X` needs X and Y both incremented, which costs 2 cy/iter more than a single-register walk. It
   still beats every legal alternative.
3. **The 16-bit bracket.** At +4 B / +6 cy it only pays when the fold replaces an add chain, which it
   always does here. A Phase 2 gate should not introduce a bracket just to fold something that is
   already cheap.
4. **Misclassification must only miss a win.** Every condition in §4 (scaled offset ≤ the X width,
   unsigned, i < 32768 for word/X16, X free) is a *may-fold* predicate. Failing any of them falls back to
   today's pointer path, which is already correct.

**Phase 2 sketch (not implemented):** add `tryFarAbsoluteIndexedAddressing` to `case 32` of
`MOSLegalizerInfo::selectAddressingMode`, modelled on the near `tryAbsoluteIndexedAddressing`.
It should match `G_PTR_ADD(G_GLOBAL_VALUE[AS2], zext(idx))` and emit the long,X load/store. It must run
ahead of `tryFarIndirectIndexedAddressing`. The first increment is the no-proof slice: an i8-zext index
into a byte far global, which needs X=8 and no bracket (`ga`/`sa`). The next is the `+mos-xy16` 16-bit
slice. `adc/and/…` long,X comes last. Validate on the `-c` path, per audit §6: the AsmPrinter
long-address text gap means a `-save-temps` round trip will silently narrow `mos24(...)`.

---

## 7. Disposition

- **Phase 1: complete. Verdict GO** for `bf`/`9f` on a far-global base, and **NO-GO** (close) for the
  non-indexed long-form ALU opcodes. Indexed `adc long,X` and the other `,X` ALU forms are folded into
  Phase 2 scope.
- **Phase 2 is separate follow-up work, which should be ranked T4.** It is gated as §4 and §6 describe,
  and it was deliberately **not started** here.
- **Possible small follow-up (unranked):** a far 16-bit **scalar** load is byte-split into two `M=1`
  `lda long`, each spilled to DP (`xe` 31 B → 21 B with one `M=0` `lda long`). It needs its own look at
  why the `s16` AS2 load is not selected natively.
- Durable artifacts merged to `main`: this document, `dev/measure-longx-global.sh`, and the fixtures and
  estimator in `dev/longx-shapes/`. The worktree is disposable.
