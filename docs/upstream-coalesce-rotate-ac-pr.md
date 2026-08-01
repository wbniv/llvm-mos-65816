# [MOS] Don't coalesce two rotate-referenced values into the A-only `Ac` class (silent miscompile)

<!-- POSTED 2026-07-26 as https://github.com/llvm-mos/llvm-mos/pull/578 (campaign Wave 1, item 2).
     UPDATED 2026-07-31 (critique-improvements pass, see
     docs/plans/2026-07-31-upstream-pr-critique-improvements.md): body below is the as-posted
     v2 text — adds the scope/root-cause section, the no-pessimization lit test, precise Csmith
     accounting, and drops the embedded (drifted) patch listing. Companion RA issue draft:
     docs/upstream-coalesce-rotate-ac-ra-issue.md (queued, NOT posted).
     Branch wbniv:mos-coalesce-rotate-ac; history: 18244924b3d3 (v1, cut from 8be054612).
-->

## Summary

On the 65816 (and any MOS subtarget), the register coalescer can merge two
shift/rotate-referenced values together into the **A-only `Ac`** register class.
Because `ASL`/`LSR`/`ROL`/`ROR` can only operate on the accumulator, an `Ac`
value is pinned to `A` for its entire live range. When such a value is also
loop-carried across an inner conditional whose *other* arm needs `A` — the
canonical case is an **inlined CRC16 bit loop**, where the bit-15 test reloads
the pre-rotate byte into `A` while the rotated high byte must survive to the
next iteration — coalescing removes the `COPY` that would let the live value
vacate `A`. The allocator then strands the value in `Y` while the loop
back-edge's `ROL` reads a **stale `A`**, silently miscompiling. `-verify-machineinstrs`
and `-verify-coalescing` are both clean, so nothing catches it.

## Reproduction

A natural CRC16-CCITT fold over an array, compiled `-mcpu=mosw65816 -Os` (default
8-bit accumulator), under enough register pressure that the rolling CRC high
byte is allocated to `Ac`, computes a **different runtime value** than the
byte-identical unrolled form. The divergence is the high byte of the CRC
accumulator falling one rotation behind, starting from the first iteration
that takes the no-XOR (skip) path:

```
loop:  sta __rc2      ; save old crc-high for the sign test
       asl __rc29     ; crc-low << 1
       rol            ; A = new crc-high
       tay            ; Y = new crc-high
       lda __rc2      ; A = OLD crc-high  (clobbers A for the bit-15 test)
       bpl .skip      ; if bit 15 == 0, skip the ^0x1021
       ...xor path ends: tay ; (Y = updated crc-high)...
.skip:               ; <-- no `tya`: A holds the STALE old crc-high
       dex
       bne loop       ; next `rol` rotates the stale A
```

`-mllvm -join-liveintervals=false` (disable coalescing) makes it correct, which
localizes it to the coalescer; bisecting the joins shows it is the coalescing of
two rotate-referenced values into `Ac`.

## Fix

`MOSRegisterInfo::shouldCoalesce` — refuse the join when the resulting class is
`Ac` and **both** the copy's source and destination are referenced by a
shift/rotate:

```cpp
if (NewRC == &MOS::AcRegClass &&
    referencedByShiftRotate(MI->getOperand(0).getReg(), MRI) &&
    referencedByShiftRotate(MI->getOperand(1).getReg(), MRI))
  return false;
```

Keeping the `COPY` lets the value occupy the broader `AImag8`/`AY` class and
spill/transfer across the `A`-clobber as needed. This mirrors the existing
rotate guards in the same function (which forbid coalescing rotate values
*into* `Imag8` memory for performance); this one is a *correctness* guard.

## What this fixes — and what it deliberately doesn't

To be precise about scope: the coalesced MIR is verifier-clean and semantically
*correct* — an `Ac`-pinned live range is legal, just maximally constrained. The
wrong code is produced downstream, when greedy RA handles that pinned
loop-carried range: it parks the value in `Y` on the skip path without
restoring `A` before the back-edge rotate. This guard removes the **trigger**
(the join that creates the pinned range), which is the conservative, reliable
place to intervene; it does not change the downstream RA behavior. In
principle, a program whose two rotate uses arrive at RA already on a single
vreg — with no `COPY` for the coalescer to remove — could still expose the
same allocation. We have not found such a shape (in every case we've seen,
separately-defined rotate values reach the coalescer through a `COPY`), and
the RA-level behavior deserves its own investigation — happy to file a
companion issue with the full analysis if that's useful.

## Tests

`llvm/test/CodeGen/MOS/coalesce-rotate-ac.mir` — a `-run-pass=register-coalescer`
test: two `ROL` results connected by a `%x:ac = COPY` must NOT be coalesced. It
fails before the fix (the COPY is removed and the two `ROL`s chain through one
vreg) and passes after.

`llvm/test/CodeGen/MOS/coalesce-rotate-ac-no-pessimize.ll` — the cost side:
common straight-line shift/rotate chains (`x << 2`, chained rotates) still
emit the tight `asl`/`rol` sequences with no extra transfers — the `COPY` the
guard keeps is allocated to `A` and folds away. This pins that the guard only
bites where the pinning would.

There is no end-to-end miscompile test in-tree, deliberately: the wrong
allocation needs genuine register pressure, and a cvise reduction of the
original bottomed out at **four simultaneous pressure sources** — removing any
one makes the wrong allocation vanish — so a small standalone reproducer is
not extractable. The miscompile itself is covered by the differential
validation below.

## Validation (downstream llvm-mos-65816 fork)

- The real miscompile (a Mode-7 zoom demo's CRC fold) now matches the host/unrolled
  reference: the loop form computes `0xF56C` (was `0xE60E`).
- Zero regressions: corpus differential 7/7, c-torture 30/30 (default == a16 ==
  xy16), `-verify-machineinstrs` clean.
- Csmith: seeds 1–60 — 54 ran to verdict, **all 54 PASS, 0 mismatch / 0 crash /
  0 error** (the other 6 were harness artifacts: result GC'd before compare, no
  verdict either way); an extended run over seeds 101–200 brought the total to
  **142/160, 0 mismatches**.
- Code-size impact: a few bytes per affected CRC-style loop (the preserved copy).
- Four SNES demos exercising CRC/LFSR rotate-under-pressure loops are playable
  in-browser (bsnes-jg WASM; each page's "Verify fidelity" button re-runs the
  WRAM self-check live against the host-computed reference):
  [crcwall](https://biohack.net/snes/crcwall/) ·
  [lfsr2](https://biohack.net/snes/lfsr2/) ·
  [bitweave](https://biohack.net/snes/bitweave/) ·
  [uarteye](https://biohack.net/snes/uarteye/)
