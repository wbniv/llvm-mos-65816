# Eliminate build nondeterminism — pinned and fixed in Phase 1

**Status: PINNED + FIXED (Phase 1 done, 2026‑09‑15; Phase 2 verification recorded in the
verification steps below).** The mechanism is a **stale GlobalISel CSE node**: the fork's
`MOSLegalizerInfo::tryAbsoluteIndexedAddressing` rewrites every use of an 8‑active‑bit s16
offset in place without telling the legalizer's observer, so `GISelCSEInfo` keeps the rewritten
user under the hash of its *old* operand profile; a later CSE lookup for the new form hits or
misses depending on whether the old and new hashes collide modulo the FoldingSet's bucket count,
and the profile contains the parent `MachineBasicBlock` pointer, so that collision is decided by
ASLR (≈ 1/N ≈ 0.5 %). The hit/miss changes the number of virtual registers created, which shifts
every later vreg number by one, which flips the bucket order of `TwoAddressInstructionPass`'s
`SmallDenseMap<Register, TiedPairList>` (hash `= id × 37`, 4 inline buckets), which swaps the
order of the two tied-operand `COPY`s it inserts before each `SBCImag8`, which the machine
scheduler then keeps — hence `sec` moving past `tax`/`lda`. Fix = bracket each use rewrite with
`changingInstr`/`changedInstr` (the contract generic GISel follows for register replacement);
fork patch `0002`, regression test `legalizer-indexed-offset-observer.mir`. **Not
upstream-relevant**: upstream llvm-mos has `Index = Builder.buildZExtOrTrunc(S8, NewOffset)` at
that spot; the rewrite-all-uses block is the fork's own seed‑56 fix. See
[Phase 1 result](#phase-1-result-2026-09-15).

Earlier status (kept for the record): **REPRODUCED (Phase 0 done, 2026‑09‑14) — not load-dependent.** The original single
divergence was followed by 68 identical builds across five methodologies (below), which is why
this plan opened as "not yet reproduced". Phase 0 then ran 2950 builds across quiet,
Docker-loaded and generic-loaded arms and caught the flip 7 times in **all three arms**,
including the exact original `dither` diff, so the load hypothesis is ruled out and the flip is
a rare ordering tie in one shared routine — see [Phase 0 result](#phase-0-result-2026-09-14).
No visible-surface change; this is a compiler/build-determinism investigation.

## Original observation (2026-09-14)

While independently verifying the snesgfx first-frame opt-in work (unrelated), I rebuilt
`examples/snes/dither.c` twice from identical source and compared:

```
CLANG=/home/will/llvm-mos-65816-dispoptin/build/llvm-mos-install/bin/mos-clang
CFG=/home/will/llvm-mos-65816-dispoptin/build/install/bin/mos-snes.cfg
$CLANG --config "$CFG" -mcpu=mosw65816 -Os -o dither-2.sfc examples/snes/dither.c
cmp dither.sfc dither-2.sfc
# dither.sfc dither-2.sfc differ: byte 8029, line 98
```

`dither.sfc` had been built moments earlier by a loop building ~117 demos in sequence (same
toolchain, same flags, same absolute source path, one extra `-I` flag). The diff was a 4-byte
rotation (`70 252 251 220` → `252 251 220 70`), the classic signature of a zero-page/near-code
candidate set winning in a different relative order — the same shape as the original #590
report (`docs/upstream-zp-alloc-deterministic-pr.md`).

## Correction to the original claim

I told the user this was "a live nondeterministic-codegen bug, reproduced right now." That
overstated it. Follow-up reproduction attempts, all on the same toolchain and demo:

| # | Test | Runs | Result |
|---|---|---|---|
| 1 | `-S` (assembly) rebuild, standalone invocations | 8 | 1 distinct output (identical) |
| 2 | `-c` (object file) rebuild, standalone invocations | 5 | 1 distinct output (identical) |
| 3 | Re-link the *same* `.o` repeatedly | 5 | 1 distinct output (identical) |
| 4 | Full driver (`-o out.sfc`), default ASLR | 20 | 1 distinct output (identical) |
| 5 | Full driver, `setarch -R` (ASLR disabled) | 20 | 1 distinct output (identical) |
| 6 | Full driver, reproducing the exact `-I` asymmetry from the original sighting | 10×2 | 1 distinct output each side (identical, and the two sides matched each other) |

68 builds, zero reproductions. **All 68 were run in a quiet window** — the two subagents
dispatched earlier in the session (the snesgfx first-frame rework, the maze re-fold) had both
gone idle, and nothing else in the session was competing for CPU/memory/disk I/O. The original
sighting happened while both were still active, each running `dev/run.sh` gates that spin up
Docker containers. **A quiet-window retest cannot distinguish "no bug" from "a contention-
dependent bug that only shows up under load"** — it is consistent with both. This is the leading
hypothesis now (raised by the user), not confirmed, and Phase 0 below is written to test it
directly rather than assume a compiler-internal cause.

Explanations as they stood before Phase 0, in the order they were then ranked — with the
outcome:

1. ~~**Hot-tree / contention-dependent.**~~ **Ruled out by Phase 0**: the flip occurs at the same
   ~0.5 % rate in the quiet arm as under Docker or generic load. The coincidence with heavy
   session activity was just that; the 68 quiet negatives were undersampled (P(miss) ≈ 0.7),
   not evidence of a load trigger.
2. **A rare, genuinely nondeterministic tie** — **confirmed in shape, but not where predicted.**
   The #590-equivalent fix (`0021`, confirmed applied and built) is intact and `MOSZeroPageAlloc`
   output is byte-identical across variants. The tie is in the placement of `sec` relative to
   carry-independent neighbours inside `_title_blank`; see the Phase 0 result and the retargeted
   Phase 1.
3. ~~**An artifact of my own test harness.**~~ Ruled out: the committed reproducer flips with the
   same single alternate hash per demo across three independent runs and two harness variants.

## Plan

### Phase 0 — get a reliable reproducer, load condition first (required before anything else)

Build a bounded, disposable script on a `throwaway/build-nondeterminism` worktree (per the
project's investigation-worktree policy) that runs **two arms**, since the leading hypothesis is
that load, not source or ASLR, is the variable:

- **Loaded arm:** N (100+) full-driver builds of `dither.c`, run *while* genuine concurrent load
  is present — e.g. `dev/run.sh <some other demo>` looping in the background (which drives Docker
  containers, matching the original session's condition), or plain `stress-ng --cpu $(nproc)
  --io 4 --vm 2` alongside the build loop for a load source that doesn't depend on this repo's
  own tooling.
- **Quiet arm:** the same N, with no other process competing, exactly reproducing this plan's 68
  already-negative trials for a same-N baseline.

Repeat both arms for the same handful of demos this plan already used
(`dither`, plus `newton`, `lsystem`, `mandel-oop`, `gouraud`, `msquares` as higher-pressure
witnesses, since a load-dependent trigger might not be `dither`-specific).

- If the **loaded arm** shows more than one distinct hash and the **quiet arm** does not: the
  hypothesis is confirmed as load-dependent. Capture what kind of load reproduces it (Docker
  contention specifically, vs. generic CPU/IO/memory pressure) — that materially changes where
  Phase 1 looks (a race/temp-file collision under real concurrent `mos-clang` invocations, vs.
  disk/page-cache pressure corrupting a read, vs. something else).
- If **both arms** come back clean after 100+ runs each: report that back before writing another
  line of diagnosis. The honest conclusion at that point is "unreproduced under either quiet or
  loaded conditions in over `N × demos × 2` builds," and this plan should be closed as
  WON'T-FIX-UNCONFIRMED rather than guessed at further, per "don't guess — explain the gap."
- If the **quiet arm** also flips (matching the original algorithmic-nondeterminism hypothesis):
  that reopens explanation (2) above and Phase 1 proceeds as originally written, targeting
  `MOSZeroPageAlloc.cpp` and adjacent passes rather than a concurrency mechanism.

### Phase 0 result (2026-09-14)

**Reproduced. Flips in every arm, so the load hypothesis (explanation 1) is ruled out; the
algorithmic-tie hypothesis (explanation 2) stands, but the tie is not in zero-page allocation.**

Reproducer: `dev/measure-build-determinism.sh` on worktree `throwaway/build-nondeterminism-phase0`
(branch off `main` at `b6ab8b5`, hardlinked `build/llvm-mos-install` + `build/install`, no
rebuild). Same toolchain, flags and absolute source path every build; each demo's `mos-a16-only`
/ platform markers detected exactly as `dev/build.sh` does. Load sources: `stress-ng`/`stress` are
not installed on this host, so the **docker** arm runs four long-lived `llvm-mos-65816-dev`
containers (CPU spin + `dd`+`fsync` IO) plus a container create/teardown churn loop, and the
**generic** arm is a host-side stand-in (`nproc` CPU spinners, 4 `dd`+`fsync` writers, 2 `/dev/shm`
churners). Load averages: docker 20–26, generic 16–20, quiet 1.3–4.9 (the "quiet" arm shares the
box with the interactive session, so it is not idle). Three runs, 2950 builds total:

| Run | Arm | N/demo | dither | newton | lsystem | mandel-oop | gouraud | msquares |
|---|---|---|---|---|---|---|---|---|
| 1 | docker | 100 | **2 (idx 57)** | 1 | 1 | 1 | 1 | 1 |
| 1 | quiet | 100 | 1 | **2 (idx 66)** | 1 | 1 | 1 | **2 (idx 55, 75)** |
| 1 | generic | 100 | 1 | **2 (idx 65)** | 1 | 1 | 1 | 1 |
| 2 | quiet | 150 | 1 | 1 | — | — | — | 1 |
| 3 | quiet | 100 | **2 (idx 67)** | **2 (idx 1; 2–100 majority)** | 1 | 1 | 1 | 1 |

Cells are distinct-hash counts; bold = flipped, with the 1‑based build index of the minority
output. Per demo over all runs: `dither` 2/550, `newton` 3/550, `msquares` 2/450, the other three
0/300 each. Rate ≈ 0.4–0.6 % per build for the demos that flip, which is exactly why 20 quiet
`dither` runs and 68 total in the first pass missed it (P(miss at 0.5 %) ≈ 0.7).

Two facts pin the *shape* of the bug before Phase 1 starts:

1. **Every flipping demo has exactly one alternate output, and it recurs across arms and runs.**
   `newton`'s alternate `9daae578…` appeared under quiet, generic and quiet again; `dither`'s
   `dfcdeaa6…` appeared under docker and quiet; `msquares`' `bf402680…` twice. Corruption or a
   temp-file race would produce different garbage each time; a recurring single alternate is a
   two-way ordering tie.
2. **The bytes.** Run 3 kept both variants (`.bnd-capture2/quiet-{dither,newton}-*.sfc` in the
   worktree). `dither` differs in 7 bytes, `newton` in 7 bytes, at two sites 327 bytes apart in
   each ROM, both inside `_title_blank` (`examples/snes/snesgfx/title_layer.h:235`, LTO-inlined
   into every title-card demo). Site 1 is the original sighting byte-for-byte (`dither` file offset
   8029, `70 252 251 220` ↔ `252 251 220 70` in `cmp -l` octal):

   ```
   ref:  38 aa a9 90 e5 09    sec ; tax ; lda #$90 ; sbc $09
   alt:  aa a9 90 38 e5 09    tax ; lda #$90 ; sec ; sbc $09
   ref:  38 a5 06 e5 09       sec ; lda $06 ; sbc $09
   alt:  a5 06 38 e5 09       lda $06 ; sec ; sbc $09
   ```

   Only the position of `sec` moves, relative to instructions it has no dependency on (`tax`,
   `lda` write N/Z, not C). No operand, address or zero-page assignment changes. Both variants
   are semantically identical, so this is a reproducibility defect, not a miscompile.

**Consequence for Phase 1:** the mechanism is a tie in whatever orders `sec` against
independent neighbours — the pre-RA machine scheduler's tie-break, or a MOS post-RA pass that
places the carry-set for `sbc` — not `MOSZeroPageAlloc.cpp`, whose output (ZP addresses) is
byte-identical across variants. The Phase 1 "quiet arm also flipped" branch below still applies
(assertions build, `-print-after` diffs across flipping runs), but its first suspect list should
be replaced by the `sec`-placement site; reduce to `_title_blank` alone, since it is the only
function that ever differed. `-mllvm -zp-avail=0` is still a cheap first check that ZP allocation
is uninvolved.

Wall-clock note: run 1's generic arm reports 13728 s because the laptop suspended mid-arm
(journal: `Operation 'suspend' finished` at 10:19:55 local); its last live checkpoint was
1510 s at 80/100. The suspend did not change any hash.

### Phase 1 — pin the mechanism (retargeted 2026‑09‑14 after Phase 0)

Phase 0 settled the branch: the quiet arm flips, the load branch is not taken, and the original
suspect (`MOSZeroPageAlloc.cpp`) is exonerated by the bytes — ZP addresses are identical across
variants; only the position of `sec` relative to carry-independent neighbours changes. The
untaken load branch (temp-file races, cgroup throttling, `strace` of concurrent invocations) is
dropped from this plan.

**Target: whatever orders a carry-set (`sec`) against independent instructions in
`_title_blank`.** Do not guess the pass; find it mechanically, in this order:

1. **IR pipeline or codegen?** `_title_blank` is LTO-inlined into every title-card demo, so the
   flip could originate in the LTO IR pipeline (instruction order in the merged module) or in
   codegen. Split it: build `dither` once with `-Wl,--save-temps` (or the fork's equivalent) to
   capture the post-LTO, pre-codegen bitcode, then run `llc` on that fixed `.bc` ~200 times with
   `dev/measure-build-determinism.sh`-style hashing. If `llc` alone flips → codegen (step 2). If
   it never flips → the divergence is upstream of `llc`: re-run the full driver ~200 times with
   `--save-temps` and `diff` the saved `.bc`/`.ll` of a flipping build against the reference to
   find the first differing IR, which names the IR pass.
2. **First divergent pass.** With the flip localised to `llc`, run ~200 `llc` invocations on the
   fixed `.bc` with `-mllvm -print-after-all` (assertions build, `dev/run.sh asserts-build`, so
   `-debug-only` is available for step 3), keep only the runs whose ROM hash is the alternate, and
   `diff` their pass-by-pass dumps against a reference run. The **earliest pass whose output
   differs** is the site. Given the shape (`sec` reordered past `tax`/`lda #imm`), the likely
   candidates are the pre-RA `machine-scheduler` (a tie between two ready SUnits broken by
   something pointer-derived), the MOS carry-set materialisation (`LDCImm`/`SetC`-style lowering —
   see `docs/upstream-ldcimm-set-lowering-pr.md` for the fork's prior work on that path), or a
   GISel combiner producing the instructions in use-list order that itself came from a
   pointer-keyed container. The dump diff decides; don't pre-commit.
3. **The container.** In the named pass, find the iteration or comparison whose result depends
   on pointer value or allocation order (`DenseMap`/`DenseSet`/`SmallPtrSet` keyed by
   `MachineInstr *`/`SUnit *`/`Value *`, a `std::sort` with a non-total comparator, or a
   `SmallSet` past its inline capacity — the `0021` lesson). Confirm with `-debug-only=<pass>` on
   a flipping vs reference run that the recorded decision differs there and only there.

Cheap sanity checks that cost nothing and remove doubt: `-mllvm -zp-avail=0` still flips (ZP
allocation truly uninvolved); the flip reproduces on `newton` and `msquares` from the same
`_title_blank` bytes (it is one bug, not three).

**Suggested dispatch tier: T4** — unknown root cause in a compiler pass, where a wrong turn (fixing
a symptom in the wrong pass) is expensive. Compiler-changing worktree (own `vendor/` + warm
`build/`), since steps 2–3 need an assertions build. Ranking itself is the orchestrator's call.

### Phase 1 result (2026‑09‑15)

Worktree `wt/build-nondeterminism-phase1` (`/home/will/llvm-mos-65816-bnd-phase1`, own
`vendor/` + warm `build/`, plus an assertions `llc` built with
`cmake --build build/llvm-mos-asserts --target llc` — the full `asserts-build` distribution was
not needed and would have taken ~2 h under the shared box's load). Steps as run, in the plan's
order:

1. **IR pipeline or codegen → codegen.** `-Wl,--save-temps` on `dither` captured
   `dither.sfc.0.5.precodegen.bc` (the post-LTO module; the build's ROM hash equals the Phase 0
   reference `65ebf8c0…`). `llc` on that fixed bitcode with the exact flags lld passes to the LTO
   backend (`-O2 -mcpu=mosw65816 -function-sections -data-sections -force-precise-rotation-cost
   -jump-inst-cost=6 -force-loop-cold-block -phi-node-folding-threshold=0 -speculate-blocks=0
   -align-large-globals=false -disable-spill-hoist -lsr-complexity-limit=10000000 -zp-avail=224`)
   reproduces lld's codegen instruction-for-instruction (objdump diff of `llc.o` vs
   `dither.sfc.lto.o`: 0 lines) and **flips by itself: 600 runs → 597 `a9a1b43f…` / 3
   `cc10db2b…`**, the asm diff being exactly the two `sec` moves in `_title_blank`. The IR
   pipeline is not involved.
2. **First divergent pass.** 600 `llc` runs with `-print-after-all -filter-print-funcs=_title_blank`
   (kept the first dump per distinct hash; 1 alternate in the first 66). Per-pass diff: the
   **Legalizer** is the first pass whose dump differs — but only by virtual-register numbering
   (canonicalising vreg numbers by order of appearance gives a 0‑line diff): the alternate run
   allocated **one vreg fewer** (`%464` vs `%465`), every vreg from `%289` on shifted by −1. The
   first pass whose *canonicalised* output differs is **`twoaddressinstruction`** (#56): the two
   `COPY`s it inserts for `SBCImag8`'s tied `ac`/`cc` operands come out in swapped order
   (`COPY cc; COPY ac` vs `COPY ac; COPY cc`). That is a deterministic function of the vreg
   numbers: `TiedOperandMap = SmallDenseMap<Register, TiedPairList>` (4 inline buckets,
   `DenseMapInfo<unsigned>` hash `id × 37`) — site 1's keys are `%493`/`%380` in the reference
   (buckets 1/0 → `cc` first) and `%492`/`%379` in the alternate (buckets 0/3 → `ac` first).
   Everything downstream (coalescer, machine scheduler, RA, `sec` placement) follows from that
   COPY order; none of those passes is nondeterministic on its own.
3. **The container (why the Legalizer creates one vreg more or less).** `-enable-cse-in-legalizer=0`
   removes the flip entirely (**1000/1000 identical**, P(0 flips at 0.5 %) ≈ 0.7 %), so the
   nondeterminism lives in the legalizer's CSE. With the assertions `llc`,
   `-debug-only=cseinfo` (600 runs, 2 alternates in 110) and `-debug-only=legalizer` (300 runs, 1 in
   42) traces of an alternate run were diffed against a reference run. Inside `_title_blank`, while
   legalizing `G_STORE %68, %74` with `%74 = G_PTR_ADD %70, %64` (a runtime 16‑bit base plus an
   s16 offset whose known bits fit in 8), `tryAbsoluteIndexedAddressing` takes its known-bits
   branch: `Lo = buildTrunc(S8, %64)` (CSE hit on the existing `%107 = G_TRUNC %64`),
   `%199 = G_CONSTANT 0`, `%200 = G_MERGE_VALUES %107, %199`, then **rewrites every other use of
   `%64` to `%200` with a bare `MO.setReg()`** — including `%69 = G_TRUNC %64` in the store's block —
   and, because the base is not absolute, returns `false`. `selectIndirectAddressing` then needs
   an s8 index for `%200` and calls `buildZExtOrTrunc(S8, %200)`: a CSE lookup for
   `G_TRUNC %200` in that block. `%69` *is* now `G_TRUNC %200`, but its FoldingSet node was
   inserted under the profile hash of `G_TRUNC %64` and never re-profiled (no
   `changingInstr`/`changedInstr`), so the lookup walks the wrong bucket — a **miss** (reference:
   `.. New MI: %201 = G_TRUNC %200`, `G_STORE_INDIR_IDX …, %201`) unless the two hashes happen to
   land in the same bucket, in which case the chain walk re-profiles the stale node, finds it
   equal, and **hits** (alternate: `CSEInfo::Found Instr %69:_(s8) = G_TRUNC %200:_(s16)`,
   `G_STORE_INDIR_IDX …, %69`). The profile includes `MBB` via `addNodeIDMBB` (`ID.AddPointer`),
   so the bucket collision is a function of heap addresses — ASLR — at ≈ 1/NumBuckets, matching
   the measured 0.4–0.6 %. Both outcomes are semantically identical (`%69 ≡ %201 ≡ trunc(%200)`),
   and the artifact combiner folds both truncs away, so the *only* residue is the one extra vreg
   from the miss. Code: `vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp`
   `tryAbsoluteIndexedAddressing`, the seed‑56 known-bits block (fork patch `0002`; upstream has
   `Index = Builder.buildZExtOrTrunc(S8, NewOffset)` there and no use rewriting).
4. **Sanity checks.** `-zp-avail=0`: 600 runs → 597/3, same two `sec` moves (ZP allocation
   uninvolved). `newton`: 600 runs → 596/4; `msquares`: 600 → 597/3 — both at the identical
   `_title_blank` site (`.LBB9_5` / `.LBB10_5`: `sec; tax; lda #144; sbc __rc9` ↔
   `tax; lda #144; sec; sbc __rc9`, plus the loop-header `sec; lda __rc6; sbc` pair). One bug.

**Fix (Phase 2, same worktree).** Bracket each rewrite with the legalizer's observer:

```cpp
        for (MachineOperand &MO :
             llvm::make_early_inc_range(MRI.use_operands(NewOffset))) {
          MachineInstr &UseMI = *MO.getParent();
          if (&UseMI == TruncMI)
            continue;
          Helper.Observer.changingInstr(UseMI);
          MO.setReg(Explicit16);
          Helper.Observer.changedInstr(UseMI);
        }
```

`changedInstr` makes `GISelCSEInfo` erase and re-record the user (consistent bucket) and
re-queues it for legalization, which is the same contract `LegalizationArtifactCombiner::
replaceRegOrBuildCopy` and `GISelChangeObserver::changingAllUsesOfReg` follow. No heuristic
changes. Regenerated `patches/llvm-mos/0002-321-accum16.patch` (round-trip PASS; only this hunk
plus line offsets changed; no foreign-patch symbols absorbed).

**Deterministic output is a third, equivalent shape.** With the fix, the re-queued `G_TRUNC` is
combined by the artifact list before `selectIndirectAddressing` runs, so the fixed compiler's
`_title_blank` takes the *alternate* form at site 1 (`tax; lda #144; sec; sbc`) and the
*reference* form at site 2 (`sec; lda __rc6; sbc`), and `_title_glyph_band` — same code path,
its own stale node, never observed flipping in 600 runs because its collision odds differ —
also moves one `sec` (`lda zp_stk+2; sec; sbc` → `sec; lda zp_stk+2; sbc`). Same instruction
count, only `sec` positions relative to carry-independent neighbours; ROM size unchanged.

**Regression guard.** `llvm/test/CodeGen/MOS/legalizer-indexed-offset-observer.mir`
(`REQUIRES: asserts`; carried in `0002` via `dev/regen-patch.sh`'s `TESTRELS`). A flaky
FileCheck on the legalizer's output would be red only ≈ 98 % of the time pre-fix, so the test
instead makes the stale node *survive* the legalizer — under `+mos-a16` an s16 `G_ADD` user of
the offset is legal and is legalized (bottom-up) before the store rewrites it — and runs
`-run-pass=legalizer,mos-combiner`: the post-legalizer combiner's end-of-pass
`CSEInfo::verify()` then fails deterministically on the pre-fix compiler:

```
CSEMap mismatch, InstrMapping has MIs without corresponding Nodes in CSEMap:
%7:_(s16) = G_ADD %10:_, %2:_
llc: .../GlobalISel/Combiner.cpp:346: bool llvm::Combiner::combineMachineInstrs():
Assertion `false && "CSEInfo is not consistent. Likely missing calls to observer on mutations."' failed.
```

and passes (plus the FileCheck lines pinning the rewritten `G_ADD` operand and the shared
`G_TRUNC` index) on the fixed one.

**Generic-LLVM note (no change made).** `TwoAddressInstructionPass` emitting the tied-operand
`COPY`s in `SmallDenseMap<Register,…>` iteration order makes instruction order depend on vreg
numbers modulo 4. That is deterministic for a given input and therefore not a bug upstream
would take, but it is the amplifier that turned a one-vreg CSE difference into a byte
difference; any future vreg-count nondeterminism in this backend will surface the same way.

### Phase 2 — fix and verify (only after Phase 1 pins a mechanism)

Same bar as the `0021` patch: an order-preserving container swap or equivalent, never a
heuristic change. Verify:

1. The Phase 0 reproducer script, re-run at the same N, shows exactly 1 distinct hash for every
   demo it previously flipped on.
2. Corpus differential (`dev/run.sh corpus`, `corpus-a16`) unchanged pass counts.
3. `-verify-machineinstrs` clean corpus-wide (unaffected by this class of fix, but cheap to
   confirm).
4. If the fix lands in `vendor/llvm-mos`, regenerate the relevant fork patch and sanity-check it
   didn't absorb unrelated hunks (`grep -c <foreign-symbol>` per the project's patch-regen
   discipline).

## Files (anticipated)

| File | Purpose |
|---|---|
| `dev/measure-build-determinism.sh` (committed on `throwaway/build-nondeterminism-phase0`; it reproduced, so it earns a durable path) | Phase 0 reproducer: N builds per demo per load arm (`quiet`/`docker`/`generic`), distinct-hash counts, first-flip index, keeps the reference and every divergent ROM for `cmp`/disassembly |
| `vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp` → `patches/llvm-mos/0002-321-accum16.patch` | the fix: observer-bracketed use rewrite in `tryAbsoluteIndexedAddressing` (Phase 1 result) |
| `vendor/llvm-mos/llvm/test/CodeGen/MOS/legalizer-indexed-offset-observer.mir` (carried in `0002`) | regression test: stale CSE node survives to the post-legalizer combiner, whose `CSEInfo::verify()` asserts pre-fix |
| `dev/regen-patch.sh` | `TESTRELS` gains the new test so `0002` keeps carrying it |
| this plan | updated in place as each phase completes or the investigation closes |

## Verification steps

1. Phase 0 reproducer run, N≥300 per demo, across at least 6 demos: raw distinct-hash counts
   recorded here.

    Run 1 (`--n 100 --arms "docker quiet generic"`, 6 demos, 1800 builds), summary as printed:

    ```
    ARM      DEMO             N  DISTINCT  FIRST-DIFF    N-DIFF
    docker   dither         100         2          57         1
    docker   newton         100         1           -         0
    docker   lsystem        100         1           -         0
    docker   mandel-oop     100         1           -         0
    docker   gouraud        100         1           -         0
    docker   msquares       100         1           -         0
    quiet    dither         100         1           -         0
    quiet    newton         100         2          66         1
    quiet    lsystem        100         1           -         0
    quiet    mandel-oop     100         1           -         0
    quiet    gouraud        100         1           -         0
    quiet    msquares       100         2          55         2
    generic  dither         100         1           -         0
    generic  newton         100         2          65         1
    generic  lsystem        100         1           -         0
    generic  mandel-oop     100         1           -         0
    generic  gouraud        100         1           -         0
    generic  msquares       100         1           -         0
    ```

    Run 2 (`--n 150 --arms quiet --demos "dither newton msquares"`, 450 builds): all three
    `DISTINCT 1`. Run 3 (`--n 100 --arms quiet`, 6 demos, 600 builds):

    ```
    quiet    dither         100         2          67         1
    quiet    newton         100         2           2        99
    quiet    lsystem        100         1           -         0
    quiet    mandel-oop     100         1           -         0
    quiet    gouraud        100         1           -         0
    quiet    msquares       100         1           -         0
    ```

    Per-demo totals: dither 550, newton 550, msquares 450, lsystem/mandel-oop/gouraud 300 each.
    **PASS** for the ≥300-per-demo bar; 2950 builds total. Three demos flipped, three never did.

2. If reproduced: the flip's exact first-occurrence index and recurrence rate recorded.

    First occurrences: docker/dither 57; quiet/newton 66; quiet/msquares 55 (again at 75);
    generic/newton 65; run 3 quiet/dither 67; run 3 quiet/newton build 1 (the rare variant came
    first; 2–100 were the majority). Recurrence: dither 2/550, newton 3/550, msquares 2/450 —
    ≈ 0.4–0.6 % per build, stable across arms rather than one-off, and always the same single
    alternate hash per demo (`dfcdeaa6ce7ac284`, `9daae578555f5534`, `bf40268046990da8`).
    Byte diff and disassembly in [Phase 0 result](#phase-0-result-2026-09-14). **PASS**.
3. If pinned (Phase 1): the specific container/pass identified, with the `-print-after` diff
   showing the actual order difference.

    Pass/container: **Legalizer → `GISelCSEInfo` FoldingSet, stale node from an un-notified
    `MO.setReg()` in `MOSLegalizerInfo::tryAbsoluteIndexedAddressing`**; amplifier:
    `TwoAddressInstructionPass`'s `SmallDenseMap<Register, TiedPairList>`. `llc` alone on the
    fixed post-LTO bitcode (release, main's `build/llvm-mos/bin/llc`):

    ```
    done N=600 distinct=2
        597 a9a1b43f48d4e49e
          3 cc10db2b8501c760
    $ diff variant-a9a1b43f48d4e49e.s variant-cc10db2b8501c760.s
    4698d4697
    < 	sec
    4700a4700
    > 	sec
    4908d4907
    < 	sec
    4909a4909
    > 	sec
    ```

    `-print-after-all -filter-print-funcs=_title_blank`, per-pass diff (raw, then with vreg
    numbers canonicalised by order of appearance):

    ```
    FIRST DIVERGENT PASS #30: Legalizer (legalizer)      (raw: %454->%453 ... one vreg fewer)
    ref: max vreg %465, distinct 256; alt: max vreg %464, distinct 256
    canonicalised diff lines: 0
    #30..#55 : renumber-only
    #56 Two-Address instruction pass (twoaddressinstruction): CANON-DIFF
    -  %v24:cc = COPY %v13:cc
    -  %v25:ac = COPY %v14:ac
    -  %v25:ac, %v24:cc, dead %v26:vc = SBCImag8 %v25:ac(tied-def 0), %v23:imag8, %v24:cc(tied-def 1)
    +  %v24:ac = COPY %v14:ac
    +  %v25:cc = COPY %v13:cc
    +  %v24:ac, %v25:cc, dead %v26:vc = SBCImag8 %v24:ac(tied-def 0), %v23:imag8, %v25:cc(tied-def 1)
    ```

    Tied-operand keys at that site: ref `%493`(ac)/`%380`(cc) → buckets `(id*37)&3` = 1/0 →
    `cc` processed first; alt `%492`/`%379` → 0/3 → `ac` first. The seed, from the assertions
    `llc` with `-debug-only=cseinfo` (600 runs, alternate at run ≤ 9) — reference vs alternate at
    the same point of `_title_blank`'s legalization:

    ```
    ref: CSEInfo::Found Instr %107:_(s8) = G_TRUNC %64:_(s16)      <- Lo = buildTrunc(S8, %64)
         CSEInfo::Recording new MI G_CONSTANT
         CSEInfo::Recording new MI G_TRUNC                            <- MISS: new %201 = G_TRUNC %200
    alt: CSEInfo::Found Instr %107:_(s8) = G_TRUNC %64:_(s16)
         CSEInfo::Recording new MI G_CONSTANT
         CSEInfo::Found Instr %69:_(s8) = G_TRUNC %200:_(s16)        <- HIT on the stale node
    ```

    (`%69` was registered as `G_TRUNC %64`; nothing re-recorded it before this lookup — the
    legalizer trace shows no `Changed MI` for it.) `-enable-cse-in-legalizer=0`: `done N=1000
    distinct=1`. **PASS.**
4. If fixed (Phase 2): reproducer 1/1 for every previously-flipping demo; corpus/verify results
   pasted per the steps above.

    Fixed toolchain (worktree `wt/build-nondeterminism-phase1`, `clang-23` rebuilt, behaviour
    confirmed by the new deterministic hashes). Assertions `llc`, fixed bitcode:
    `done N=600 distinct=1 / 600 5f46cd1535c38f96`. Reproducer:

    ```
    $ dev/measure-build-determinism.sh --n 300 --arms quiet --demos "dither newton msquares"
    ARM      DEMO             N  DISTINCT  FIRST-DIFF    N-DIFF
    quiet    dither         300         1           -         0
    quiet    newton         300         1           -         0
    quiet    msquares       300         1           -         0
    ```

    Corpus (fixed toolchain): `dev/run.sh corpus` **`==> corpus: 63/63 passed`**; `dev/run.sh
    corpus-a16` **`==> corpus-a16: 62/62 passed, 0 xfail`** (both unchanged from the pre-fix counts). `-mllvm -verify-machineinstrs` over all 138 demos + 120 corpus
    slices, pre-fix vs post-fix toolchain: `PASS=246 FAIL=12` both, **identical PASS/FAIL sets**
    (the 12 are unrelated: missing generated asset headers, non-standalone video units, and the
    pre-existing `unable to legalize G_MERGE_VALUES s32` in `bankwalk`/`farptrcmp`/`farspill`).
    ROM byte comparison pre-fix vs post-fix, same flags (pre-fix toolchain = this worktree with
    the hunk reverted, since main's install was rebuilt by another session mid-run):

    ```
    built=258 different=114 build-failed=12      (12 = the same environment failures)
    corpus slices: 120/120 IDENTICAL
    demos: 12 IDENTICAL, 114 DIFFERENT
      110 x  7 bytes, 2 hunks, pure permutation: one `sec` past `lda`/`tax`   (= the two known sites)
      n-body     10 bytes, 3 hunks, pure permutation of `sec`/`clc` past `lda`/`tax`
      smulorbit  21 bytes, 6 hunks, pure permutation of `sec`/`clc` past `lda`/`ldy`/`sta`/`tax`
      mulov64    52 bytes: main swaps the roles of __rc6/__rc7 throughout (+ the 2 sec moves)
      fft      13312 bytes: main 1731 -> 1726 insns (a tay/phy .. ply save pair gone, static-stack
                            offsets shift by 8; every later address moves) (+ the 2 sec moves)
    ```

    So the corpus is byte-identical; the demos are **not** "one of the two known variants" but
    a third, deterministic shape (see Phase 1 result), and in `fft`/`mulov64` the re-queued users
    change `main` beyond `sec` placement. Those four demos were run through their own
    differential gates on the fixed toolchain — all **PASS**, host == bsnes-jg == MAME:
    `fft 0x6D7A`, `mulov64 0x3A69`, `n-body 0xCC65`, `smulorbit 0xD81B`. `llvm/test/CodeGen/MOS`
    on the assertions tree (tools built: llc opt llvm-mc llvm-objdump llvm-readelf llvm-readobj
    FileCheck not count split-file): fixed `llc` 83/86 pass, failing = `shift-rotate.ll`,
    `legalizer.mir`, `scavenger.mir` (pre-existing fork divergences); pre-fix `llc` the same three
    plus `legalizer-indexed-offset-observer.mir` (red). Regression test via `llvm-lit`:

    ```
    pre-fix : FAIL: LLVM :: CodeGen/MOS/legalizer-indexed-offset-observer.mir
              CSEMap mismatch, InstrMapping has MIs without corresponding Nodes in CSEMap:
              %7:_(s16) = G_ADD %10:_, %2:_
              Assertion `false && "CSEInfo is not consistent. Likely missing calls to observer on mutations."'
    fixed   : PASS: LLVM :: CodeGen/MOS/legalizer-indexed-offset-observer.mir   Passed: 1 (100.00%)
    ```

    `dev/regen-patch.sh`: `RESULT: PASS — 0002 round-trips`; `git diff` of `0002` = this hunk +
    line offsets; foreign-symbol grep (`GlobalBenefit`, `BRK_Immediate`, `setLexMotorolaIntegers`,
    `branch target out of range`) 0 in both old and new `0002`. **PASS** (with the shape caveat
    above stated, not hidden).
5. ~~If never reproduced after Phase 0: this plan closed as WON'T-FIX-UNCONFIRMED.~~ Not
   applicable — reproduced (step 1). Phase 1 is next; Phase 0's throwaway worktree
   (`/home/will/llvm-mos-65816-bnd-phase0`) was **retained** until Phase 1 started because its
   untracked `.bnd-capture2/` holds the captured reference/alternate ROM pairs that Phase 1 step 1
   starts from (regenerating them costs ~200 builds per demo at the 0.5 % rate).

## Landing record (2026‑09‑15)

- `wt/build-nondeterminism-phase1` commit `8cedb22` cherry-picked onto `main` as `7899355`; the fix hunk and
  the MIR test applied to `main`'s live `vendor/` tree by hand (the worktree's vendor predates the 2026‑09‑14
  fork-patch followups, so the tree itself was not moved), then `dev/regen-patch.sh` regenerated `0002`
  byte-identical to the cherry-picked patch — patch and vendor agree.
- `main`'s toolchain rebuilt with the fix (`dev/run.sh toolchain`); the released
  `20260914-f9711be` package predates the fix and still carries the ~0.5 % `sec` flip — the next release
  picks it up. A full 138-demo gate sweep on the fixed toolchain remains open (corpus, corpus-a16 and the
  four demos whose `main` changed beyond the `sec` permutation were gated; see Phase 1 result).
- Both throwaway worktrees (`bnd-phase0`, `bnd-phase1`) are disposable now that the fix is on `main`.
