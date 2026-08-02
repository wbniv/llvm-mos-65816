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

A downstream attempt at (2) — a bounded `readsUndefSubreg` tracer that follows a
spuriously-live lane through full-register split COPYs to its `undef` origin —
clears the straight-line shape but **not** these witnesses: both are
**loop-carried**, so the lane's reaching value at the read is a **PHI-def** at the
loop header. Proving its undef-origin requires recursing through every predecessor
**including the loop back-edge** (visited-set + slot/lanemask care), which is a
materially larger change — reinforcing that this belongs in SplitKit/InlineSpiller
(carry the lane's undef-ness through the inserted COPY at the source) rather than a
patch on the rewriter's read side.

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

---

## Second manifestation (2026-08-02): the undef lane feeds a *store*, not a dead read

The original report characterises the surviving read as **dead** (`$x = COPY $rcN` with `$x`
immediately overwritten), which supports the "code-correct, verifier-only" framing. A second
instance found in `examples/snes/seqvm.c` (`draw_frame`, `+mos-a16`, `-O1/-O2/-Os`, clean at
`-O0`/`-Oz`) has the same cause but a live consumer:

```
; pre-rewriter (virtual)
464B  %91:imag16  = STAImag16 %306:ac16
480B  undef %371.sublo:imag16 = COPY %91.subhi:imag16     ; high lane never defined
712B  undef %375.sublo:imag16 = COPY %371.sublo:imag16    ; ditto, propagated
716B  %376:imag16 = COPY %375:imag16
724B  %377:gpr = COPY %376.sublo:imag16
728B  STAbs %377:gpr, %stack.2
736B  %378:gpr = COPY %376.subhi:imag16                   ; reads the undefined lane
740B  STAbs %378:gpr, %stack.2 + 1                        ; ... and STORES it

; after Virtual Register Rewriter
480B  renamable $rc4 = COPY killed renamable $rc3
736B  renamable $x = COPY killed renamable $rc3           ; *** Using an undefined physical register
```

Notes that may help whoever fixes this:

- The `killed` flag at 480B is **correct** — that vreg's use genuinely ends there. The later
  physical read belongs to a different vreg whose high lane is undef by construction; RA
  assigned both to `$rc3`. Diagnosing this from the post-RA MIR alone invites a
  "premature kill flag" misreading (we made exactly that mistake first).
- The high-lane copy of `%376 = COPY %375` is elided during rewriting because the source lane
  is undef; the `undef` flag is not transferred to the surviving physical *read*, which is what
  the verifier then rejects.
- Enabling sub-register liveness (`-mllvm -enable-subreg-liveness`) does **not** suppress it.
- Still code-correct: the compiler itself declared the lane a don't-care, and the demo's
  differential gate passes (`dev/run.sh seqvm` → `0xE8C5`). The store simply writes a
  don't-care byte to a stack slot whose high half is never read.
