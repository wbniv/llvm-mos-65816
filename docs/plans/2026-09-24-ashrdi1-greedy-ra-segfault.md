# Greedy RA segfault in `SplitEditor::enterIntvAfter` on `ashrdi-1.c` (patch 0040)

**Date:** 2026‑09‑24 · **TODO:** M2 item "Greedy RA segfault in `SplitEditor::enterIntvAfter` on
`ashrdi-1.c` (`constant_shift`), `mosw65816 -Os`, project toolchain only" ·
**Branch:** `throwaway/ashrdi1-ra-segfault` (investigation worktree; see `~/CLAUDE.md`
"Worktree-based feature workflow").

No visible surface (compiler backend change), so no mockups.

## The failure

```text
$ build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 -Os -w \
    -c vendor/c-torture/execute/ashrdi-1.c -o /tmp/ashrdi-1.o
PLEASE submit a bug report ...
 #4  SplitEditor::enterIntvAfter (SplitKit.cpp)
 #5  SplitEditor::splitRegOutBlock
 #6  RAGreedy::splitAroundRegion  <- doRegionSplit <- tryRegionSplit <- trySplit
```

Found 2026‑09‑23 when `tools/torture_filter.py` was re-run for patch 0038 and `ashrdi-1`
dropped out of scope; it was in scope on 2026‑06‑26.

## Step 1 — which configurations fail (establish the blast radius)

Matrix over `-mcpu`, `-O` level and `+mos-a16`, project toolchain
`build/llvm-mos-install/bin/mos-clang`:

```text
cpu=mosw65816 -O0 feat=''    -> ok        cpu=default6502 -O0 -> ok
cpu=mosw65816 -O0 feat='a16' -> ok        cpu=default6502 -O1 -> ok
cpu=mosw65816 -O1 feat=''    -> ok        cpu=default6502 -O2 -> ok
cpu=mosw65816 -O1 feat='a16' -> ok        cpu=default6502 -Os -> ok
cpu=mosw65816 -O2 feat=''    -> ok
cpu=mosw65816 -O2 feat='a16' -> ok
cpu=mosw65816 -Os feat=''    -> CRASH(rc=139)
cpu=mosw65816 -Os feat='a16' -> ok
```

Exactly one cell: **`mosw65816`, `-Os`, default (non‑`+mos-a16`)**. `mos6502` never fails and
`+mos-a16` never fails, so the trigger is the 65816-without-`a16` register/instruction shape
acting on the `optsize` IR that `-Os` produces.

## Step 2 — llc-level reproducer

`-Os` only affects the *front end*: the IR it emits carries `optsize`. Feeding that IR to the
project `llc` (`build/llvm-mos/bin/llc`, same vendor state, no assertions):

```text
llc -O0 -mcpu=mosw65816 ashrdi-Os.ll -> rc=0
llc -O1 -mcpu=mosw65816 ashrdi-Os.ll -> rc=139
llc -O2 -mcpu=mosw65816 ashrdi-Os.ll -> rc=139
llc -O3 -mcpu=mosw65816 ashrdi-Os.ll -> rc=139
llc -O2 -mcpu=mosw65816 -mattr=+mos-a16 -> rc=0
```

So it is a pure backend fault, reproducible from IR, and `llvm-reduce` applies.
`llvm-reduce` took the 446-line module to **96 lines**: `@constant_shift` with a 48-case
`switch` (which becomes a jump table) over `i16`, seven `ashr i64` arms and a phi.

It also survives a MIR round trip — `llc -stop-before=greedy` then
`llc -start-before=greedy` on the resulting `.mir` crashes identically, which is what makes a
`.mir` regression test possible.

## Step 3 — what `enterIntvAfter` actually faults on

```cpp
SlotIndex SplitEditor::enterIntvAfter(SlotIndex Idx) {
  Idx = Idx.getBoundaryIndex();
  VNInfo *ParentVNI = Edit->getParent().getVNInfoAt(Idx);
  if (!ParentVNI) return Idx;
  MachineInstr *MI = LIS.getInstructionFromIndex(Idx);
  assert(MI && "enterIntvAfter called with invalid index");   // <- Release: no assert
  VNInfo *VNI = defFromParent(OpenIdx, ParentVNI, Idx, *MI->getParent(), ...);
```

The installed toolchain has **no assertions**, so the `assert(MI && ...)` is compiled out and
`*MI->getParent()` dereferences null. The proximate cause is therefore settled without any
further work: **`LIS.getInstructionFromIndex(EnterAfter.getBoundaryIndex())` returns null** —
`EnterAfter` names a `SlotIndexes` list entry that carries no instruction (an MBB-start entry,
or an entry whose instruction was erased without its index being reclaimed).

`EnterAfter` is `Cand.Intf.last()` from `RAGreedy::splitAroundRegion` — the last interference
slot for the candidate physreg in that block.

## Step 4 — the reduced case widens the blast radius

The original `-Os` matrix said "65816 only". On the **reduced** IR that is false — the
reduction removed the noise that was hiding it:

| `llc -O2` on `red.ll` | `mos6502` | `mos65c02` | `mosw65816` |
|---|---|---|---|
| `build/0030-claude-review/llc-pristine-assert` (pristine upstream) | abort (`Remaining virtual register … dead early-clobber %…:imag16 = STStk`) | abort (same) | abort (same) |
| `build/0030-claude-review/llc-final` (upstream-shape stack, no 0001/0002) | ok | ok | ok |
| `build/0030-claude-review/llc-0038` (same + 0038) | ok | ok | ok |
| `build/llvm-mos/bin/llc` (**live vendor state**) | ok | **rc=139** | **rc=139** |

So:

- The fault is **not** `+mos-a16`-specific and not even 65816-specific — `mos65c02` reproduces.
  The 6502/65c02 pre-greedy MIR differs by two instructions (`JMP`→`BRA`, `LDImm 0`→`LDZ`);
  that is a register-pressure nudge, not a structural difference, which is why the 6502 leg
  survives by luck rather than by design.
- The pristine upstream abort is the *unrelated* spill-hoist defect that patch 0033 fixes
  (`llc` never gets the driver's `-disable-spill-hoist`), so pristine cannot be used as a
  clean baseline here.
- `llc-final`/`llc-0038` carry every generic-LLVM patch in the stack (0025, 0028, 0029, 0033,
  0035, 0037) and are clean, so **the generic patches are not the cause**. The delta is the
  MOS directory: the two big mirrors 0001/0002 plus the older standalone MOS-dir patches.

Two more discriminators on the live `llc`, `mosw65816 -O2`:

```text
rc=0     -min-jump-table-entries=1000     (no jump table -> no crash)
rc=0     -regalloc=basic
rc=139   (default greedy)
```

The 48-case `switch` must actually become a jump table, and only *greedy* faults — consistent
with a splitting-specific invariant rather than a malformed machine function.

`%159:cc` is the interesting interval: `Cc` is a **one-register class**
(`MOSRegisterInfo.td:232`, `def Cc : MOSReg1Class<(add C)>`), chained through seven `ROR`s in
`bb.15`, while `GBR`/`CmpBrZero` terminators carry `implicit-def dead $c`. A single-register
class with fixed interference from terminators is exactly the shape that drives greedy into
region splitting.

## Hypotheses

1. **An empty basic block.** The pre-greedy MIR has `bb.3` with zero instructions
   (predecessors `bb.1`, `bb.2`; falls through to `bb.4`). An empty MBB owns exactly one
   `SlotIndexes` entry — its block-start entry, which has no instruction — so any interference
   index landing there faults. **REJECTED:** inserting an explicit `BRA %bb.4` into `bb.3` in
   the pre-greedy MIR (semantically identical, block no longer empty) still crashes
   (`rc=139` both with and without).

2. **A dangling `SlotIndex`: an instruction erased during RA whose live-range segment still
   ends at its index.** The vendor stack modifies three generic files that run inside or
   immediately before greedy — `llvm/lib/CodeGen/InlineSpiller.cpp` (patch 0033),
   `llvm/lib/CodeGen/VirtRegMap.cpp` (0028), `llvm/lib/CodeGen/TwoAddressInstructionPass.cpp`
   (0029) — plus the MOS `copyPhysReg` liveness patches 0030/0031 and the uncommitted
   `MOSRegisterInfo.cpp` liveness hunks another worker has in flight.

3. **A physreg live range reaching a block boundary.** A regunit segment that stops at the
   *next* block's start index gives `Intf.last()` a block-start entry. `RAGreedy::addSplitConstraints`
   is supposed to force `MustSpill` when `Intf.last() >= getLastSplitPoint(Number)`, so this
   requires the MOS last-split-point or the regunit range to be wrong.

## Method

Assertion build of `llc` only, from the live vendor state, so the assert names the bad index
and `-debug-only=regalloc` names the block, the register and the candidate:

- `build/0040-ra-src` — detached `git worktree` of `vendor/llvm-mos` at its HEAD
  (`8be0546128a5`), with the working-tree `llvm/lib/Target/MOS/` rsynced over it and the 29
  modified non-MOS files copied in. This reproduces the live vendor state exactly, including
  the other worker's uncommitted hunks.
- `build/0040-ra-build` — Release + `LLVM_ENABLE_ASSERTIONS=ON`,
  `LLVM_TARGETS_TO_BUILD=X86`, `LLVM_EXPERIMENTAL_TARGETS_TO_BUILD=MOS`, ccache against
  `build/.ccache`, target `llc` only. Deliberately **not** `build/newton-postra-build`, which
  another agent is using.

Attribution is then an incremental rebuild of the same build dir with one suspect reverted at
a time (one `.cpp` plus a link, not a toolchain cycle).

## Root cause

The assertion build (`build/0040-ra-build/bin/llc`, Release + assertions, built from the live
vendor state) turns the segfault into the expected assertion:

```text
llc: .../llvm/lib/CodeGen/SplitKit.cpp:746: SlotIndex llvm::SplitEditor::enterIntvAfter(SlotIndex):
     Assertion `MI && "enterIntvAfter called with invalid index"' failed.
2. Running pass 'Greedy Register Allocator' on function '@constant_shift'
 #9 llvm::SplitEditor::enterIntvAfter(llvm::SlotIndex)
#10 llvm::SplitEditor::splitRegOutBlock(...)
#11 llvm::RAGreedy::splitAroundRegion(...)
```

and `-debug-only=regalloc` names the index:

```text
Split for $rc10 in 1 bundles, intv 1.
splitAroundRegion with 2 globals.
%bb.7 [528B;9440B), uses 9152r-9152r, reg-out 1, enter after 9428d, defined in block,
      interference overlaps uses.
    enterIntvAfter 9428d: valno 0
```

`EnterAfter` is `9428d`, and `SlotIndexes` entry 9428 has **no instruction**. The trace shows
exactly how it got that way, all inside one greedy run:

```text
  rewr %bb.7  9428B:2  %910:anyi8 = COPY %911:anyi8      <- a split inserts this COPY (entry 9428 created)
  assigning %910 to $rc10: RC10LSB [9428r,9440B:0)…

  Inline spilling Anyi8:%911 …
    folded:   9428r  %910:anyi8, early-clobber %981:imag16 = LDStk %stack.25, 0
  queuing new interval: %981 [9428e,9428d:0) 0@9428e  weight:INF
  evicting $rs5 interference: Cascade 36
  unassigning %910 from $rc10: RC10LSB
  assigning %981 to $rs5: RC10LSB [9428e,9428d:0) 0@9428e RC11LSB [9428e,9428d:0) 0@9428e

  Inline spilling Anyi8:%910 …
  Coalescing stack access: %910:anyi8, dead early-clobber %981:imag16 = LDStk %stack.25, 0
```

Step by step:

1. Region splitting inserts `%910 = COPY %911` at a freshly numbered index 9428.
2. Spilling `%911` **folds** that COPY into a reload. MOS's reload hook needs a 16-bit scratch
   pointer and expresses it as an **extra virtual def**, `early-clobber %981:imag16`. This is
   deliberate llvm-mos behaviour: `getVDefInterval()` in `InlineSpiller.cpp` exists precisely
   to give such hook-created registers live intervals, and they are enqueued and allocated
   like any other virtual register.
3. `%981` is allocated to `$rs5`, i.e. `$rc10:$rc11` — it now occupies `$rc10` over
   `[9428e, 9428d)` in the allocator's interference matrix.
4. Spilling `%910` next reaches `InlineSpiller::coalesceStackAccess()`, which recognises that
   same `LDStk` as a redundant access of the slot and **erases it**
   (`LIS.RemoveMachineInstrFromMaps`, `MI->eraseFromParent()`).

`%981` is now orphaned: its only def is gone, but nothing unassigns it, so `$rc10`'s
`LiveIntervalUnion` keeps a segment over index 9428 — an index that no longer has an
instruction. When `%766` is later split with `$rc10` as the candidate, `Intf.last()` returns
`9428d`, `enterIntvAfter` looks up the instruction there, gets null, and dereferences it.

Upstream LLVM never hits this because upstream's `foldMemoryOperand` does not mint virtual
registers; **`coalesceStackAccess` was simply never taught about llvm-mos's extra-virtual-def
convention.** Patch 0033 fixed the *hoisting* end of the same disease
("the spill hook introduced virtual registers ⇒ undo"); this is the *coalescing* end.

0002 is the **trigger, not the cause** — it changes register pressure enough to reach this
sequence. The defect is a latent llvm-mos one, which is why it also fires on `mos65c02`.

## Attribution

Bisected by rebuilding only `llc` in `build/0040-ra-build`, resetting
`llvm/lib/Target/MOS/` to pristine upstream and applying subsets (the generic vendor edits left
in place throughout, since `llc-final` already proved they are not the cause):

| MOS directory contents | `mos6502` | `mos65c02` | `mosw65816` |
|---|---|---|---|
| pristine + 0001 only | rc=0 | rc=0 | rc=0 |
| pristine + 0001 + **0002 as committed at HEAD** | rc=0 | **rc=134** | **rc=134** |
| full live vendor MOS dir (0002 + every standalone patch + the other worker's in-progress `MOSRegisterInfo.cpp` hunks) | rc=0 | rc=134 | rc=134 |

So:

- **The in-progress `MOSRegisterInfo.cpp` liveness edits are not involved.** HEAD-committed 0002
  alone reproduces, and the working-tree 0002 adds nothing.
- **No standalone patch (0003, 0010, 0018–0038) is involved either** — none of them is applied in
  the middle row.
- **0002 is the trigger, not the cause.** It changes register pressure enough to reach the
  sequence; 0001 alone never does. The defect itself is in generic `InlineSpiller` interacting
  with MOS's longstanding extra-virtual-def spill hooks, which is why `mos65c02` — a CPU with no
  `+mos-a16` anything — reproduces once the case is reduced.

## Design

**Chosen:** make `coalesceStackAccess` decline to erase a stack access that carries virtual
defs other than the register being spilled. The redundant load/store simply stays and the
normal `spillAroundUses` path rewrites it — correct, just not free, and only on this rare
shape. Five lines, conservative in the project's required direction: a misclassification can
only ever *miss an optimisation*, never *cause a miscompile*. It mirrors patch 0033's design
so the two ends of the same invariant read the same way.

**Rejected:** un-assign and delete the orphaned scratch registers at the erase site.
`InlineSpiller` holds `VirtRegMap` but not `LiveRegMatrix`, so it cannot unassign a register
the allocator has already placed; removing the interval alone would leave dangling segments in
the matrix's `LiveIntervalUnion` (a use-after-free rather than a null dereference). Plumbing
the matrix into the spiller to save a redundant reload is not a trade worth making.

The fix lives in generic LLVM, so it is a new standalone patch
[`patches/llvm-mos/0040-llvm-inline-spiller-coalesce-scratch-vregs.patch`](../../patches/llvm-mos/0040-llvm-inline-spiller-coalesce-scratch-vregs.patch),
registered in `dev/toolchain.sh` after 0037. It needs **no** `dev/regen-patch.sh` entry:
`STANDALONE_MOSDIR` covers only `llvm/lib/Target/MOS/` and `TESTRELS` is an explicit
allow-list, neither of which my two files fall into, so a 0002 regen cannot absorb it.

Regression test:
`llvm/test/CodeGen/MOS/inline-spiller-coalesce-scratch-vreg.ll` (the reduced `constant_shift`,
`-verify-machineinstrs`, `mos65c02` + `mosw65816`).

### Is one site enough? — the other three erase paths in `InlineSpiller`

`InlineSpiller.cpp` removes instructions in exactly four places, and the other three already do
the bookkeeping that `coalesceStackAccess` skipped:

| Site | Handling of extra virtual defs |
|---|---|
| `coalesceStackAccess` (`:902–903`) | **none** — `RemoveMachineInstrFromMaps` then `eraseFromParent`, nothing else. This is the bug. |
| `foldMemoryOperand` (`:1118`) | Replaces `MI` with `FoldMI` and runs the full LIS update around it; the defs move to the surviving instruction. |
| `hoistAllSpills` (`:1819–1821`) | Already guarded by **patch 0033**, which refuses a hoist group whose hook produced virtual registers. |
| `eliminateRedundantSpills` → `LiveRangeEdit::eliminateDeadDefs` (`:841`, `:1356`, `:1837`) | `eliminateDeadDef` walks **every** operand: for each virtual def it calls `LIS.removeVRegDefAt(LI, Idx)` and, when the interval empties, erases the register. A scratch vreg's `[Xe, Xd)` interval is emptied, so no segment survives over the dead index. |

So `coalesceStackAccess` was the only unguarded site, and the fix is complete rather than a
point patch. (The narrower question of whether `LIS.removeInterval` on an *already assigned*
register can leave a stale `LiveRegMatrix` entry applies equally to upstream dead-def removal
and is outside this change; nothing in the validation provoked it.)

## Verification

Full record, including build hashes and residual risk:
[`docs/pr-preparations/2026-09-24/0040-validation.md`](../pr-preparations/2026-09-24/0040-validation.md).

### 1. The reduced test fails before and passes after, on the same assertion `llc`

```text
llc-before-0040 mos65c02  rc=134
llc-before-0040 mosw65816 rc=134
llc-0040        mos65c02  rc=0
llc-0040        mosw65816 rc=0
```

and the pre-fix failure is the expected assertion, not an unrelated one:

```text
llc: .../llvm/lib/CodeGen/SplitKit.cpp:746: SlotIndex llvm::SplitEditor::enterIntvAfter(SlotIndex):
     Assertion `MI && "enterIntvAfter called with invalid index"' failed.
2. Running pass 'Greedy Register Allocator' on function '@constant_shift'
```

**PASS**

### 2. `ashrdi-1.c` through the project toolchain, all 16 configurations, verifier on

`mos-clang --target=mos -mcpu=$cpu $O -w [+mos-a16] -mllvm -verify-machineinstrs -c ashrdi-1.c`

```text
mosw65816 -O0 def rc=0    mosw65816 -O0 a16 rc=0    mos6502  -O0 rc=0    mos65c02 -O0 rc=0
mosw65816 -O1 def rc=0    mosw65816 -O1 a16 rc=0    mos6502  -O1 rc=0    mos65c02 -O1 rc=0
mosw65816 -O2 def rc=0    mosw65816 -O2 a16 rc=0    mos6502  -O2 rc=0    mos65c02 -O2 rc=0
mosw65816 -Os def rc=0    mosw65816 -Os a16 rc=0    mos6502  -Os rc=0    mos65c02 -Os rc=0
```

`mosw65816 -Os def` was the segfault. **PASS (16/16)**

### 3. c-torture codegen differential, before vs after

```text
== totals ==
   1364 SAME
    266 FE-FAIL
     24 BOTH-FAIL
      1 REPAIRED      (ashrdi-1, rb=134 -> ra=0)
      1 CHANGED       (960215-1)
```

`960215-1` is a stack-slot permutation; assembled `.text` 2,541 → 2,542 bytes (+1):

```text
   text	   data	    bss	    dec	    hex	filename
   2541	     32	     48	   2621	    a3d	/tmp/960215-b.o
   2542	     32	     48	   2622	    a3e	/tmp/960215-a.o
```

0 newly broken. **PASS**

### 4. `dev/run.sh corpus-a16`

```text
==> corpus-a16: 79/79 passed, 0 xfail
```

**PASS**

### 5. `tools/torture_filter.py` brings `ashrdi-1.c` back into scope

Every changed line in both files:

```text
=== inscope.tsv ===
+ashrdi-1.c
=== unsupported.tsv ===
-ashrdi-1.c	link-other	PLEASE submit a bug report to https://github.com/llvm/llvm-project/issues/ ...
=== counts ===
inscope   before=1298 after=1299
unsupport before=486  after=485
```

One line per file and nothing else, so there is no other change to explain. **PASS**

### 6. `dev/run.sh torture --tests ashrdi-1.c` on both emulators

```text
==> torture-run: 1 test(s), -Os, explicit, default==+mos-a16==+mos-xy16 (MAME + bsnes-jg)
     ashrdi-1.c             PASS  all variants PASS (0x600D)
==> torture-run: 1 PASS, 0 FAIL, 0 SKIP, 0 XFAIL (of 1)
```

**PASS**

### 7. MOS CodeGen + MC lit suites

```text
before: Total Discovered Tests: 152   Failed: 13 (8.55%)
after:  Total Discovered Tests: 152   Failed:  9 (5.92%)
```

The four repaired are the new test plus `inline-asm-indirect-output.ll`,
`return-address-spc700.ll` and `return-frame-address.ll` — the latter three only failed because
`build/llvm-mos/bin/llc` was stale (2026‑09‑23 07:37; `dev/run.sh toolchain` builds and installs
the clang targets, not `llc`). The remaining 9 fail identically before and after and are the known
vendor-vs-upstream CHECK divergences. **PASS (no new failure)**

### 8. Patch applies in the toolchain's order, and order-independently

```text
0033 OK (4 markers)
0040 APPLIES CLEANLY ON TOP OF 0033
order-independent: OK
```

**PASS**
