# [MOS] `-verify-machineinstrs` rejects a dead read of an `undef` `Imag16` sub-lane after register allocation ("Using an undefined physical register")

## Summary

Under `+mos-a16`/`+mos-xy16` at `-O1`/`-Os`, a high-register-pressure function can
emit a **dead** `$x = COPY $rcN` whose `$rcN` is the **high byte of an `Imag16`
pair whose high lane is `undef`**. The verifier rejects it:

```
*** Bad machine code: Using an undefined physical register ***
- function:    main
- instruction: renamable $x = COPY killed renamable $rc11
- operand 1:   killed renamable $rc11
```

The code is **correct** at runtime (the copy is dead — `$x` is overwritten before
any use), so this is a latent verifier-only defect, but it blocks
`-verify-machineinstrs` builds.

## Root cause

A 16-bit value (here a `__mulsi3` argument) is built with the standard
sub-register idiom where one lane is defined and the sibling lane is `undef`:

```
undef %N.sublo:imag16 = COPY %lowbyte     ; %N.subhi is undef
```

Register allocation assigns `%N` to an `Imag16` pair (`$rc10:$rc11`) and tracks
the **undef high lane** as live from the `undef`-def point to a later (dead)
full-pair read:

```
assigning %1759 to $rs5:  RC10LSB [5980r,5988r)  RC11LSB [5980r,6000r)
```

…but **no instruction materializes the high lane**. When the virtual sub-register
read is lowered to the **physical** `$rc11`, the `undef` attribute that the
virtual subrange carried is **lost** (a physreg read has no `undef` flag), so the
dead read of `$rc11` looks like a use of an undefined physical register and the
verifier rejects it.

```
$rc10 = COPY $rc6        ; low lane defined
...
$x = COPY $rc10          ; dead ($x overwritten below)
$x = COPY killed $rc11   ; <-- dead read of the UNDEF high lane -> verifier reject
$x = COPY $rc9           ; overwrites $x
```

## Why it is a verifier-only / latent issue

`-mllvm -join-liveintervals=false` (disable the coalescer) makes it verify clean —
not because the coalescer is at fault, but because without coalescing the dead
extracts stay separate vregs that the dead-MI pass then removes. With coalescing,
the dead pair-extract survives RA as a physical read of the undef lane.

## Why the rewriter's existing undef-marking misses it

The target enables sub-register liveness (`enableSubRegLiveness() == true`,
`Imag16` has disjunct `sublo`/`subhi`), and `VirtRegRewriter` already marks undef
sub-register reads (`VirtRegMap.cpp`: `readsUndefSubreg(MO)` → `MO.setIsUndef(true)`).
It misses this case because a **live-range-split full-pair `COPY`** (`%1759 = COPY
%x`, defining *both* lanes at one slot) propagates the **undef `subhi` lane as a
*live* value** — so `readsUndefSubreg` finds a live subrange overlapping the
`subhi` lane mask at the read and returns `false`. The split/copy-insertion does not
carry the lane's `undef`-ness through the inserted COPY.

## Candidate fixes (maintainer's call — touches generic RA / sub-register liveness)

1. **Carry `undef` through the split/spill COPY.** In SplitKit / InlineSpiller,
   when copying a value whose lane is `undef`, mark that lane `undef` on the
   inserted COPY's source so the downstream read is recognized undef.
2. **Trace the undef origin in `readsUndefSubreg`** — treat a subrange whose
   reaching value originates at an `undef` def as not-live for the read.
3. **Eliminate the dead pair-extract** before verification (a dead `$x = COPY
   $rcN` whose def is dead and whose source lane is undef).

All are toolchain-wide; the `undef %N.sublo:imag16 = …` idiom is pervasive in the
MOS backend, so any change needs a full differential + verify regression sweep.

## Reproduction (downstream llvm-mos-65816 fork)

`examples/snes/corpus/lsystem_sim.c` (function `main`) and
`examples/snes/corpus/newton_sim.c` (function `newton_gate_crc`, `-O1` only),
compiled `-mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os -mllvm
-verify-machineinstrs`. Both run correctly (lsystem `0x79C3`, newton `0x4D8B` on
MAME + bsnes-jg). Tracked downstream as
`KNOWN_ISSUES["a16-rc-undef-ra-pure-virtual"]`.

## Relationship to the coalescer fix

This is a **distinct second cause** of the same verifier message; the
register-coalescer copy-hint cause (`vreg = COPY $rcN` folded into a pair across a
clobbering call) is fixed separately in `MOSRegisterInfo::shouldCoalesce` — see
[`upstream-coalesce-rc-undef-pr.md`](upstream-coalesce-rc-undef-pr.md). That fix
does **not** address this one (there is no `$rcN` copy hint here to refuse).
