# Eliminate build nondeterminism — reproduced in Phase 0, mechanism not yet pinned

**Status: REPRODUCED (Phase 0 done, 2026‑09‑14) — not load-dependent.** The original single
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
0/300 each. Rate ≈ 0.4–0.6 % per build for the demos that flip, which is exactly why 20 quiet
`dither` runs and 68 total in the first pass missed it (P(miss at 0.5 %) ≈ 0.7).

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
| `vendor/llvm-mos/llvm/lib/Target/MOS/...` (TBD, only if Phase 1 pins a MOS-specific site) | the fix, if any |
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
    ≈ 0.4–0.6 % per build, stable across arms rather than one-off, and always the same single
    alternate hash per demo (`dfcdeaa6ce7ac284`, `9daae578555f5534`, `bf40268046990da8`).
    Byte diff and disassembly in [Phase 0 result](#phase-0-result-2026-09-14). **PASS**.
3. If pinned (Phase 1): the specific container/pass identified, with the `-print-after` diff
   showing the actual order difference.
4. If fixed (Phase 2): reproducer 1/1 for every previously-flipping demo; corpus/verify results
   pasted per the steps above.
5. ~~If never reproduced after Phase 0: this plan closed as WON'T-FIX-UNCONFIRMED.~~ Not
   applicable — reproduced (step 1). Phase 1 is next; Phase 0's throwaway worktree
   (`/home/will/llvm-mos-65816-bnd-phase0`) is **retained** until Phase 1 starts because its
   untracked `.bnd-capture2/` holds the captured reference/alternate ROM pairs that Phase 1 step 1
   starts from (regenerating them costs ~200 builds per demo at the 0.5 % rate).
