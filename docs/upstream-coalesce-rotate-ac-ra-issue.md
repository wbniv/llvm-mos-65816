# [DRAFT — issue body for llvm-mos/llvm-mos; strip this preamble when posting]
#
# Status: DRAFTED 2026-07-31, NOT POSTED (posting is user-triggered). Companion to
# PR #578 (coalesce-rotate-Ac guard); referenced from that PR's body ("happy to file a
# companion issue"). Post AFTER (or together with) a maintainer response on #578, so the
# issue lands as the promised follow-up rather than a drive-by.
# Post command:
#   gh issue create --repo llvm-mos/llvm-mos \
#     --title "[MOS] Greedy RA mishandles an Ac-pinned loop-carried live range (stale A across a rotate back-edge)" \
#     --body "$(sed '1,/^---$/d' docs/upstream-coalesce-rotate-ac-ra-issue.md)"
---
## Context

PR #578 stops the register coalescer from merging two shift/rotate-referenced values
into the A-only `Ac` register class, because the resulting pinned live range was
observed to miscompile an inlined CRC16 bit loop (stale `A` read by the back-edge
`ROL`). That guard removes the *trigger* — this issue records the *underlying* RA
behavior, which the guard does not change.

## The RA-level defect

Input state (produced by the coalescer before #578, and in principle producible
without any coalescing at all): a vreg constrained to `Ac`, loop-carried across an
inner conditional, where the conditional's other arm needs `A` for an unrelated value.
This MIR is `-verify-machineinstrs` and `-verify-coalescing` clean — an `Ac`-pinned
live range is legal, just maximally constrained (the class has one register).

Observed allocation (65816, `-Os`, default 8-bit accumulator, under pressure):

```
loop:  sta __rc2      ; save old crc-high for the sign test
       asl __rc29     ; crc-low << 1
       rol            ; A = new crc-high
       tay            ; Y = new crc-high      <-- RA parks the Ac value in Y
       lda __rc2      ; A = OLD crc-high (the other arm's use of A)
       bpl .skip
       ...xor path ends with tay (Y updated)...
.skip:               ; <-- no tya: nothing restores A
       dex
       bne loop       ; back-edge ROL reads the STALE A
```

The value's only legal home at the `ROL` is `A`, yet RA leaves the current value in
`Y` on the skip path and never copies it back before the back-edge use. The result is
a silent miscompile: the machine verifier cannot see values, only liveness, and the
liveness is consistent.

## Why the #578 guard doesn't close this

The guard fires in `shouldCoalesce`, so it only helps when the pinned range would
have been *created by a join* — it keeps the `COPY`, letting the value live in the
broader `AImag8`/`AY` class. A program whose two rotate uses reach RA already on a
single vreg (no `COPY` to preserve) would still present RA with the same pinned
loop-carried range. We have not found such a shape in the wild — in every observed
case, separately-defined rotate values reach the coalescer through a `COPY` — but
nothing rules it out structurally.

## Reproduction status

The wrong allocation needs genuine register pressure: a cvise reduction of the
original program (a Mode-7 zoom demo's CRC fold; details and asm in #578) bottomed
out at four simultaneous pressure sources — removing any one makes the wrong
allocation vanish — so we could not extract a small standalone reproducer. Before
#578's guard, the miscompile reproduces on that demo as a differential failure
(loop-form CRC `0xE60E` vs correct `0xF56C`). After the guard, no known input
reaches the defect; this issue is filed as latent-hazard documentation with analysis
attached rather than a live crasher.

## Possible directions

- Teach the relevant split/spill path that an `Ac`-constrained value evicted from
  `A` must be restored before any in-class use (the general contract, seemingly
  violated here).
- Or forbid `Ac` as an allocation class for loop-carried ranges entirely
  (force `AImag8`), accepting a copy where today there is a wrong-value read.
- Or add a post-RA verification pass for single-register classes: every use of an
  `Ac` value must be reached by a def or restore of `A` on all paths — this would
  have caught the original miscompile at build time.
