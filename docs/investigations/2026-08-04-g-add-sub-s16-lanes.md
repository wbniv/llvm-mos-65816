# Does `G_ADD`/`G_SUB` miss 16-bit lanes under `+mos-a16`?

**Date:** 2026-08-04 · **Branch:** `throwaway/g-add-sub-s16-lanes` ·
**Worktree:** `/home/will/llvm-mos-65816-gaddsub16`
**Spun out of:** the #122 withdrawal in
[`plans/2026-08-03-round7-defect-hunting-demos.md`](../plans/2026-08-03-round7-defect-hunting-demos.md)

## Verdict — (b) the 8-bit carry chain is right as the default; now documented, not assumed

A blanket s16-lane form was **built and measured**, not modelled. Across the 112 compilable
corpus slices it is a **net loss of +281 B (+0.18%)** and it **breaks two slices that the
baseline compiles cleanly** (`-verify-machineinstrs`: *Using an undefined physical register*).
The carry-seam concern the TODO item raised is **real and now demonstrated**, not hypothetical.

But the result is strongly **bimodal**, not a wash: 20 slices get smaller by a combined
**2265 B (1.48% of the corpus)** while 24 get bigger by **2546 B**. There is a genuine prize
here; it is simply not reachable by changing the add's lane width alone. The blocker is
structural and is stated in [Why](#why-the-lane-width-cannot-move-alone) below.

## Correcting the item's premise

The TODO item says the a16 feature makes no difference to add/sub. That is **half right**, and
the half it gets wrong matters:

- **s16 add/sub is already native under a16.** `legalizeAddSub`
  (`MOSLegalizerInfo.cpp:875-878`) returns early for `hasAccum16() && Ty == s16`, handing the op
  to `selectAlu16Native` → one 16-bit `adc`/`sbc` on `A16`. This has been in place since
  Increment 1d-retry.
- **Only s32-and-wider falls to the byte chain.** With no `maxScalar`, anything wider reaches
  `Helper.narrowScalarAddSub(MI, 0, S8)` → an N-lane 8-bit `G_UADDE` chain, identical to the
  default build. So the item's "identical MIR with and without the feature" observation is
  correct **for s32+ only**.

The item also worried a 16-bit lane would need new pseudo-instructions for the carry seam. It
does not: `ADCImag16` / `ADCAbs16` / `SBCImag16` / `SBCAbs16` (`MOSInstrLogical.td:667-686`,
`838-853`) already carry `Cc:$carryin` in and `(outs Ac16:$dst, Cc:$carryout, Vc:$vout)` out.
That is why this experiment was cheap enough to actually build.

## Phase A — the population and shape of the byte chains

`dev/measure-addsub-lanes.sh` (new, host-only, no rebuild) over all 120 corpus slices,
`+mos-a16 -Os`, post-legalize MIR.

### Carry-chain lane-width histogram

| lanes | chains | meaning | lane-bytes |
|---:|---:|---|---:|
| 1 | 2 | s8 add with carry (not a widened add) | 2 |
| 2 | 5 | s16 **not** via the native path | 10 |
| 3 | 19 | s24 / packed far | 57 |
| 4 | 176 | **s32** | 704 |
| 7 | 1 | other | 7 |
| 8 | 41 | **s64** | 328 |
| **total** | **244** | | **1108** |

237 chains are ≥3 lanes, spread over 44 of 120 slices. Corpus `.text` under a16 is
**152,615 B** — and, worth noting on its own, **198 B larger** than the same corpus built
without the feature (152,417 B).

### Operand residency — the lesson-2 measurement

For every byte operand of every wide chain, the defining opcode, chased through `COPY`:

| count | share | producer | 16-bit lane finds this… |
|---:|---:|---|---|
| 557 | 25.4% | `COPY` from a physreg / argument | **byte-locked** |
| 428 | 19.5% | another lane of the same chain | 16-friendly |
| 290 | 13.2% | `G_CONSTANT` | 16-friendly |
| 268 | 12.2% | `G_UNMERGE_VALUES` | 16-friendly |
| 203 | 9.3% | `G_PHI` | **byte-locked** |
| 146 | 6.7% | `G_SHLE` | **byte-locked** |
| 111 | 5.1% | `G_LSHRE` | **byte-locked** |
| 83 | 3.8% | `G_SELECT` | **byte-locked** |
| 59 | 2.7% | `G_SBC` | **byte-locked** |
| 46 | 2.1% | `G_LOAD_*` | 16-friendly |
| **2192** | | **total** | **47.1% friendly / 52.9% byte-locked** |

Per chain: **179 byte-locked, 47 all-friendly, 11 mostly-friendly**. Only 46 of 2192 operands
(2.1%) come from a memory load. The chains are overwhelmingly fed by *other byte-level MIR
values*, which is the whole story.

## Phase B — the experiment, built and measured

Three gated hunks in the worktree's `vendor/`, all conditioned on `STI.hasAccum16()`:

1. `MOSLegalizerInfo.cpp` `legalizeAddSub` — narrow a wide `G_ADD` to `S16` lanes when the
   width is an exact multiple of 16. (`G_SUB` deliberately excluded: `legalizeSubE` hardcodes
   `S8` when building `G_SBC`, a separate surface. Add dominates anyway — 2885 `adc` vs 663
   `sbc` in the corpus.)
2. `G_UADDE` legal for `S16`, `maxScalar` raised to `S16`. `G_SADDE` left at `S8`.
3. `G_UADDO` custom for `S16`, `maxScalar` raised to `S16` — `narrowScalarAddSub` emits lane 0
   as `G_UADDO`, so leaving it capped produced a **hybrid** (low lane 2×s8, high lane native)
   that was worse than either pure form. This was a real intermediate result, not a typo.
4. `MOSInstructionSelector.cpp` — route s16 `G_UADDE` to `selectAlu16Native`, generalized to
   take carry-in from the instruction (operand 4) and define the carry-out (operand 1) rather
   than synthesising a `clc`.

### The generated form is exactly what was wanted — and still loses

`unsigned long gc = ga + gb` on plain (non-volatile) globals:

```
BASELINE (4x s8 lanes)                  EXPERIMENT (2x s16 lanes)
  .text.f = 0x38 = 56 B                   .text.f = 0x4e = 78 B   (+22 B)

  lda/ldx/ldy/sty  marshalling ~14 B      ldx/ldy/stx/sty marshalling  40 B
  clc                                     clc
  adc ; adc ; adc ; adc   (8-bit x4)      rep #$20
  sta/stx unpacking       ~15 B             lda ; adc ; sta
                                            lda ; adc ; sta          (16-bit x2)
                                          sep #$20
                                          ldx/stx unpacking          20 B
```

The arithmetic core did exactly what the design intended — **one `clc`, one `rep`/`sep`
bracket, two 16-bit `adc`s, 17 B** against roughly 25 B for the four-lane byte form. The
**marshalling around it exploded from ~29 B to ~60 B**, because `G_LOAD`/`G_STORE` still carry
`maxScalar(0, S8)`, so the s32 global arrives as four separate byte loads and has to be
re-assembled into contiguous `Imag16` zero-page pairs and taken apart again afterwards.

### Corpus A/B (`dev/measure-addsub-ab.sh`, new)

| | bytes |
|---|---:|
| a16 baseline | 152,615 |
| a16 experiment | 152,896 |
| **net** | **+281 (+0.18%)** |
| 20 slices smaller | **−2265** (1.48% of corpus) |
| 24 slices larger | **+2546** |
| 68 slices unchanged | 0 |
| **default (non-a16) build, before vs after** | **±0 — gate holds** |

Best: `bitcensus_sim` −929, `tea_sim` −399, `oddmask_sim` −210, `lsystem_sim` −195,
`avalanche_sim` −143. Worst: `mulov64_sim` **+807**, `perlin_sim` +309, `turtle-vm_sim` +172,
`raycaster_sim` +164, `boids_sim` +163.

`mulov64_sim` (+807) is the clearest anti-case: 41 eight-lane s64 chains, so every one pays
marshalling four times over.

### Correctness — the carry seam is real

`-verify-machineinstrs` over the corpus with the experimental compiler:
**110 pass, 2 fail** — `pcooker_sim` and `rdiff_sim`, both
`*** Bad machine code: Using an undefined physical register ***` after the Virtual Register
Rewriter. Both compile **clean** on the baseline. The carry physreg's live range does not
survive the `rep`/`sep` bracket plus `Ac16` pressure at the lane seam the way the 8-bit chain's
does. This is precisely the "a 16-bit lane changes the seam" risk the TODO item flagged, and it
is now evidence rather than speculation.

(The 7 slices reported `COMPILE-FAIL` — `cpu6502_sim`, `keycmp64_sim`, `multibase_sim`,
`nmitally_sim`, `qsortviz_sim`, `spaceship_sim`, `ucmprank_sim` — fail **identically on the
baseline compiler**; they need libc headers this host-only harness does not supply. They are
excluded from both sides, not a regression.)

## Why the lane width cannot move alone

An s32 value under a16 is **byte-resident at both ends**: `G_LOAD`/`G_STORE` narrow to `S8`
(`maxScalar(0, S8)`), and `G_PHI`, `G_SHLE`/`G_LSHRE`, `G_SELECT` all operate on byte lanes.
Converting only the add makes the 16-bit lane an **island** — the value must be marshalled into
`Imag16` pairs on the way in and taken apart on the way out. The measured 52.9% byte-locked
operand share is that island's perimeter, and the marshalling cost scales with it.

The 20 winning slices are the ones where the chain sits amid *other* 16-friendly producers, so
the island is large enough that its perimeter is amortised. That is why the result is bimodal
rather than uniformly bad.

## What would actually be needed

Not a bigger version of this patch. Either:

- **(A) Widen the lane model coherently** — s16 lanes for `G_LOAD`/`G_STORE`/`G_PHI`/shift/
  select under a16 together, so wide values are 16-bit-resident end to end and the add's lane
  width follows. Large, cross-cutting, and it must carry its own regression story; the payoff is
  the 2265 B seen here plus the `legalizeUnmergeS32ToBytes` traffic it would delete (385 fires
  across 52 slices). This is a roadmap-sized item, not a follow-up.
- **(B) Gate the narrow change on measured operand residency** — fire s16 lanes only when every
  byte operand of the chain resolves to a 16-friendly producer. 47 of 237 chains qualify today.
  This satisfies the project's gating discipline (a misclassification only misses a win), but it
  **cannot proceed until the undefined-physreg seam defect is fixed**, and it captures only the
  subset of the 2265 B that sits in all-friendly chains.

**Recommendation: close the item as (b) — deliberate, now documented.** Neither follow-up is
worth opening speculatively; (A) is the one with the real prize and it is a design decision
about the a16 lane model as a whole, not about `G_ADD`.

## Reproduce

```bash
# Phase A — no rebuild, uses the installed toolchain read-only
dev/measure-addsub-lanes.sh

# Phase B — needs the experimental toolchain built in this worktree
BEFORE=/home/will/llvm-mos-65816/build/llvm-mos-install/bin \
AFTER=$PWD/build/llvm-mos-install/bin \
dev/measure-addsub-ab.sh
```

The four experimental `vendor/` hunks live only on `throwaway/g-add-sub-s16-lanes` and are
**not** part of `patches/llvm-mos/0002`. They are kept as the reproduction for the numbers
above, not as a candidate to land.
