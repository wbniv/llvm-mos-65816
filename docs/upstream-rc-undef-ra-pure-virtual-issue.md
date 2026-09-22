# [MOS] Undefined Imag16 lane rejected after register allocation


## Current assessment — provenance clarified 2026-09-22

**Fix and upstream regression are ready for review.** An eight-instruction MIR test
reproduces on the September 21 upstream revision `742d554bf080` using the stock
MOS target and only `greedy,virtregrewriter`.

**Origin:** the failure occurred in naturally compiled downstream C, including
the [L-System Plant](https://biohack.net/snes/lsystem/) kernel preserved by
`rcundef2.c` and the [Newton Fractal](https://biohack.net/snes/newton/) kernel in
`newton_sim.c`, under our downstream-only `+mos-a16` / `+mos-xy16` features.
The demo pages identify the applications; the saved compiler inputs and logs
provide the failure evidence. The eight-instruction test is a
deliberately constructed MIR model of the observed mechanism. It does not need
those features, an SDK, or the C frontend to trigger the stock-upstream rewriter.
We have not established an ordinary stock-upstream C compilation that generates
the same pattern. Reproducing the contract failure at MIR level does not by itself
establish that frontend reachability.

The failure occurs when a full virtual-register `COPY` reads a value with an undef
lane and register allocation assigns its source and destination to the same physical
register. `VirtRegRewriter` removes that identity copy. The removal also discards the
copy's definition of the destination's undef lane, so a later physical read of that
lane has no reaching definition and MachineVerifier rejects it.

The fix detects lanes without a live source subrange before rewriting.
`rewriteInstruction` owns both operand rewriting and identity-copy cleanup,
keeping that lane information local. If the copy becomes an identity copy, the
helper retains it as a `KILL`, matching the handling for an explicitly undef
source. The `KILL` preserves the physical liveness definition and emits no machine
code. September 21 validation: current-upstream MOS CodeGen 85 pass / one
unsupported; downstream verifier gate 34/34; 24 corpus inputs have identical MIR
and assembly to the boolean-parameter implementation.
[Validation and patch artifacts](pr-preparations/2026-09-21/0028-validation.md).

The generic patch and lit test are carried in
`patches/llvm-mos/0028-llvm-virtregrewriter-undef-lane-identity-copy.patch`. The
downstream REP/SEP pass had a separate verifier failure in `trimerge_sim.c`: its X16
restore cloned a source kill flag. That pass now clears kill information on the
original writer and cloned reload and has an independent MIR regression.

[Upstream issue #48](https://github.com/llvm-mos/llvm-mos/issues/48) records related
partial-register spill-liveness history, resolved in 2021 by changing legalization.
It is useful prior art, not an established duplicate. The latest witness includes a
store, so the report must not be titled or summarized as exclusively a dead read.

See the [pending-work chart](upstream-pending-work.md) for readiness and dependencies.
The sections below preserve the investigation sequence and its revisions.

## Minimal upstream reproducer

This is the constructed test case, not the full compiler-generated MIR from the
downstream program or a claimed unchanged output of automated reduction. The
[validation record's provenance section](pr-preparations/2026-09-21/0028-validation.md#reproducer-provenance)
identifies the saved C-generated MIR, failure log, and reduction artifacts.

```mir
bb.0:
  %0:gpr = LDImm 1
  undef %1.sublo:imag16 = COPY %0
  %2:imag16 = COPY %1
  %3:gpr = COPY %2.sublo
  STAbs %3, 0
  %4:gpr = COPY %2.subhi
  STAbs %4, 1
  RTS
```

Before the fix, `%1` and `%2` both allocate to `$rs1`; the identity copy disappears,
and the `$rc3` read fails verification. After the fix, rewriting retains
`$rs1 = KILL $rs1` between the low-lane definition and the two extracts.

## Historical investigation

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

> **Update 2026-08-02.** A second witness has the same root cause but the surviving
> read is **not** dead — it feeds a store. It is still code-correct (the compiler
> itself declared the lane a don't-care), so the verifier-only characterisation
> holds, but "the copy is dead" is *not* the invariant that makes it safe. See
> [Second manifestation](#second-manifestation-2026-08-02-the-undef-lane-feeds-a-store-not-a-dead-read).

## Superseded diagnosis: lane propagation

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

## Why the earlier rewriter diagnosis appeared plausible

The target enables sub-register liveness (`enableSubRegLiveness() == true`,
`Imag16` has disjunct `sublo`/`subhi`), and `VirtRegRewriter` already marks undef
sub-register reads (`VirtRegMap.cpp`: `readsUndefSubreg(MO)` → `MO.setIsUndef(true)`).
It misses this case because a **live-range-split full-pair `COPY`** (`%1759 = COPY
%x`, defining *both* lanes at one slot) propagates the **undef `subhi` lane as a
*live* value** — so `readsUndefSubreg` finds a live subrange overlapping the
`subhi` lane mask at the read and returns `false`. The split/copy-insertion does not
carry the lane's `undef`-ness through the inserted COPY.

## Superseded candidate fixes

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

All compiled `-mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -mllvm
-verify-machineinstrs`, and all run correctly (the fork's 4-way host/MAME/bsnes-jg
differential was green on every one). They are now positive verifier regressions.

| witness | function | reproduces at | notes |
|---|---|---|---|
| `examples/snes/seqvm.c` | `draw_frame` | `-O1`/`-O2`/`-Os`, `+mos-a16` and `+mos-xy16` | 2 errors, `$rc3` + `$rc5`; the undef lane feeds a **store**, not a dead read — see [Second manifestation](#second-manifestation-2026-08-02-the-undef-lane-feeds-a-store-not-a-dead-read) for the exact command line and output. Needs `--config mos-snes.cfg`. Clean at `-Oz` under `+mos-a16`. |
| `examples/65816/rcundef2.c` | `main` | `-O1`…`-Os`, both features | `$rc11`; self-contained (`--target=mos`, no SDK headers), which is why it is the fork's XPASS-guard repro. |
| `examples/snes/corpus/newton_sim.c` | `newton_gate_crc` | `-O1` **only** | 3 errors, `$rc2`/`$rc4`/`$rc5`. Clean at `-Os` since the fork's coalescer fix for the *other* cause. |
| `examples/snes/corpus/trimerge_sim.c` | `main` | `-O1`/`-Os`, `+mos-xy16` only | `$x16 = LDXImag16 killed renamable $rs1` ×3 — the Imag16-**pair** form of the same cause. |

> **Note on an earlier repro.** Revisions of this report before 2026‑09‑15 named
> `examples/snes/corpus/lsystem_sim.c` (`main`, `$rc11`) as the primary witness. That file
> verifies **clean** today, but **not because anything was fixed**: an unrelated downstream
> commit (2026‑08‑01) rewrote its idle loop from `for (;;) {}` to
> `for (;;) __asm__ volatile("wai")`, which reshapes `main` enough that the vulnerable live
> range is no longer formed. Feeding the *previous* revision of that file to the *current*
> compiler still reproduces `$rc11` at `-O1`/`-O2`/`-O3`/`-Os` on both features. The reduced,
> loop-free `rcundef2.c` above preserves that exact shape.

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

### Misdiagnosis, recorded deliberately

The first pass at this witness read the **post-RA** MIR only, saw `killed renamable $rc3`
at 480B followed by a read of `$rc3` at 736B, and concluded **"premature kill flag →
potential miscompile"**. That framing is **withdrawn**. The kill at 480B is correct: it
ends the live range of a vreg whose use genuinely finishes there, and the read at 736B
belongs to a *different* vreg — one whose high lane is undefined by construction — that
RA happened to assign the same physical register. Only the **virtual-register** MIR
(`-mllvm -print-after=…` before the rewriter, the 480B→712B→716B→736B chain above)
distinguishes the two.

The practical consequence for whoever fixes this: **do not diagnose this message from
post-RA MIR**. The physical form is genuinely ambiguous between "kill flag placed too
early" (a real miscompile) and "undef lane lost its flag" (verifier noise), and the two
call for opposite fixes.

### Reproduction (second manifestation)

`examples/snes/seqvm.c`, function `draw_frame`, in the downstream llvm-mos-65816 fork:

```console
$ mos-clang --config mos-snes.cfg -mcpu=mosw65816 \
    -Xclang -target-feature -Xclang +mos-a16 \
    -Os -fno-lto -mllvm -verify-machineinstrs -c examples/snes/seqvm.c
*** Bad machine code: Using an undefined physical register ***
- basic block: %bb.2  [192B;760B)
- instruction: 736B   renamable $x = COPY killed renamable $rc3
*** Bad machine code: Using an undefined physical register ***
- basic block: %bb.5  [1024B;1600B)
- instruction: 1480B  renamable $x = COPY killed renamable $rc5
fatal error: error in backend: Found 2 machine code errors.
```

Two errors at `-Os` (and at `-O1`/`-O2`); **clean at `-O0` and `-Oz`**. Re-confirmed
byte-for-byte on 2026-08-04 and again on 2026-09-13 against the current fork toolchain.

---

## Update 2026-09-13: the copy that loses the lane is RA-inserted, and SplitKit is not the culprit

Pre-RA (`-print-before=greedy`), the value is a single original vreg with this shape:

```
bb.2:  480B  undef %207.sublo:imag16 = COPY %91.subhi:imag16        ; subhi undef here
       720B  CmpBrZeroMultiByte %bb.4, 1, %207.sublo:imag16, ...     ; branch: bb.4 skips 784B
bb.3:  784B  %207.subhi:imag16 = COPY %18.subhi:imag16               ; subhi defined on this path only
...   3472B  CmpBrImag16 %bb.12, undef $z, 1, %32:imag16, %207:imag16 ; full 16-bit use, both paths merge
      4144B  CmpBrImag8 %bb.4, undef $z, 1, %320:gpr, %207.sublo:imag16
```

There is no full-pair copy of `%207` before register allocation, and the highest pre-RA vreg is
`%327`, so `%371`, `%375`, `%376` and `%378` are all created by greedy. `SplitEditor::defFromParent`
copies only the lanes of the *original* interval's subranges that are live at the split point
(`SplitKit.cpp`, `LaneMask |= S.LaneMask` for `S.liveAt(UseIdx)`), and it did narrow the 712B copy to
`sublo`. The full-pair copy four slots later at 716B therefore means LiveIntervals reported
`%207.subhi` live at 716B, on a path where the only reaching definition of that lane is the
`undef` partial def at 480B. The earlier read-side tracer saw the same thing from the other end (the
subrange value reaching the read is a PHI-def).

So the rewriter and SplitKit both behave correctly for the liveness they are handed; the suspect
is how the `subhi` subrange is extended across the `undef`-flagged partial def when the 784B value
and the undef path merge before the full use at 3472B (`LiveRangeCalc::findReachingDefs` /
`updateSSA` with the `Undefs` slots from `computeSubRangeUndefs`). A fix at that layer would make
the 716B copy narrow to `sublo`, leave `%376.subhi` with no subrange, and let the rewriter's
existing `readsUndefSubreg` mark the 736B read `undef`. Downstream we have not attempted this:
it is generic sub-register liveness, and the failure mode of getting it wrong is a silent
miscompile rather than a verifier message.
