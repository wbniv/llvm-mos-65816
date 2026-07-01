# Finding — the `a16-*-rc-undef` "undefined physical register" verifier failure is TWO distinct defects

**Status:** **ROOT-CAUSED** (both). **Cause #1 — FIXED + SHIPPED + upstream-PR-ready** (register
coalescer). **Cause #2 — root-caused, three fix attempts, DEFERRED to upstream** (a generic-LLVM RA
sub-register-`undef`-liveness feature). The code was already **correct** under both causes — the symptom is
a `-verify-machineinstrs` false-positive over a *latent* (never-executed-wrong) hazard, not a live
miscompile. Diagnosed 2026-06-30 with a purpose-built **asserts toolchain** (`build/llvm-mos-asserts`,
`-debug-only=regalloc` join/assignment traces) on a lifted minimal repro (`examples/65816/rcundef.c` =
`newton_step`), all on the `throwaway/rc-undef-fix` worktree.

Full arc + verification: [the plan](../plans/2026-06-29-a16-rc-undef-ra-machineverifier-fix.md). Upstream
artifacts: cause #1 [`upstream-coalesce-rc-undef-pr.md`](../upstream-coalesce-rc-undef-pr.md) (PR, patch
`0015`), cause #2 [`upstream-rc-undef-ra-pure-virtual-issue.md`](../upstream-rc-undef-ra-pure-virtual-issue.md)
(issue). Prior art / sibling: the default-8bit coalescer miscompile
[`2026-06-25-default8-65816-loopfold-miscompile.md`](2026-06-25-default8-65816-loopfold-miscompile.md)
(fork patch `0010`, the same `shouldCoalesce` hook).

## Symptom

Under `+mos-a16` / `+mos-xy16` at `-O1`/`-Os`, high-register-pressure functions emit

```
*** Bad machine code: Using an undefined physical register ***
- function:    newton_step          (or: newton_gate_crc, or main)
- instruction: renamable $x = COPY killed renamable $rcN     ; $rcN = $rc3, $rc5, $rc11 …
- operand 1:   killed renamable $rcN
```

`$rcN` are the calling convention's **imaginary** (zero-page) registers — `RC0..RC31` (8-bit) paired into
`RS0..RS15`/`Imag16` (16-bit) — the soft accumulator/index/argument-return scratch. The verifier rejects a
read of `$rcN` with no reaching definition on the path. The demos that surface it (`newton`, lsystem) run
**correctly** on both MAME and bsnes-jg (`0x4D8B`, `0x79C3`), so the value is right at runtime; the IR is
ill-formed. Open since the #2 Newton demo shipped (2026-06-27); a second independent witness (the #23
L-System demo) confirmed it is not newton-specific and motivated the dig.

## It is TWO defects

Both produce the identical verifier message; `-mllvm -join-liveintervals=false` (disable the coalescer)
masks **both** — which is what conflated them. The asserts traces separate them cleanly:

| Cause | Witnesses | Mechanism (one line) | Disposition |
|---|---|---|---|
| **#1 coalescer copy-hint** | `rcundef.c`, `newton_step` (`-Os`) | a value `vreg = COPY $rcN` (a libcall result) is folded into an `Imag16` pair across a call that re-clobbers `$rcN`; the allocator re-binds the pair to `$rcN` over the clobber | **FIXED** in `shouldCoalesce` (patch `0002`/`0015`) |
| **#2 RA undef sub-lane** | `lsystem_sim.c main` (all `-O`), `newton_gate_crc` (`-O1`), `gouraud_sim.c` + `msquares_sim.c` (`-O1`/`-Os`, demos #69/#71) | a **pure-virtual** `Imag16` whose high lane is `undef` is bound to an `$rc` pair; a dead full-pair read of the `undef` lane survives RA, and the `undef` flag is lost when lowered to the physical `$rcN` | **DEFERRED** upstream (generic-LLVM RA feature) |

`-Os` is the canonical ship/verify level (`tools/a16_fuzz.py` + every demo/corpus build are `-Os`; `-O1` is
never built). At `-Os` cause #1 covers `newton`; cause #2 still covers lsystem.

**Round-4 update (2026-07-01).** Two more Cause-#2 witnesses surfaced from the demo battery:
`gouraud_sim.c` (#69, per-pixel barycentric divide) and `msquares_sim.c` (#71, per-pixel edge-crossing
divide) both crash `-verify-machineinstrs` at `-O1`/`-Os` under `+mos-a16` and `+mos-xy16` (`-O0` clean),
with the identical `Using an undefined physical register` signature — while their full 5-way differentials
are green (code bit-exact correct). They confirm Cause #2 is **not exotic**: ordinary high-register-pressure
`int32`-divide graphics kernels hit it, not just the L-system / soft-float slices. No new action — the fix
is the same deferred generic-LLVM RA change; these are recorded as XFAIL witnesses.

## Cause #1 — register-coalescer copy-hint (FIXED)

**Mechanism** (asserts `-debug-only=regalloc` on the minimal repro, two sequential `__mulsi3` calls):

```
1344B  %674 = COPY $rc3            ; read of the 1st __mulsi3 result out of the imaginary return reg
       Considering merging %674 with $rc3   -> "Can only merge into reserved registers" (refused; $rc3 not reserved)
1552B  undef %657.sublo = COPY %674          ; folded into an Imag16 PAIR (sub-register copy) ...
       Considering merging to Imag16 with %674 in %657:sublo -> Success
       updated: 1344B  undef %657.sublo = COPY $rc3          ; ... rewriting the def to read $rc3 directly
...    %657 lives [1344r,5936r) — SPANS the 2nd __mulsi3 (JSR ... implicit-def $rc3, mos_csr regmask)
```

The fold pulls the `COPY $rc3` def into the pair `%657`; the pair inherits the physical-`$rc3` allocation
hint and Greedy re-binds it to `$rc2:$rc3` **across** the second `__mulsi3` that clobbers `$rc3` → a
`$x = COPY $rc3` use with no reaching def on that path. Correct at runtime only because nothing reuses
`$rc3` in the gap.

**Fix** — `MOSRegisterInfo::shouldCoalesce` refuses exactly that join:

```cpp
if (NewRC == &MOS::Imag16RegClass && (DstSubReg || SubReg)) {
  if (copiedFromClobberedPhysImag(MI->getOperand(0).getReg(), MRI, LIS) ||
      copiedFromClobberedPhysImag(MI->getOperand(1).getReg(), MRI, LIS))
    return false;
}
```

`copiedFromClobberedPhysImag(Reg)` = `Reg`'s **unique** def is `COPY $rcN` (physical `Imag8`) **and** `Reg`
is live across a call clobbering `$rcN` (`LiveIntervals::checkRegMaskInterference`). Same hook + risk
profile as the committed `0010-coalesce-rotate-ac` fix. **Correctness-safe by construction** (refusing a
coalesce only ever keeps a COPY) and tightly gated.

**Validation:** `rcundef.c` + `newton_step` verify clean `-O0/-O1/-Os` (a16 + xy16); newton demo value
unchanged (`0x4D8B`, MAME + bsnes-jg); corpus differential green; **4/34** corpus programs change bytes
(all verify-clean + differential-identical), the other **30** byte-identical. Shipped: fork commit
`f1af264` (fix + `dev/run.sh rcundef` gate + lit test `0015` + dropped the `newton` `KNOWN_ISSUES` XFAIL);
newton ROM rebuilt + redeployed to [biohack.net/snes/newton/](https://biohack.net/snes/newton/) (tag
`v1.0.146`); upstream PR mint-ready (`0015`, `git apply --check` clean vs pristine `c798c3141`).

## Cause #2 — RA-assigned `undef` sub-lane (DEFERRED, root-caused)

A *different* shape with no `$rcN` copy hint for `shouldCoalesce` to key on. Asserts
`-debug-only=regalloc` + `-print-after` on `lsystem_sim.c main` (`$x = COPY killed $rc11` at 6000B):

1. **It's a dead read of an `undef` high lane.** `$x` is overwritten 16 bytes later (6016B) before any use —
   a leftover use of `%1759`, a 16-bit `__mulsi3` argument whose **low byte is defined** (`$rc10 = COPY
   $rc6`) and whose **high byte is `undef`** (the `undef %N.sublo:imag16 = COPY …` sub-register idiom marks
   the sibling lane undef). The value is a genuine don't-care; the demo runs `0x79C3`.
2. **The rewriter *has* undef-marking — it's defeated.** MOS enables sub-register liveness
   (`MOSSubtarget::enableSubRegLiveness() == true`; `Imag16` has disjunct `sublo`/`subhi`), and
   `VirtRegRewriter::readsUndefSubreg` → `MO.setIsUndef(true)` exists. It misses this case because a
   **live-range-split full-pair `COPY`** (`%1759 = COPY %x`, both lanes, one def) propagates the `undef`
   `subhi` lane as a **spuriously-live** subrange — `readsUndefSubreg` finds a live subrange overlapping the
   lane and returns `false`. When the virtual sub-register read is lowered to the physical `$rc11`, the
   `undef` attribute is lost (physreg reads carry no undef flag) → the verifier rejects it.
3. **The undef-ness is path-sensitive *and* loop-carried.** Both witnesses are loops, so the lane's value at
   the read is a **PHI-def** at the loop header; the lane *is* written somewhere (a `STAImag16` on another
   path/iteration), so it is **not** globally dead either.

### Three fix attempts (all on the worktree, all reverted, shipped toolchain never touched)

All edits were isolated to `vendor/llvm-mos/llvm/lib/CodeGen/VirtRegMap.cpp` (generic CodeGen — in **no**
fork patch) and fully reverted to pristine; the Release toolchain never carried them. Each only ever marks
**more** reads `undef` (proven-undef), so it is correctness-safe *if the lane analysis is right* — the
corpus differential was the net.

1. **Path-sensitive `lanesUndefAt`** — trace a spuriously-live lane back through full-register split COPYs
   to an `undef` origin. **Bails on `isPHIDef()`** → does not clear the loop-carried witnesses.
2. **Global `laneGloballyUndef`** — scan **all** of a sub-range's value numbers (PHIs as forwarders, COPYs
   traced one hop, cycles cut by a visited-set), sidestepping the loop-PHI. Instrumented bail logging showed
   the failing values (`%1759`, `%1756`, `%1757`) bail **conservatively, not on genuine real-defs**:
   `%1756` is a **sub-register COPY def** (`dstSub=subhi`) the tracer refuses to invert, and `%1759`/`%1757`
   have a VNInfo whose **def slot is valid but maps to no instruction** (`phi=0 defValid=1` — an obscure
   split-product subrange value). (The `STAImag16` real-defs in the log are *other* vregs, correctly
   not-undef.)
3. **SplitKit `defFromParent` review** — it already drops lanes not `liveAt` the split point, but our
   `subhi` **is** live there (the undef was lost upstream and is now loop-carried), so the same undef-origin
   analysis is needed regardless of locus.

### Why it was stopped here (a deliberate trade, not a failure)

The fix is **close** — the lane really is path-undef and the blockers are tracer conservatism — but
finishing it safely needs intricate **sub-register lane-mask composition** through subreg COPYs plus
handling that obscure valid-slot/no-instruction VNInfo. A wrong lane computation there is a **silent
miscompile** the corpus might not exercise. For a **code-correct** (verifier-only) defect, shipping a
miscompile-risk change to fix a non-miscompile is the wrong trade and violates the project's
"correctness = the differential" bar. The correct fix is a genuine **generic-LLVM RA feature**
(path-sensitive, loop-aware, subreg-lane-precise `undef` propagation) — and the analysis points at
**SplitKit / InlineSpiller carrying the lane's `undef`-ness through the inserted COPY at the source** as the
right locus. Filed upstream; `lsystem_sim.c` keeps its `KNOWN_ISSUES["a16-rc-undef-ra-pure-virtual"]` XFAIL
until it lands.

## Artifacts

- Minimal repro + gate: [`examples/65816/rcundef.c`](../../examples/65816/rcundef.c) · `dev/rcundef.sh`
  (`dev/run.sh rcundef`).
- Asserts toolchain builder: `dev/asserts-clang.sh` (`build/llvm-mos-asserts`, clang+llc, `-debug-only`).
- Fork patches: `0002` (cpp, comprehensive) + `0015-321-coalesce-rc-undef.patch` (standalone, clean vs
  pristine — the upstream patch).
- XFAIL ledger: `tools/a16_fuzz.py` `KNOWN_ISSUES["a16-rc-undef-ra-pure-virtual"]` (cause #2) — `newton`
  (cause #1) dropped.
- Plan (full verification + per-attempt log):
  [`2026-06-29-a16-rc-undef-ra-machineverifier-fix.md`](../plans/2026-06-29-a16-rc-undef-ra-machineverifier-fix.md).
