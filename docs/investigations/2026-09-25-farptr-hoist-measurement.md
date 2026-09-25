# Far-pointer add "never hoisted" out of a loop — why, and is a hoist worth it · **NO‑GO**

**Asked:** [`[dp],Y` Phase 1 §4](2026-09-24-dpy-indexed-measurement.md#4-measurement-b--realistic-16-bit-ambient-loop-devdpy-shapesloopc)
hand-built the 64-iteration far-ROM → WRAM blit (`dev/dpy-shapes/loop.c`) with the 32‑bit pointer
add hoisted (`blithoist.s`, 86 → 42 B) and then with `[dp],Y` on top (`blitdpy.s`, 32 B). The TODO
asked: (1) *why* does the compiler not hoist the add — IR LICM, `MachineLICM`, or address-mode
selection re-materialising it? (2) what is the hoist actually worth, with and without
`-enable-misched=false`?

**Date:** 2026‑09‑25 · **Branch:** `throwaway/farptr-hoist-measure` (worktree
`/home/will/llvm-mos-65816-hoist-measure`, host-only) · **Scope:** trace + measure. **No compiler
source changed, no experimental patch.** All "current" numbers come from the shipped toolchain,
snapshotted before measuring, because another agent was rebuilding `vendor/` concurrently:

| binary | host path it was copied from | sha256 |
|---|---|---|
| `clang-23` | `build/llvm-mos-install/bin/clang-23` (mtime 2026‑09‑25 07:35, contains `[dp],Y` increment 1 `2689b74d`) | `d06097b5…58ef70` |
| `llc` | `build/llvm-mos/bin/llc` | `43caf097…f09860` |

**Visible surface:** none (a codegen measurement). No mockups section.

---

## Verdict

1. **Why it isn't hoisted — for `loop.c`, hoisting is not legal.** `tab[o + j]` with `uint16_t o`
   and `uint8_t j` computes `o + j` in **16‑bit `unsigned int`** (MOS `int` is 16 bits). The IR is
   `add i16 %o, %j` **without `nuw`**, followed by `zext i16 → i32`. The address is
   `tab + zext16((o + j) mod 2¹⁶)`, not `(tab + o) + j`. They differ whenever `o + j ≥ 0x10000`,
   i.e. `o ≥ 0xFFC1`. Example: `o = 0xFFF0`, `j = 0x10`. C reads `tab[0x0000]`. Phase 1's
   `blithoist.s` and `blitdpy.s` both read `tab + 0x10000`, one bank higher. **Phase 1's 42‑B and
   32‑B shapes are not equivalent to `loop.c`.** No LICM pass is refusing a legal hoist: nothing
   in that loop is loop-invariant except `tab` and `o`, and both are already outside the loop.
2. **When the source makes the hoist legal, it already happens, at IR level.** With
   `tab[(uint32_t)o + j]`, an explicit `p = tab + base; … p[j]`, or a `*p++` walk, the 32‑bit
   `tab + o` sits in the **preheader** in the `-Os` IR. It is computed once in the prologue of the
   emitted code: 3 of 4 variants, 72 B. IR LICM works, and `MachineLICM` has nothing left to hoist.
   What stays in the loop is the **addressing add `p + zext(j)`** (26 B, ~37 cycles/iteration).
   That add depends on the IV `j`, so no LICM pass could move it. The only ways to remove it are
   strength reduction to a pointer IV, or folding it into `[dp],Y`.
3. **Loop Strength Reduction actively undoes strength reduction for far pointers, on purpose.**
   Given a hand-written `*p++` walk, LSR rewrites the 32‑bit pointer IV back to `p + zext(j)`,
   sharing the `i8` IV. It does this because `MOSTargetLowering::isLegalAddressingMode`
   (`MOSISelLowering.cpp`) is **blind to address space**: "base register + 8‑bit index register"
   is reported as a free "indirect indexed" mode. That is true for near `(zp),Y`. For
   `addrspace(2)` it is true only if ISel folds a *register* index into `[dp],Y` — and that is
   precisely `[dp],Y` **increment 2**, which has not landed. (Increment 1 folds constant
   displacements 1..3 only.) This is the third hypothesis in the TODO, made precise: the address
   is not *re-materialised*. It is a per-iteration address computation, and LSR keeps it that way
   because the target tells it the computation is free.
4. **Is a hoist or strength-reduction Phase 2 worth doing? NO‑GO.** It is both unsafe on the motivating
   shape and dominated on the safe shapes:
   - On today's compiler the pointer-IV form **loses**. `-mllvm -disable-lsr` keeps the `*p++` walk,
     and it comes out at **92 B vs 72 B** (+20 B). The pointer's four DP bytes are shuffled
     twice per iteration, because the pre- and post-increment pointer are both live (a phi-copy /
     coalescing problem). That is nowhere near the hand-built 42 B.
   - On the legal shapes, `[dp],Y` increment 2 captures the **whole** win (`blitdpy`, 32 B,
     ~18 cyc/iter) straight from the IR shape that LSR already produces, `p + zext i8 j`. The range
     proof is trivial there, because an `i8` index always fits the 8‑bit `Y`.
   - A pointer-IV "hoist" would **destroy** that `[dp],Y` opportunity. See [§5](#5-the-dpy-interaction--flagged).
5. **`farindex.c` has no loop** around its far accesses: three straight-line volatile `int32_t`
   subscripts, plus a `wai` spin with no memory access. The hoist win is **0 B by construction**.
   Its with/without-misched delta (422 vs 342 B) is entirely the known pre-RA scheduler cliff.

The win Phase 1 attributed to "hoisting" belongs to two items that are **already tracked**:
`[dp],Y` increment 2 for the legal `p[j]` shapes, and `long,X` (`bf`) under `+mos-xy16` for the
wrapping `tab[o + j]` shape (§4). **No new Phase 2 item is warranted.** The two flags below go to
those two items instead.

---

## 1. Pipeline trace — where the add lives at each stage

Codegen pipeline (`-mllvm -debug-pass=Structure`, relevant passes in order): `loop-reduce` →
`codegenprepare` → `irtranslator` → `legalizer` → `instruction-select` → `early-machinelicm` →
`machine-cse` → `machine-sink` → `machine-scheduler` → `greedy` → `machinelicm` (post-RA). IR LICM
has already run in the middle-end `-Os` pipeline.

The four source variants (inlined here as the reproducer, `vars.c`):

```c
#include <stdint.h>
#define FAR __attribute__((address_space(2)))
extern const FAR uint8_t tab[];
volatile uint16_t base;
uint8_t dst[64];
/* V1 = dev/dpy-shapes/loop.c verbatim: 16-bit wrapping offset o+j */
void v1_wrap16(void){ uint16_t o = base; for (uint8_t j = 0; j < 64; j++) dst[j] = tab[o + j]; }
/* V2: offset widened before the add -> no 16-bit wrap, tab+o is invariant */
void v2_wide(void){ uint16_t o = base; for (uint8_t j = 0; j < 64; j++) dst[j] = tab[(uint32_t)o + j]; }
/* V3: explicit invariant far pointer, indexed */
void v3_ptr(void){ const FAR uint8_t *p = tab + base; for (uint8_t j = 0; j < 64; j++) dst[j] = p[j]; }
/* V4: explicit pointer walk (what a strength-reduced loop would be) */
void v4_walk(void){ const FAR uint8_t *p = tab + base; for (uint8_t j = 0; j < 64; j++) dst[j] = *p++; }
```

**Middle-end IR (`-Os -S -emit-llvm`), loop bodies.** V1: the address is inherently per-iteration.

```llvm
  %5 = zext nneg i8 %4 to i16
  %6 = add i16 %1, %5                  ; o + j, 16-bit, NO nuw -> may wrap
  %7 = zext i16 %6 to i32
  %8 = getelementptr inbounds nuw i8, ptr addrspace(2) @tab, i32 %7
```

V2 and V3 produce identical IR: `tab + zext(o)` is **already in the preheader**, so IR LICM and
reassociation did their job.

```llvm
; preheader
  %2 = zext i16 %1 to i32
  %3 = getelementptr inbounds nuw i8, ptr addrspace(2) @tab, i32 %2
; loop
  %7 = zext nneg i8 %6 to i32
  %8 = getelementptr inbounds nuw i8, ptr addrspace(2) %3, i32 %7   ; p + j, per-iteration
```

**LSR on V4** (`-print-before/after=loop-reduce -filter-print-funcs=v4_walk`) turns the pointer IV
back into base + index:

```llvm
*** IR Dump Before Loop Strength Reduction (loop-reduce) ***
  %6 = phi i8 [ 0, %0 ], [ %12, %5 ]
  %7 = phi ptr addrspace(2) [ %3, %0 ], [ %8, %5 ]
  %8 = getelementptr inbounds nuw i8, ptr addrspace(2) %7, i32 1
*** IR Dump After Loop Strength Reduction (loop-reduce) ***
  %6 = phi i8 [ 0, %0 ], [ %12, %5 ]
  %7 = zext nneg i8 %6 to i32
  %8 = getelementptr i8, ptr addrspace(2) %3, i32 %7
```

The reason is in `MOSTargetLowering::isLegalAddressingMode`. Only `AS_ZeroPage` is special-cased;
for every other address space, `AS2` included:

```cpp
    // Indirect indexed addressing mode: 16-bit register + 8-bit index register.
    // Doesn't matter which is 8-bit and which is 16-bit.
    return !AM.BaseGV && !AM.BaseOffs &&
           (is8BitIndex(AM.BaseType) || is8BitIndex(AM.ScaleType));
```

`MOSTTIImpl::isLSRCostLess` then ranks `Insns` first, so a formula that drops the 32‑bit IV (a free
"addressing mode" plus one shared `i8` IV) always wins. The `-lsr-preferred-addressing-mode=pre|postindexed`,
`-lsr-insns-cost=false` and `-lsr-exp-narrow` knobs all left the sizes unchanged (72/72/72).

**MIR / final code.** In V3 the prologue computes `p = tab + base` once (`0x09`–`0x1f`). The loop
(`0x23`–`0x46`, 36 B) is just the per-iteration `p + j` and the load:

```
  23: 86 00     stx __rc2        ; j (X) -> DP
  25: 98        tya              ; p.lo (kept in Y since the prologue)
  26: 18        clc
  27: 65 00     adc __rc2
  29: 85 00     sta __rc4        ; q.lo
  2b..3b:       lda/adc #0/sta x3 -> q.hi, q.bank, q.top   (carry chain)
  3d: a7 00     lda [__rc4]
  3f: 9d 00 00  sta dst,x
  42: e8        inx
  43: e0 40     cpx #$40
  45: d0 dc     bne $23
```

Nothing in this loop is invariant, so `early-machinelicm` and `machinelicm` have nothing to refuse.
The multi-instruction carry chain never gets the chance to be a `MachineLICM` problem.

In V1 the loop (`0x0f`–`0x54`, 70 B; Phase 1 counted from `0x11`, giving 68) additionally computes the 16‑bit
`o + j` (with the `rep`/`sep` and `phy`/`ply` carry-save dance) before the 32‑bit `tab + zext`.
Again, every piece depends on `j`. The only invariant parts, `hi(tab)` in X at `0x0b` and `o` in
`__rc2`, are already outside the loop.

## 2. Measurement — byte sizes, with and without the scheduler cliff

`-Os -ffunction-sections -c`, `+mos-a16`, `-mllvm -verify-machineinstrs` (clean on every build),
sizes from `llvm-objdump -h`. Raw output:

```
lsr=on  misched=on  v1_wrap16=86 v2_wide=72 v3_ptr=72 v4_walk=72
lsr=on  misched=off v1_wrap16=86 v2_wide=73 v3_ptr=73 v4_walk=73
lsr=off misched=on  v1_wrap16=86 v2_wide=72 v3_ptr=72 v4_walk=92
lsr=off misched=off v1_wrap16=86 v2_wide=73 v3_ptr=73 v4_walk=91
xy16 misched=on  v1_wrap16=86 v2_wide=72 v3_ptr=72 v4_walk=72      (+mos-a16 +mos-xy16)
xy16 misched=off v1_wrap16=86 v2_wide=73 v3_ptr=73 v4_walk=73
farindex misched=on  .text.main=422
farindex misched=off .text.main=342
blithoist 42      (hand-built, llvm-mc)
blitdpy 32        (hand-built, llvm-mc)
```

| shape | legal to hoist `tab+o`? | today (misched on / off) | pointer-IV form, compiler (`-disable-lsr`) | pointer-IV, hand (`blithoist`) | `[dp],Y` (`blitdpy`) |
|---|---|---|---|---|---|
| V1 `tab[o+j]` (`loop.c`) | **no** — 16‑bit wrap | 86 / 86 B, body 70 B, ~101 cy/iter | n/a | *not equivalent* | *not equivalent* |
| V2 `tab[(uint32_t)o+j]` | yes (already hoisted) | 72 / 73 B, body 36 B, ~55 cy/iter | 72 / 73 (no IV to keep) | 42 B, body 20 B, 26 cy | **32 B, body 10 B, 18 cy** |
| V3 `p=tab+base; p[j]` | yes (already hoisted) | 72 / 73 B | 72 / 73 | 42 B | **32 B** |
| V4 `p=tab+base; *p++` | yes (already hoisted) | 72 / 73 B (LSR → `p+j`) | **92 / 91 B**, body 53 B, ~64 cy | 42 B | **32 B** |
| `farindex.c` `main` | no loop | 422 / 342 B | n/a | — | — |

Cycle counts are hand counts for the 8‑bit-M loop body, assuming DP=0 and the non-carry path.
Phase 1's own figures are reused for `blithoist` and `blitdpy`.

- **The scheduler cliff does not touch this shape.** The single-access loop moves by ±1 B between
  misched on and off, so neither conclusion depends on it. `farindex.c`'s 80 B gap is entirely
  the cliff, and none of it is loop-related.
- **Increment 1 did not move these numbers.** V1 is still 86 B, as the increment 2 TODO already records.

## 3. Safety constraint — when the far pointer computation may *not* be hoisted

A pointer-IV or hoisted-base form is correct only if **every** condition below holds. Record them
here so that whichever item eventually touches this path does not rediscover them:

1. **The offset must be computed at pointer width, or proven not to wrap.** A 16‑bit index sum
   `o + j` that is zero-extended afterwards (`zext(add i16 …)` with no `nuw`) wraps modulo 2¹⁶
   *inside the bank-offset range*. Rewriting it as `(tab + o) + j` changes the address whenever
   `o + j ≥ 2¹⁶`. This is the `loop.c` case. It needs `nuw` on the narrow add, a proven range on
   `o`, or loop versioning. None of these is available for a volatile runtime `base`.
2. **The base must genuinely be loop-invariant.** A volatile base read *inside* the loop, or a base
   loaded from memory that the loop stores to (or a call may clobber), cannot be hoisted.
3. **The pointer IV must advance at full 24‑bit width, carrying into the bank byte.** A 16‑bit
   pointer walk would re-introduce the cross-bank truncation bug fixed by `0001`
   (`farindex.c`'s history).
4. **Scale belongs in the step.** For `elem > 1` the step is `sizeof(elem)`. The wrap condition
   in (1) is then on the *scaled* offset.

## 4. Where the motivating shape's win actually is

For `loop.c` as written, the address is `tab + zext16(k)` with `k = o + j` wrapping at 16 bits. A
legal cheap form therefore needs a **16‑bit index register holding `k`** and an addressing mode that
adds it to a 24‑bit base with carry into the bank:

- **`lda tab,X` (`bf`, absolute-long indexed) with a 16‑bit X under `+mos-xy16`** is exactly
  `tab + zext16(X)`. No DP pointer is needed, and `k` becomes a plain 16‑bit IV (`inx`), so the
  wrap is handled by construction. That is the open `long,X` item (T3, measure-first). **`loop.c` is a
  customer for it, not for `[dp],Y`.**
- Under `+mos-a16` alone (8‑bit X/Y), no index mode can hold `k`, so today's per-iteration add is
  the correct code for this source.

## 5. The `[dp],Y` interaction — **flagged**

Two findings for `[dp],Y` **increment 2** (the in-flight `[wip T4]` item):

1. **Hoisting (strength reducing) would make `[dp],Y` *harder* to see — so don't.** Increment 2 wants
   a far access of the form `load (p + zext(idx))` with `p` loop-invariant and `idx` provably
   within the Y width. **That is exactly the IR LSR produces today** for V2, V3 and V4, because
   `isLegalAddressingMode` already promises the mode. If a "hoist fix" made LSR keep a pointer IV
   (for example by making `isLegalAddressingMode` return false for AS2 reg+reg), every such loop
   would turn into `load p_iv; p_iv += 1`. The index would vanish, and increment 2 would have
   nothing to fold. That shape also costs +20 B on today's compiler (V4 with `-disable-lsr`). The
   two changes compete. `[dp],Y` dominates (32 vs 42 B even against a perfect hand-built walk), so
   **the address-space-blind legality hook should stay as it is.** Once increment 2 lands, it
   becomes *true* for `i8` indices under `+mos-a16`. If increment 2 ever leaves a legal `i8`-index
   case unfolded, the hook becomes a lie for that case. It should then be made AS2-aware *to match
   what ISel folds*, not to force a pointer IV.
2. **Correctness trap for increment 2: `loop.c` is NOT a legal `[dp],Y` customer with `Y = j`.**
   The increment 2 TODO names `dev/dpy-shapes/loop.c` as "its customer", measured by Phase 1's
   `blitdpy.s`. But `blitdpy.s` computes `(tab + o) + j`, which is **not** the C semantics when
   `o + j` wraps (§3.1). Increment 2's matcher must **not** reassociate
   `tab + zext(add i16 o, j)` into `(tab + zext o) + zext j` unless the narrow add is `nuw`. The
   legal `[dp],Y` customers are V2, V3 and V4 (index = `zext i8 j`, trivially < 256). Use one of
   those, not `loop.c`, as increment 2's before/after fixture. **If increment 2 already uses
   `loop.c` and reports `b7` firing on it, that is a probable miscompile.** The differential will
   not catch it unless a test drives `base ≥ 0xFFC1`.

## 6. Disposition

- **Investigation complete. Verdict: NO‑GO on a separate hoist or strength-reduction Phase 2.** No
  new T4 follow-up item. The measured win is owned by `[dp],Y` increment 2 (legal `p[j]` shapes)
  and `long,X` (`loop.c`'s wrapping shape). The two flags in §5 are routed to those items.
- Durable artifact merged to `main`: this document. The fixture is inlined in §1, and the commands
  are below. The throwaway worktree is removed.

**Reproduce** (host only; any `mos-clang` of the same build):

```bash
C=build/llvm-mos-install/bin/mos-clang; OD=build/llvm-mos-install/bin/llvm-objdump
A16="-Xclang -target-feature -Xclang +mos-a16"
# IR: is tab+o in the preheader?  Does LSR rewrite the walk?
$C --target=mos -mcpu=mosw65816 $A16 -Os -S -emit-llvm vars.c -o vars.ll
$C --target=mos -mcpu=mosw65816 $A16 -Os -c vars.c -o /dev/null \
   -mllvm -print-before=loop-reduce -mllvm -print-after=loop-reduce -mllvm -filter-print-funcs=v4_walk
# sizes: add -mllvm -enable-misched=false and/or -mllvm -disable-lsr
$C --target=mos -mcpu=mosw65816 $A16 -Os -ffunction-sections -mllvm -verify-machineinstrs -c vars.c -o v.o
$OD -h v.o
```
