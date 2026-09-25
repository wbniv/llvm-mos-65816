# Far 16-bit scalar load/store is byte-split — Phase 1 measurement · **GO (gated)**

**Asked:** [`long,X` Phase 1 §5](2026-09-25-longx-global-measurement.md#5-long-form-arithmeticcompare-secondary)
found that `x ^ fg`, with `fg` a far `uint16_t`, loads `fg` as two `M=1` `lda long` bytes, each spilled to
DP and reassembled, instead of one `M=0` `lda long` (31 B today, 21 B hand-built). This document answers
three questions. **Why** is the access split? **How often** does it happen? **What would a single `M=0`
access win**, in bytes and cycles, in 16-bit-ambient code, under both scheduler modes and both `+mos-a16`
and `+mos-xy16`? It also settles the bank-crossing correctness question that any Phase 2 must respect.

**Date:** 2026‑09‑25 · **Branch:** `throwaway/far-scalar-split-measure` (worktree
`/home/will/llvm-mos-65816-farscalar`, host-only hardlink recipe per
[howto-feature-worktree](../howto-feature-worktree.md)) · **Scope:** measure and report.
**No compiler source was changed.** Every "current" number is the shipped toolchain's own output. Every
"`M=0`" number is either real compiler output (the near analog, §4.1) or a minimal hand edit of the
compiler's own `-S` output, reassembled with `llvm-mc` (§4.2).

**Toolchain measured:** `build/llvm-mos-install/bin/clang-23` of the main checkout (hardlinked into the
worktree), sha256 `d06097b58e71b708…`, mtime 2026‑09‑25 07:35. This is the same binary as the `long,X`
Phase 1, and it includes `[dp],Y` increment 1.

**Visible surface:** none. This is a codegen measurement, so there is no mockups section.

**Reproduce:** `GENDIR=/home/will/llvm-mos-65816/build BANKCROSS=1 dev/measure-far-scalar-split.sh`
(host-only, except for the MAME leg of the bank probe, which runs through `dev/container.sh`). `GENDIR`
points at the generated SNES asset headers. The fixtures, the census analyser, and the hand-built shapes
are in `dev/far-scalar-split/`. Cycles come from the `long,X` estimator `dev/longx-shapes/cycles.py`,
whose model is in its header. The script reproduces every number below.

---

## Verdict — **GO for a gated Phase 2** (rank T4), with a bank-crossing *non*-constraint and three gate conditions

- **Root cause (§1):** `MOSLegalizerInfo::legalizeLoadStore16` only offers its native 16-bit arms
  (`G_LOAD16_ABS`/`_INDIR`/indexed) when the pointer is 16 bits wide. A far (`p2`, 32-bit) pointer falls
  through to `Helper.narrowScalar(MI, 0, s8)`, and each byte then becomes a separate `G_LOAD_FAR_ABS` /
  `G_LOAD_FAR_INDIR[_IDX]` (`M=1` `lda long` / `lda [dp]`). **No far 16-bit load/store pseudo exists at
  all:** `LDAbsLong` / `LDIndirLong` define an 8-bit `Ac` only. The cause is not a legalizer mis-narrowing,
  and it is not the `p2↔s32` bridge. The native far arm and its selection target were simply never built.
- **Win, where the value has a 16-bit consumer (§4):** it is large, and the same under both scheduler
  modes and both `+mos-a16`/`+mos-xy16` (byte-identical output), with one exception noted below.
  - Far **global** scalar: **−10 B** (`xe`), **−26 B / −34 cy** (`tick`, RMW; −30 B with an `adc long`
    fold), and **−14 B with −20 cy/iter (−33 %)** in a loop that re-reads it (`mixv`).
  - Runtime far **pointer** walk: **−14 B, −28 cy/iter (−25 %)** (`sump`, both scheduler modes). The
    corpus idiom, a far-source VRAM word upload (`vramup`), gives **−8 B, −15 cy/iter (−20 %)**.
  - The exception is `vramup` with `-enable-misched=false`. There the scheduler puts the 8-bit pointer
    update between the load and its consumer, and the strict edit wins only **0 B / −1 cy**. Sinking that
    copy recovers −8 B / −15 cy.
- **Loss vectors (governing lesson 2, §4.3):** ungated, the change **regresses**.
  - A value that is returned in `A:X` (`ldr`) loses **+3 B**.
  - A store of an `A:X`-resident value (`str`) loses **+5 B**.
  - A store of a byte-resident value (`fillp`) is **neutral** (0 B / −1 cy).
  - The gate must therefore keep today's byte path in three cases: every use is a `G_UNMERGE` (the
    existing `AllUsesUnmerge` rule, which already covers `ldr`); a store's value is not produced by a
    native 16-bit op; and a far operand must never reach a form with no long encoding (§5).
- **Bank crossing (§6): not a constraint.** On **bsnes-jg and MAME**, a single `M=0` `lda`/`sta long`,
  `lda [dp]`, or `lda`/`sta [dp],y` at `$7EFFFF` **carries its second byte into `$7F0000`**. That is
  exactly what today's byte split does, because the linker computes its `fg+1` as a 24-bit sum. The
  bsnes-jg source (`readLong(V.d + I.w + 1)`, masked to 24 bits) agrees. Phase 2 may use one `M=0` access
  at any address, including `$xxFFFF`.
- **Frequency (§3): low today.**
  - **0** far-global 16-bit accesses in the compiled corpus. The only ones are in this item's own fixture.
  - **11 `i16` loads + 2 `i16` stores**, all through runtime far pointers, in 5 of 426 translation units
    (`lzss-gallery` 8, `farindex` 3, `dblbridge` 1, `mandel-double` 1).
  - **3 of these load sites have a 16-bit consumer and would win.** All three are the same VRAM upload
    idiom: `dblbridge` `_title_reserve`, and `lzss-gallery` `main` and `vram_words_far`. The rest are
    byte-consumed and neutral.
  - Per governing lesson 3 this is a **scheduling input, not a veto**. The win per site is large, and a
    far `uint16_t` in `$7E/$7F` WRAM is the natural way to write SNES state that does not fit bank 0.
- **Sequencing recommendation:** Phase 2 needs a family of `Ac16` long pseudos (`LDA/STA long`,
  `[dp]`, `[dp],y`). [`long,X` Phase 2](2026-09-25-longx-global-measurement.md#6-loss-vectors-governing-lesson-2-and-the-gate-phase-2-needs)
  needs the same family for its word-element slice (`lda long,X` under `M=0`). Build them once, together
  or back to back.

---

## 1. Root cause — where the 16-bit far load is split

**MIR, `+mos-a16`, `xe`** (step 1 of the script, `-print-after=irtranslator,legalizer`):

```
# After IRTranslator
  %3:_(s16) = G_LOAD %4:_(p2) :: (dereferenceable invariant load (s16) from @fg, align 1, addrspace 2)
# After Legalizer
  %8:_(s8)  = G_LOAD_FAR_ABS @fg     :: (... load (s8) from @fg, addrspace 2)
  %11:_(s8) = G_LOAD_FAR_ABS @fg + 1 :: (... load (s8) from @fg + 1, addrspace 2)
  %3:_(s16) = G_MERGE_VALUES %8:_(s8), %11:_(s8)
```

The split is complete by the end of the **Legalizer**. RegBankSelect and InstructionSelect only lower
what they are given: two `LDAbsLong` → `REG_SEQUENCE` → `LDAImag16`. That is the
`af; sta rc4; af; sta rc5; rep; lda rc4` in the output.

**The code path** (`vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp`; line numbers are as read
on 2026‑09‑25, so grep the quoted anchors, since `vendor/` is multi-agent):

1. `legalizeLoad` sends every `s16` `G_LOAD` to `legalizeLoadStore16` (anchor
   `return legalizeLoadStore16(Helper, MRI, MI);`, :2256). The store side does the same (:2347).
2. `legalizeLoadStore16` (:2173) builds its three native arms (`G_LOAD16_ABS`, the indexed
   `tryIndexedAddressing16`, and `G_LOAD16_INDIR`) only under
   **`if (STI.hasAccum16() && MRI.getType(Ptr).getScalarSizeInBits() == 16)`** (:2204). A `p2` pointer is
   32 bits wide, so it skips all three.
3. It lands on **`// zp-pointer / far / non-a16: fall back to the 8-bit byte-pair lowering.`** (:2240):
   `Helper.narrowScalar(MI, 0, LLT::scalar(8))`. The comment names "far" explicitly. The byte split is the
   intended fallback, not an accident.
4. Each resulting `s8` `G_LOAD` re-enters `legalizeLoad` → `selectAddressingMode` → `case 32`
   (:2547) → `tryFarAbsoluteAddressing` (a global or constant becomes `G_LOAD_FAR_ABS`),
   `tryFarIndirectIndexedAddressing` (`+1` becomes `[dp],y`), or `tryFarIndirectAddressing`
   (`[dp]`).
5. **There is no 16-bit selection target.** `LDAbsLong` (`MOSInstrLogical.td:591`) is
   `(outs Ac:$dst)` → `LDA_AbsoluteLong addr24`, which is 8-bit only. `LDIndirLong`, `LDIndirLongIdx`
   and the store forms are the same. The 16-bit near pseudo `LDAbs16` (:677) is
   `LDA_Absolute addr16`, a **DBR-relative** 16-bit operand (§5).

So the three hypotheses in the brief resolve as follows:

- **Not** legalizer narrowing of a legal form.
- **Yes:** "an a16 far-load rule missing." Specifically, the `p2` arm of `legalizeLoadStore16` and
  `Ac16` long pseudos to select it into are both missing.
- **Not** the `p2↔s32` bridge. The `G_LOAD`'s own `s16` result is split, and no `p2` value is unmerged.

**Every** far 16-bit access takes this path. Step 3 of the script shows abs-long loads and stores and
`[dp]`/`[dp],y` loads and stores all byte-split.

## 2. Is the `M=0` far form a new codegen shape? No — the near path already emits its exact bytes

With an `extern` near `uint16_t`, the native `s16` pipeline selects `LDAbs16` (`lda abs`). The MC layer
then **relaxes** it to `lda long` (`af …`, `R_MOS_ADDR24`), because the symbol's section is unknown
(`MOSAsmBackend.cpp`, anchor `BankRelax && !Sec->getName().starts_with(".far")`, :191; an unresolved
fragment returns "relax" earlier). The ALU fold `ADCAbs16` → `adc long` (`6f`) and the store `STAbs16` →
`sta long` (`8f`) behave the same way. **The near-extern analog of a far-global shape is therefore
byte-for-byte what an explicit `M=0` far form would emit.** The relocation type and length match; only the
symbol differs. §4.1 uses it as the `M=0` target, so those numbers are real compiler output, not
hand-built.

This is only a measurement shortcut. Phase 2 must **not** implement it by reusing `LDAbs16` plus MC
relaxation. A far symbol defined in a non-`.far*` section, or a constant far address, would stay
`lda abs`, which reads the wrong bank (§5).

## 3. Census — how often it happens

**(a) Exact, from optimized IR** (every `load`/`store` through `ptr addrspace(2)`, all 426 translation
units: `examples/snes/*.c`, `examples/snes/corpus/*.c`, `examples/65816/**/*.c`; `+mos-a16`, `-Oz`/`-Os`):

| access | global base | runtime far pointer |
|---|---:|---:|
| `load i16` | **0** | **11** |
| `store i16` | **0** | **2** |
| `load i32` | 0 | 2 (`farbank`) |
| `load i8` / `store i8` | 3 / 4 | 102 / 25 |

The `i16` accesses by unit: `lzss-gallery` 6 loads + 2 stores, `farindex` 3, `dblbridge` 1,
`mandel-double` 1.

**(b) Shape, in the compiled objects** (`dev/far-scalar-split/census.py`, which finds byte-split pairs
`af A`…`af A+1` and `a7 d`…`b7 d` / `87 d`…`97 d`). The result is **16 sites under `+mos-a16`, identical
under `+mos-xy16`**, all `[dp]`/`[dp],y`. The pair set also contains struct and `i32` byte copies, which
is why it holds 4 store pairs against 2 `i16` stores. Each load site was read by hand, and the
analyser's automatic `reg` tag was corrected where a `phy/ldy/sty` shuffle hid a 16-bit consumer:

| site | consumer of the 2 bytes | `M=0` outcome |
|---|---|---|
| `dblbridge` `_title_reserve` | `rep; lda rc; sta $2118` (VRAM word) | **win** (the `vramup` shape) |
| `lzss-gallery` `main` (1 of 2) | `rep; lda rc; sta $2118` | **win** |
| `lzss-gallery` `vram_words_far` | shuffle, then `rep; lda rc; sta $2118` | **win** |
| `lzss-gallery` `compress_far` (ld) | byte-copied to `(zp)`/`(zp),y`, or stored byte-swapped | neutral |
| `lzss-gallery` `main` (2 of 2), `mandel-double` `main` | high byte used alone (shift) | neutral / loss |
| `farindex` ×3, `farbank` ×2 | folded into `s32` math byte-wise | neutral |
| stores: `lzss-gallery` `compress_far` ×3, `lsystem` `main` | byte-resident value | neutral (the `fillp` result) |

**Prebuilt ROM images** (`build/*.elf`, 494 files, LTO-linked): the analyser finds 22 pairs, all in the
hand-written `svx_decode_payload_asm` and none compiler-emitted. Those images predate the current
toolchain in many cases (some predate `[dp],Y` inc 1), so (a) and (b) above, which were recompiled with
the measured toolchain, are the authoritative census.

## 4. What it costs / what the fix wins

All numbers use `-Os`. "`+mos-xy16`" output is **byte-identical** to `+mos-a16` in every row, current and
`M=0`. Only cycles differ, through the `--x16` X-width model, and they are shown as `a16 (xy16)`. The
fixtures are `dev/far-scalar-split/shapes.c`, `m0/*.s` and `hazard.c`.

### 4.1 Far **global** scalar (`M=0` target = the near-extern analog, real compiler output)

`-enable-misched=false` changes **none** of these rows, current or `M=0`.

| shape | what it is | current | `M=0` | Δ |
|---|---|---|---|---|
| `xe` | leaf, `x ^ fg`, `A:X` in and out | 31 B / 52 (54) cy | 21 B / 38 (40) cy | **−10 B, −14 cy** |
| `tick` | `fc = fc + fg`, far WRAM RMW | 48 B / 74 cy | 22 B / 40 cy (no fold, hand-built) · 18 B / 32 cy (with `adc long`) | **−26 B, −34 cy** (−30 B, −42 cy with fold) |
| `mixv` | loop, volatile far scalar re-read per iteration | 41 B, body 38 B / 60 (62) cy/iter | 27 B, body 24 B / 40 (42) cy/iter | **−14 B, −20 cy/iter (−33 %)** |
| `mixh` | loop, far scalar hoisted, used twice per iteration | 45 B, body 21 B / 36 (38) cy/iter | 37 B, body 21 B / 36 (38) cy/iter | −8 B once, 0 per iteration |

### 4.2 Runtime far **pointer** (`M=0` = the compiler's own `-S`, with **only** the split access replaced)

The edit replaces `lda [d]; sta rc; lda [d],y; sta rc'; rep; lda rc` with `rep; lda [d]`. The dead
`ldy #1` and `phy/ply` are **left in**, so every `M=0` figure here is a lower bound on the win. The
reassembled unedited `-S` reproduces the compiled bytes and cycles exactly in every row, which checks the
round trip.

| shape | scheduler | current | `M=0` | Δ |
|---|---|---|---|---|
| `sump` (`s += *p++`) | default | 89 B, body 67 B / 113 (121) cy/iter | 75 B, body 53 B / 85 (89) cy/iter | **−14 B, −28 (−32) cy/iter (−25 %)** |
| `sump` | `-enable-misched=false` | 112 B, body 74 B / 122 (135) | 98 B, body 60 B / 94 (103) | **−14 B, −28 (−32) cy/iter** |
| `vramup` (`VMDATA = *p++`) | default | 53 B, body 46 B / 74 (74) | 45 B, body 38 B / 59 (59) | **−8 B, −15 cy/iter (−20 %)** |
| `vramup` | `-enable-misched=false`, strict order | 89 B, body 67 B / 107 (115) | 89 B, body 67 B / 106 (114) | **0 B, −1 cy** |
| `vramup` | `-enable-misched=false`, pointer copy sunk below the store | — | 81 B, body 59 B / 92 (100) | −8 B, −15 cy/iter |
| `fillp` (`*p++ = v`, store) | both (identical) | 89 B, body 53 B / 87 (95) | 89 B, body 53 B / 86 (94) | 0 B, −1 cy |

**The scheduler cliff shows up here.** `-enable-misched=false` *worsens* today's code (`sump` +23 B,
`vramup` +36 B), so it cannot manufacture the `M=0` win. But it can *hide* the win. In `vramup` the
non-misched order puts the 8-bit pointer copy between the load and its 16-bit consumer. A literal `M=0`
load then spills to DP across a `sep` region and gains nothing. The win depends on the load sitting next
to its consumer. That adjacency is a schedule property, and Phase 2 should measure it in both modes, as
here.

### 4.3 Loss vectors (governing lesson 2) — what an ungated rule would do

| shape | today (byte path) | ungated `M=0` | Δ | what keeps the byte path |
|---|---|---|---|---|
| `ldr`: `return fg` (`A:X`) | 12 B / 22 cy (`af; tay; af; tax; tya`) | 15 B / 28 (29) cy (`rep; af; sta; sep; ldx; lda`) | **+3 B** | existing `AllUsesUnmerge` gate (the near analog stays byte-wise: `af; ldx abs`) |
| `str`: `fs = v` (`A:X`) | 10 B / 18 cy (`8f; txa; 8f`) | 15 B / 28 (29) cy (near rule "stores always native") | **+5 B** | **none today:** a new store gate is needed |
| `fillp`: store of a byte-resident value | 89 B / 87 cy per iteration | 89 B / 86 cy | 0 | — (neutral) |

**Side finding, which belongs to the near path and not to this item.** The same "stores always take the
native form" rule (`legalizeLoadStore16`, anchor `Stores always take the native form`, :2195) makes a
plain **near setter** `void set(uint16_t v){ g = v; }` cost **14 B / 27 cy under `+mos-a16`**, against
**7 B / 14 cy** by default (`sta abs; stx abs`). That is a live lesson-2 regression on one of the most
common C shapes. It is filed separately in TODO.

## 5. Constraints a Phase 2 must gate on (recorded so they are not rediscovered)

1. **Emit explicit long forms, and never rely on MC bank relaxation.** New `Ac16` pseudos are needed:
   `LDA`/`STA_AbsoluteLong` (`af`/`8f`), `LDA`/`STA_DirectPageIndirectLong` (`a7`/`87`), and the `,y`
   forms (`b7`/`97`), each marked `M16` in `MOSInsertREPSEP`. Reusing `LDAbs16` (`addr16`) is correct
   only when relaxation happens to fire. That is never the case for a constant far address, and it is
   not the case for a far object in a non-`.far*` section.
2. **A far operand must never reach a form with no long encoding.** From the near analog (step 5 of the
   script, `hazard.c`), the native `s16` path emits these with a 16-bit (`R_MOS_ADDR16`, DBR-relative)
   operand:
   - `stz abs` (`9c`), from the zero-store fusion;
   - `ldx`/`ldy abs` (`ae`/`ac`), including the `+mos-xy16` B1 `Xc16` constraint → `LDXAbs16`;
   - `stx abs` (`8e`).

   The 65816 has **no long form** of any of these, nor of `inc`/`dec`/`asl`/`lsr`/`rol`/`ror`/`tsb`/`trb`
   or `cpx`/`cpy`/`bit`. A `p2` load or store must skip the B1 constraint, the STZ fusion, and every
   RMW or X/Y fold.
3. **Gate loads:** keep `AllUsesUnmerge` → byte path (`ldr`, +3 B otherwise).
4. **Gate stores:** go native only when the stored value is produced by a native 16-bit op, meaning
   `Ac16`/`Imag16`-resident. Do not go native when it arrives in `A:X` (`str`, +5 B) or as bytes
   (`fillp`, 0 B). Near's "always native" rule is the wrong model (§4.3).
5. **ALU folds are an optional later increment.** `eor`/`cmp long` buy 0 B in `xe`
   ([`long,X` §5](2026-09-25-longx-global-measurement.md#5-long-form-arithmeticcompare-secondary)), but
   `adc long` buys 4 B in `tick` (22 → 18 B). They need `ADC/…AbsLong16` pseudos, and they must keep the
   `noStoreBetween` + single-use clamp of the near fold helpers.
6. **No bank-crossing special case** (§6).
7. **Validate on the `-c` path.** The AsmPrinter long-address text gap (audit §6) means a `-save-temps`
   round trip can silently narrow `mos24(...)`.

## 6. Bank crossing — does one `M=0` access at `$xxFFFF` wrap like two byte accesses? **Yes, identically.**

**Today's byte split.** The second byte's address is `fg+1` (`R_MOS_ADDR24`, computed by the linker as a
24-bit sum) or `ptr + Y` (`[dp],y`, a 24-bit add). Either way it **carries into the next bank**.

**The probe.** `dev/far-scalar-split/bankcross.{c,sh}` is hand-written 65816 in inline asm, run on both
emulators. It seeds the WRAM bank seam with `$7EFFFE=$EE`, `$7EFFFF=$A5`, `$7F0000=$5A`, `$7E0000=$C3`. A
carry reads the high byte `$5A`; a within-bank wrap would read `$C3`. It sets `D=$1F00` and saves/restores
`$7E0000`, so the compiler's DP registers are untouched.

| access (`M=0`) | carry expectation | bsnes-jg | MAME |
|---|---|---|---|
| R1 `lda $7EFFFF` (`af`) | `$5AA5` | `$5AA5` | `$5AA5` |
| R3 `lda [dp]`, ptr `$7EFFFF` (`a7`) | `$5AA5` | `$5AA5` | `$5AA5` |
| R4 `lda [dp],y`, ptr `$7EFFFE`, Y=1 (`b7`) | `$5AA5` | `$5AA5` | `$5AA5` |
| R5 `sta $7EFFFF` ← `$1234`: (`$7F0000`, `$7E0000`) | `($12, $C3)` | `($12, $C3)` | `($12, $C3)` |
| R7 `sta [dp],y` ← `$6789` (ptr `$7EFFFE`, Y=1) | `($67, $C3)` | `($67, $C3)` | `($67, $C3)` |
| R2 today's byte split (`M=1` `af $7EFFFF` + `af $7F0000`) | `$5AA5` | `$5AA5` | `$5AA5` |

Raw results: `res_a=0x5AA55AA5 res_b=0xC3125AA5 res_c=0x5AA5C367`, identical on both emulators (the
`SMOKE: PASS` lines are in the step 6 output).

**Source cross-check.** bsnes-jg `WDC65816::LongRead16` and `IndirectLongRead16` fetch the high byte with
`readLong(V.d + I.w + 1)`, and `readLong` masks with `& 0xffffff`. `LongWrite16` and
`IndirectLongWrite16` do the same through `writeLong`. The top of memory therefore wraps
`$FFFFFF` → `$000000`. The `R_MOS_ADDR24` truncation of `fg+1` does the same.

**The byte order matches too.** Both forms touch the low byte first, then the high byte, so volatile
access order is unchanged.

**Conclusion:** a single `M=0` access is semantically identical to today's byte pair at every address.
Phase 2 carries **no bank-seam constraint**, and no alignment or "not at `$xxFFFF`" gate is needed.

## 7. Disposition

- **Phase 1: complete. Verdict GO** for a gated Phase 2 (native `M=0` far 16-bit load/store). The gate
  and constraints are in §5.
- **Phase 2 is separate follow-up work, suggested rank T4.** It is cross-cutting: a new legalizer arm,
  new `Ac16` long pseudos, selector changes, `MOSInsertREPSEP` classification, and the exclusions in
  §5.2 and §5.4. Share the pseudo family with [`long,X` Phase 2](2026-09-25-longx-global-measurement.md).
  Nothing was implemented here.
- **Separate near-path finding (§4.3):** under `+mos-a16`, a near setter `g = v` costs 14 B against
  7 B. This is filed as its own TODO item.
- **Durable artifacts merged to `main`:** this document, `dev/measure-far-scalar-split.sh`, and
  `dev/far-scalar-split/`, which holds the fixtures, the census and relocation analysers, the hand-built
  `m0/*.s`, and the bank-seam probe. The worktree is disposable.
