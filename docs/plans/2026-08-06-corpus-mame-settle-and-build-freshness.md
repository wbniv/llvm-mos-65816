# Plain corpus: MAME settle budget and build freshness

**Date:** 2026-08-06 · **Status:** COMPLETE · **Tier:** T2

## Problem

Provisioning the SPC700 IPL turned `dev/run.sh corpus` from a skipped MAME leg into a real 63-row run.
The first run returned only 40/63:

- 21 long-running kernels still held the zero-initialized `corpus_result` when sampled; and
- `nbody_sim.sfc` and `nmitally_sim.sfc` plus their maps were absent.

The first write-up called this a 600-tick deadline. Source inspection corrects that claim: `corpus.sh`
does not set `SMOKE_SETTLE`, so `_emu.sh` uses its historical **60-tick** default and a three-emulated-second
backstop. By contrast, `corpus-a16.sh` explicitly exports `SMOKE_SETTLE=1000`; the same manifest then passes
62/62 across default, a16, and xy16 on both emulators. This is a harness budget/freshness defect, not a
measured codegen divergence.

`corpus.sh` also consumes prebuilt `build/<name>.{sfc,map}` files and merely tells the operator to run the
large all-examples build when either is absent. That makes the supposedly manifest-scoped gate depend on
unrelated prior work and allows stale ROMs when sources change.

## Implementation

1. Make the plain corpus self-contained at its own scope:
   - resolve the selected toolchain and installed `mos-snes.cfg`;
   - compile every manifest row's source to its canonical `build/<name>.sfc` and `.map` before running;
   - checksum each ROM; and
   - fail immediately and identify the source if compilation/checksum fails.
2. Set `SMOKE_SETTLE=1000` by default, matching the already-green `corpus-a16` evidence. Keep it
   environment-overridable for focused measurement.
3. Set `SMOKE_SECONDS=20` by default so MAME's backstop exceeds 1,000 frames at approximately 60 fps.
   Forward `SMOKE_SECONDS` through `dev/run.sh`, which currently forwards `SMOKE_SETTLE` but not the paired
   backstop.
4. Update help/comments and correct every new 600-tick status claim to 60 ticks.

A per-test budget table is deliberately rejected for now: the uniform 1,000-tick bound already passed all
62 computational rows in `corpus-a16`, `-nothrottle` keeps its wall-clock cost modest, and a table would add
63 manifest-policy values without improving correctness.

## Verification

1. `bash -n` and `shellcheck` on changed shell scripts.
2. Move `build/nbody_sim.{sfc,map}` and `build/nmitally_sim.{sfc,map}` aside if present; run the gate and
   prove it recreates them. (They are absent at implementation start, so the first full run is already the
   cold-build control.)
3. Run `SMOKE_SETTLE=60 dev/run.sh corpus` as the negative timing control after the build preflight; expect
   the known long-kernel failures but no missing-ROM failures.
4. Run plain `dev/run.sh corpus`; require `63/63 passed`.
5. Re-run `dev/run.sh corpus-a16`; require the established `62/62 passed, 0 xfail` differential result.
6. Record raw summaries in this plan and close the TODO follow-up only after both full gates pass.

## Results

**PASS — 6/6 verification steps completed.** The negative control, full plain corpus, paired differential,
and static checks all produced the required results below.

```text
$ SMOKE_SETTLE=60 SMOKE_SECONDS=3 dev/run.sh corpus
63/63 manifest rows built, including nbody_sim and nmitally_sim
corpus: 42/63 passed
```

This negative control removed both missing-ROM failures while preserving exactly the 21 late-result
failures, independently proving the build-freshness half of the fix and confirming the 60-tick diagnosis.

```text
$ dev/run.sh corpus
corpus: build expected.tsv with /work/build/llvm-mos-install/bin/mos-clang
corpus: run expected.tsv (MAME settle=1000, backstop=20s)
corpus: 63/63 passed

$ dev/run.sh corpus-a16
corpus-a16: 62/62 passed, 0 xfail
```

`bash -n`, `shellcheck`, and `git diff --check` pass. The uniform budget is accepted: every plain row is
green, and the broader default/a16/xy16 × MAME/bsnes-jg differential remains unchanged.
