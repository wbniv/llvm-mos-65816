# Eliminate build nondeterminism — one unconfirmed sighting, reproduction failed on retest

**Status: NOT YET REPRODUCED.** A single divergence was observed once. Sixty-eight follow-up
builds across five methodologies (below) all came back identical. This plan's first job is
therefore to get a reliable reproducer before diagnosing anything — see [Correction](#correction-to-the-original-claim).
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

Explanations, in order of plausibility given the above:

1. **Hot-tree / contention-dependent.** Something in the build (a temp-file path, a
   timing/`clock()`-seeded value, a race on a shared build artifact) behaves differently under
   concurrent load than in isolation. This is untested, not ruled out, and the most parsimonious
   fit for "happened once, during heavy concurrent session activity; never again in 68 quiet
   retries."
2. **A rare, genuinely nondeterministic tie** in a container the #590-equivalent fix
   (`patches/llvm-mos/0021-mos-zp-alloc-deterministic.patch`, confirmed applied and rebuilt into
   this toolchain — `MOSZeroPageAlloc.cpp` already has `GlobalBenefit`/`CalleeFreqs` as
   `MapVector` and `SCCCallees` as `SmallSetVector`) does not cover, with a flip rate too low for
   20 quiet ASLR-on runs to catch reliably. Weaker fit than (1) since it doesn't explain why the
   one sighting coincided with heavy concurrent load.
3. **An artifact of my own test harness** that I have not identified (both `-I` asymmetry and
   ASLR were ruled out, but not exhaustively).

I am not confident enough in any of these to propose a fix. Per the project's own rule, an
anomaly needs a concrete, reproducible cause before it is acted on.

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

### Phase 1 — pin the mechanism (only if Phase 0 reproduces)

**If the loaded arm alone flipped:** the mechanism is concurrency-dependent, not the compiler's
own iteration order. Look at: temp-file naming under `mos-clang`/`ld.lld` (predictable names that
could collide across simultaneous invocations — check with `strace -f -e trace=open,openat`
during a loaded-arm run for any temp path shared across processes); whether the specific demos
that flip are the ones invoking Docker-backed tooling concurrently (points at I/O/page-cache
pressure corrupting a read, or a cgroup-throttling-induced timeout somewhere treated as success);
and whether disabling whichever load source reproduced it (Docker vs. generic `stress-ng`) narrows
it to one specific contended resource.

**If the quiet arm also flipped:** follow the #590 investigation's own precedent
(`docs/upstream-zp-alloc-deterministic-pr.md`, `docs/plans/2026-08-01-...` style): build with
assertions (`dev/run.sh asserts-build`), reduce to the smallest demo/function that still flips,
and use `-mllvm -print-after=<suspect-pass>` across several flipping runs to diff the actual data
structure whose iteration order changed. Candidate suspects, roughly in the order the #590
precedent suggests checking:

- A fourth pointer-keyed container in `MOSZeroPageAlloc.cpp` beyond the three the #590-equivalent
  patch already fixed (`SCCCallees`, `GlobalBenefit`, `CalleeFreqs`) — grep for any remaining
  `DenseMap<... *, ...>` or `SmallPtrSet`/`SmallSet` (which degrades to a pointer-ordered
  `std::set` past its inline capacity — the exact `0021` lesson) in that file and its callees.
- A different pass entirely with the same symptom shape — register allocation tie-breaking,
  machine block placement, or `ld.lld`'s own symbol/section ordering when resolving weak symbols
  across the C runtime archive (crt0, `compiler-rt`) the SDK links against. Rule this in/out by
  checking whether disabling zero-page allocation (`-mllvm -zp-avail=0`) still reproduces the
  flip once Phase 0 has a working repro — if it still flips with ZP allocation off, the cause is
  elsewhere.

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
| `throwaway/build-nondeterminism` worktree, a `dev/measure-build-determinism.sh`-style script | Phase 0 reproducer (disposable if it never reproduces; promote to a committed `dev/` script if it does, per the project's investigation-worktree policy) |
| `vendor/llvm-mos/llvm/lib/Target/MOS/...` (TBD, only if Phase 1 pins a MOS-specific site) | the fix, if any |
| this plan | updated in place as each phase completes or the investigation closes |

## Verification steps

1. Phase 0 reproducer run, N≥300 per demo, across at least 6 demos: raw distinct-hash counts
   recorded here.
2. If reproduced: the flip's exact first-occurrence index and recurrence rate recorded.
3. If pinned (Phase 1): the specific container/pass identified, with the `-print-after` diff
   showing the actual order difference.
4. If fixed (Phase 2): reproducer 1/1 for every previously-flipping demo; corpus/verify results
   pasted per the steps above.
5. If never reproduced after Phase 0: this plan closed as WON'T-FIX-UNCONFIRMED, with the 68 (now
   68 + Phase-0's N) negative trials recorded as the evidence for closing it.
