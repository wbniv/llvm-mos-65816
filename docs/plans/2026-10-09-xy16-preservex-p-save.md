# XY16 `preserveX` status-register saves

TODO item: **Repair XY16 preserveX status-register saves** (T4). Defect record:
[`mos-xy16-preserve-x-p-save`](../defects/mos-xy16-preserve-x-p-save.json).

No visible surface: the change is a machine-IR operand flag and a pre-emit
lowering choice inside `MOSInsertREPSEP`. There are no mockups.

## Problem

`MOSInsertREPSEP::preserveX` keeps a live 16-bit X across an `SEP #$10` by
pushing it and pulling it back. When the restore cannot use `PLX` (N/Z needed,
or stack bytes above the spill), it shuffles through a three-byte A/P save:
`PH $p`, `PHA16 $a16`, and `PLA16`/`PL $p` afterwards. Whether `PH $p` reads a
defined value is decided by **backward liveness** alone: the operand is marked
`undef` only when none of C, N, Z, V is live.

Backward liveness says a value is *read later*. It does not say a value is
*defined here*. The two differ when a later instruction reads all of P while
some flags are undefined. The scavenger's status save (`PH killed $p` in a loop
block, valid because carry is defined there) is such a reader: it makes N, Z
and V live back through the loop to the block whose `JSR` clobbered them.
`preserveX` runs after that `JSR`, sees N/Z live, emits `PH $p` without `undef`,
and the machine verifier, which walks forward and accepts a use only if some
sub-register has a defined value, reports `Using an undefined physical
register`. Without `-verify-machineinstrs` the object is emitted: the pushed
byte is pulled back unchanged, so the emitted code is correct; the defect is a
false liveness claim in the MIR (and a missed `PLX` shortcut, below).

## Design

One predicate decides both questions `preserveX` asks: a register's value must
be preserved only if it is **live after the point (backward) and defined before
it (forward availability, as the verifier tracks it)**. `preserveX` computes
both sets at each save point and uses their intersection for:

1. the `undef` flag on `PH $p` (any of C, N, Z, V needed);
2. the `undef` flag on the `PHA16 $a16` courier save (A or B needed);
3. the `PLX` shortcut test (N or Z needed). When N/Z are live but undefined,
   `PLX` may clobber them; the full shuffle is unnecessary.

Items 1 and 2 change only MIR operand flags, never emitted bytes. Item 3 can
only replace the 15-instruction shuffle with one `PLX`, so where it changes
code it is smaller and faster at every optimization level; there is nothing to
gate per level (lesson 4), and it never fires where N/Z hold a defined value
(lesson 2). The forward walk mirrors the scavenger's `hasNoAvailableValue`
helper, which answers the same question for its own `PH $p`.

**Rejected:** making the scavenger's save read only the defined flags (`PH undef
$p, implicit $c`). It removes the spurious N/Z/V liveness at one source but
changes liveness for every scavenger P save in all CPU modes, and leaves
`preserveX` wrong for any other whole-P reader, including its own `PH $p`.

## Where it lands

- Downstream: `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInsertREPSEP.cpp` and
  two regression functions, carried in `patches/llvm-mos/0002-321-accum16.patch`.
  They went into `llvm/test/CodeGen/MOS/insert-rep-sep-cloned-kills.mir`, next
  to its `live_nz` case, rather than `insert-rep-sep-stack.mir` as first
  planned: every function in the stack file is also linked into the SNES
  hard-stack runtime gate (`dev/xy16xreload.sh`), and flags that no instruction
  defines have no runtime value to check.
- Split series: `preserveX` and the stack test are introduced by #321-4
  ("Insert REP/SEP from M/X width requirements") and untouched afterwards, so
  the fix folds into #321-4 and every later commit rebases without conflict.
  Delivered as a fold diff and amended message in the evidence directory, not
  as rewritten commits: round six (`split-320-321-r6`) is built but was never
  recorded, its far-word stages show one failing test each, and folding into
  #321-4 changes every later hash, so the fold is sequenced by whoever finishes
  round six.

## Verification

1. ~~Replay the record's baseline: `c8fb18cb` on `boids.xy16.ll` exits 134 with
   `Using an undefined physical register`.~~ Done at pin `0f031168a7cc`; see the current results below.
2. ~~Red on the current downstream `llc` (`6f303945`): the recovered IR with
   `-start-after=loop-reduce`, and the new MIR regression, both fail with that
   signature.~~ Done at pin `0f031168a7cc`; see the current results below.
3. ~~Series: the new MIR regression fails on the unfixed #321-4 `llc` and passes
   on the fixed one; MOS CodeGen + MC lit pass at fixed #321-4, fixed #321-16
   and the fixed near-index packet.~~ Done by round seven's fold (`b393bb94db76`); its frozen `llc` binaries pass the regression and the record input.
4. ~~Green on the record input: the fixed near-index packet `llc` compiles
   `boids.xy16.ll` with the baseline configuration (exit 0), and the recovered
   IR and the truchet `-O3` repeat sighting.~~ Done at pin `0f031168a7cc`; see the current results below.
5. ~~Downstream: the rebuilt toolchain compiles the recovered IR and truchet with
   the verifier; the full MOS lit suites pass (`dev/run.sh lit`).~~ Done at pin `0f031168a7cc`; see the current results below.
6. ~~Code effect: `llc` before/after over frozen IR of every corpus program and
   demo, default/A16/XY16 at `-Os`, `-Oz`, `-O2`, `-O3`; objects identical
   except where the `PLX` shortcut fires, which must only shrink.~~ Done at pin `f24948c7d1a4` (5,088 configurations, both changed objects shrink); not rerun at `0f031168a7cc`.
7. ~~Differential: `dev/run.sh corpus-a16` (host == default@MAME == +mos-a16@MAME
   == +mos-a16@bsnes-jg, plus XY16) and the hard-stack gate that runs
   `insert-rep-sep-stack.mir`.~~ `corpus-a16` 83/83 at `f24948c7d1a4`; `xy16xreload` 8/8 at both pins.
8. ~~The regenerated `0002` differs from `HEAD` only in `MOSInsertREPSEP.cpp`
   and `insert-rep-sep-stack.mir`.~~ Done at pin `0f031168a7cc`; see the current results below.

### Results (2026-10-09)

**October 10 update:** the dev image now exists, and the repair was carried onto main `3618d3ec` (pin `f24948c7d1a4`), where `MOSInsertREPSEP.cpp` and `insert-rep-sep-cloned-kills.mir` are unchanged (blobs `bc183c0cc2dc`, `f193abc81071`); `dev/regen-patch.sh` round-trips the unmodified checkout, and the spliced `0002` equals main's with exactly the two sections replaced. Round seven of the series folds the repair into #321-4 (`b393bb94db76`): its container-built `llc` binaries `r7-321-04`, `r7-321-16` and `r7-ni` pass the MIR regression and `boids.xy16.ll`. The container toolchain build still cannot run: the selected checkout (`vendor/llvm-mos-f24948c7d1a4` → `.scratch/upstream-pin-2026-10-09/source`) is sparse with an empty `runtimes/`, so `dev/run.sh toolchain` stops at configure with "No download info given for 'runtimes-mos-unknown-unknown'" (`build/xy16px/toolchain-unfixed.log`). Steps 3, 5 and 7 remain incomplete.

Container builds were unavailable: `/var/run/docker.sock` is `root:root 0600`,
and the active rootless daemon has no `llvm-mos-65816-dev` image (about 2 GB to
build, 3 GB free). The fixed `llc` binaries are host rebuilds of the one changed
translation unit into the existing build directories; a control shows the
rebuilt near-proof `llc` emits the baseline's object byte for byte where the
repair cannot apply. Logs and tools:
[evidence](../defects/evidence/2026-10-09-xy16-preservex-repair/README.md).

| Build | Path | sha256 |
|---|---|---|
| record baseline | `build/near-proof-upstream/candidate/bin/llc` | `c8fb18cbdc4f6e40923f530b4c6cc70ba68ca1ae9b2f7a92ecd65b19245d4b64` |
| near-proof + repair | `build/xy16px/np/llc` | `ec3535c9bfaa1e9f3ac32c3b8ab17bf691f7e7e52ae0a49e8bbd98073eabae04` |
| downstream (installed) | `build/llvm-mos/bin/llc` | `6f303945beb17ab3c8a568ca135b926633533b592b01dd6677c22d49fcceca19` |
| downstream + repair | `build/xy16px/ds/llc` | `1fa2d01a54e9d1ec7578a1ca745ca548b827ea3e82a67bd47b042c2399a44cd6` |
| series #321-4 (tree `bda6806cfddb`) | `build/split-320-321/llc/r3-321-04` | `7cb9426a2de329bf2e203cd5287784ae74d66e9e6125a97926f6f1487dc0cf31` |

1. ~~Baseline replay~~ (`baseline-replay.log`):

    ```
    COMMAND: build/near-proof-upstream/candidate/bin/llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs -filetype=obj docs/defects/evidence/2026-09-29-xy16-preserve-x-p-save/boids.xy16.ll -o /dev/null
    llc sha256: c8fb18cbdc4f6e40923f530b4c6cc70ba68ca1ae9b2f7a92ecd65b19245d4b64
    *** Bad machine code: Using an undefined physical register ***
    - function:    main
    - basic block: %bb.25  (addr)
    - instruction: PH $p
    EXIT: 134
    ```

    PASS.

2. ~~Red on the downstream `llc`~~ (`downstream-recovered-ir-red.log`, `mir-regression-downstream-red.log`):

    ```
    COMMAND: build/llvm-mos/bin/llc ... -verify-machineinstrs -start-after=loop-reduce -filetype=obj .../boids.xy16.recovered.ll -o /dev/null
    llc sha256: 6f303945beb17ab3c8a568ca135b926633533b592b01dd6677c22d49fcceca19
    *** Bad machine code: Using an undefined physical register ***
    - function:    main
    - instruction: PH $p
    EXIT: 134
    COMMAND: build/llvm-mos/bin/llc ... -run-pass=mos-insert-rep-sep -verify-machineinstrs insert-rep-sep-cloned-kills.mir -o - | FileCheck ...
    *** Bad machine code: Using an undefined physical register ***
    - function:    live_undefined_nz
    - instruction: PH $p
    LLC_EXIT: 134 FILECHECK_EXIT: 2
    ```

    The truchet `-O3` sighting also fails there (`downstream-truchet-o3-red.log`, `EXIT: 134`). PASS.

3. Series (`mir-regression-321-04-red.log`, `mir-regression-near-proof-green.log`):

    ```
    COMMAND: build/split-320-321/llc/r3-321-04 ... -run-pass=mos-insert-rep-sep -verify-machineinstrs insert-rep-sep-cloned-kills.mir -o - | FileCheck ...
    llc sha256: 7cb9426a2de329bf2e203cd5287784ae74d66e9e6125a97926f6f1487dc0cf31
    *** Bad machine code: Using an undefined physical register ***
    - function:    live_undefined_nz
    - instruction: PH $p
    LLC_EXIT: 134 FILECHECK_EXIT: 2
    COMMAND: build/xy16px/np/llc ... (same)
    llc sha256: ec3535c9bfaa1e9f3ac32c3b8ab17bf691f7e7e52ae0a49e8bbd98073eabae04
    LLC_EXIT: 0 FILECHECK_EXIT: 0
    ```

    FAIL (incomplete): red on #321-4 holds, but no fixed #321-4, #321-16 or
    near-index packet `llc` was built and no series lit ran, because the
    container is unavailable and the fold was not committed (see "Where it
    lands"). The green above is the near-proof candidate, whose `preserveX`
    matches the series byte for byte.

4. ~~Green on the record input~~ (`candidate.log`, `candidate-recovered-ir.log`, `candidate-truchet-o3.log`):

    ```
    COMMAND: build/xy16px/np/llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs -filetype=obj docs/defects/evidence/2026-09-29-xy16-preserve-x-p-save/boids.xy16.ll -o /dev/null
    llc sha256: ec3535c9bfaa1e9f3ac32c3b8ab17bf691f7e7e52ae0a49e8bbd98073eabae04
    EXIT: 0
    COMMAND: build/xy16px/np/llc ... -start-after=loop-reduce ... boids.xy16.recovered.ll -o /dev/null
    EXIT: 0
    COMMAND: build/xy16px/np/llc -O3 -verify-machineinstrs -filetype=obj $SCRATCH/truchet.ll -o /dev/null
    EXIT: 0
    ```

    PASS. The candidate is the near-proof packet `llc` with the repair, not a
    fixed series commit.

5. Downstream (`downstream-*-green.log`, `lit-downstream.txt`):

    ```
    build/xy16px/ds/llc ... boids.xy16.recovered.ll  EXIT: 0
    build/xy16px/ds/llc -O3 ... truchet.ll           EXIT: 0
    before: llc 6f303945..., test tree as in vendor
    PASS=192 UNSUPPORTED=4
    after: build/xy16px/ds/llc bound over /work/build/llvm-mos/bin/llc, and insert-rep-sep-cloned-kills.mir with the two new functions
    PASS=192 UNSUPPORTED=4
    single-test check, unfixed llc + new test:
    FAIL: LLVM :: CodeGen/MOS/insert-rep-sep-cloned-kills.mir (1 of 1)
    single-test check, fixed llc + new test:
    PASS: LLVM :: CodeGen/MOS/insert-rep-sep-cloned-kills.mir (1 of 1)
    ```

    FAIL (incomplete): the repair passes with the host-rebuilt `llc`, but the
    toolchain was not rebuilt in the container or installed, so `clang-23`/`lld`
    and `dev/run.sh lit` are unchanged.

6. ~~Code effect~~ (`census-summary.txt`):

    ```
    configurations: 5088; frontend failures: 0
    identical failures on both sides (far-pointer and other pre-existing compile errors, exit 1): 174
    verifier failures with this signature: before 1, after 0
    objects that differ: 1
      examples/snes/truchet.c xy16 -O3: before exit -6:undef-phys (object emitted without the verifier), .text 21771 B; after exit 0, .text 21712 B; delta -59 B
      default -Os: 384/384 compiled objects identical
      ... (every default, a16 and xy16 level identical; xy16 -O3 422/422 besides truchet)
    ```

    PASS. No opt-level gate is needed: no `-Os`/`-Oz` object changes, and the
    one change is a pure size and cycle win.

7. Differential (`census-summary.txt`):

    ```
    runtime check of the one changed configuration (truchet.c, +mos-a16 +mos-xy16, -O3; host oracle tools/truchet-sim.c = EXPECT=0xB3E6)
      bsnes-jg (build/jgxcheck, 800 frames): before SMOKE: PASS got=0xB3E6; after SMOKE: PASS got=0xB3E6
      MAME (dev/_emu.sh run_assert on the host in tools/wrap.sh, SMOKE_SETTLE=800): before SMOKE: PASS got=0xB3E6; after SMOKE: PASS got=0xB3E6
    ```

    FAIL (incomplete): `dev/run.sh corpus-a16` and `dev/run.sh xy16xreload`
    need the container. Every other census object is byte-identical, so they
    can only differ on truchet XY16 `-O3`, which matches the oracle on both
    emulators.

8. ~~`0002` scope~~:

    ```
    $ git diff --stat
     patches/llvm-mos/0002-321-accum16.patch | 105 ++++++++++++++++++++++++++------
    $ git diff patches/llvm-mos/0002-321-accum16.patch | grep '^[-+]index'
    -index 000000000000..bc183c0cc2dc
    +index 000000000000..98c349c371cf
    -index 000000000000..f193abc81071
    +index 000000000000..1c6b2f9947aa
    MOSInsertREPSEP.cpp round-trips
    insert-rep-sep-cloned-kills.mir round-trips
    ```

    PASS, with the test file changed as noted under "Where it lands". The
    full `dev/regen-patch.sh` needs two 2.2 GB vendor worktrees, which the
    disk and `/tmp` cannot hold, so the two new-file sections were regenerated
    with `tools/newfile-section.sh`. That generator reproduces both `HEAD`
    sections byte for byte from the current vendor files, and each new section
    applies to reproduce the fixed file exactly.

### Results (2026-10-10, container build at pin `f24948c7d1a4`, superseded by the next section)

The dev container was usable again. `runtimes/` was added to the sparse pin
checkout, and `dev/toolchain.sh` built it in the container into the separate
prefix `build/llvm-mos-f24948c7d1a4-install` (`LLVM_MOS_INSTALL`, lock held inside
the container, `BUILD_JOBS=3`): once unfixed, then with the two files. The
shared `build/llvm-mos-install/bin/llc` stayed
`6f303945beb17ab3c8a568ca135b926633533b592b01dd6677c22d49fcceca19` throughout.

| Build | Path | sha256 |
|---|---|---|
| pin, unfixed | `build/xy16px/newpin-unfixed/llc` | `2acf2f546d2a350b8f3fbb9458c987acfb64f2bfeb4637cb64048dabe7c8c85e` |
| pin, fixed (installed at the separate prefix) | `build/llvm-mos-f24948c7d1a4-install/bin/llc`, frozen as `build/xy16px/newpin-fixed/llc` | `f68dae297924c7edce0deb41e529f596460001a71ba713621a43bb392593c5d4` |

1. ~~Baseline replay~~: unchanged from October 9 (PASS).

2. ~~Red on the downstream `llc`~~, now the unfixed pin build (`newpin-*.log`):

    ```
    2026-10-10T03:37:50Z COMMAND: build/xy16px/newpin-unfixed/llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs -filetype=obj docs/defects/evidence/2026-09-29-xy16-preserve-x-p-save/boids.xy16.ll -o /dev/null
    llc sha256: 2acf2f546d2a350b8f3fbb9458c987acfb64f2bfeb4637cb64048dabe7c8c85e
    *** Bad machine code: Using an undefined physical register ***
    - function:    main
    - instruction: PH $p
         196070 Done                       | grep -E 'Bad machine code|^- function|^- basic block|^- instruction|^- operand|LLVM ERROR'
    EXIT: 134
    EXIT: 134
    EXIT: 134
    - function:    live_undefined_nz
    LLC_EXIT: 134 FILECHECK_EXIT: 2
    ```

    PASS. The original record input now fails on the downstream compiler too.

3. ~~Series~~: round seven folds the repair into #321-4 (`b393bb94db76`). Its
   frozen container builds, read only:

    ```
    r7-321-04 22acece860a3c7aa mirtest_filecheck=0 boids=0
    r7-321-16 52f69f0483678d09 mirtest_filecheck=0 boids=0
    r7-ni 935440014999d541 mirtest_filecheck=0 boids=0
    ```

    Round six's near-index `llc` (`216f43a6`) fails `boids.xy16.ll` with 134
    and #321-4 before the fold fails the MIR test (October 9). PASS; the
    series' own lit gates belong to round seven's record.

4. ~~Green on the record input~~ (`newpin-boids-original-green.log`):

    ```
    2026-10-10T03:40:19Z COMMAND: build/llvm-mos-f24948c7d1a4-install/bin/llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs -filetype=obj docs/defects/evidence/2026-09-29-xy16-preserve-x-p-save/boids.xy16.ll -o /dev/null
    llc sha256: f68dae297924c7edce0deb41e529f596460001a71ba713621a43bb392593c5d4
    EXIT: 0
    EXIT: 0
    EXIT: 0
    LLC_EXIT: 0 FILECHECK_EXIT: 0
    ```

    PASS.

5. ~~Downstream~~ (`newpin-toolchain-and-lit.txt`):

    ```
    ==> done in 25m 22s: clang version 24.0.0git (/work/vendor/llvm-mos-f24948c7d1a4/clang f24948c7d1a4b9f162d4d0192ccceecab1e441ff)
    rc=0 2026-10-10T03:37:21Z; free: 11Gi avail; disk 32G free; shared llc 6f303945beb17ab3c8a568ca135b926633533b592b01dd6677c22d49fcceca19
    ==> done in 0m 38s: clang version 24.0.0git (/work/vendor/llvm-mos-f24948c7d1a4/clang f24948c7d1a4b9f162d4d0192ccceecab1e441ff)
    rc=0 2026-10-10T03:39:59Z; free: 11Gi avail; disk 32G free; shared llc 6f303945beb17ab3c8a568ca135b926633533b592b01dd6677c22d49fcceca19
      installed llc sha256 f68dae297924c7edce0deb41e529f596460001a71ba713621a43bb392593c5d4 mtime 2026-10-10T03:39:53Z
    shared install unchanged: build/llvm-mos-install/bin/llc 6f303945beb17ab3c8a568ca135b926633533b592b01dd6677c22d49fcceca19
    ==> llvm-lit -s /work/vendor/llvm-mos-f24948c7d1a4/llvm/test/CodeGen/MOS /work/vendor/llvm-mos-f24948c7d1a4/llvm/test/MC/MOS
    Total Discovered Tests: 206
      Unsupported:   4 (1.94%)
      Passed     : 202 (98.06%)
    ```

    PASS at the separate prefix. Swapping the shared install to the new pin is
    a separate decision and was not done.

6. ~~Code effect~~ (`newpin-census-summary.txt`, clang-built pair):

    ```
    configurations: 5088; frontend failures: 0
    identical failures on both sides (far-pointer and other pre-existing compile errors, exit 1): 174
    verifier failures with this signature: before 2, after 0
    objects that differ: 2
      examples/snes/boids.c xy16 -Os: before exit -6:undef-phys (object emitted without the verifier), .text 13403 B; after exit 0, .text 13384 B; delta -19 B
      examples/snes/truchet.c xy16 -O3: before exit -6:undef-phys (object emitted without the verifier), .text 21584 B; after exit 0, .text 21525 B; delta -59 B
    runtime check of both changed configurations (object from each llc, linked by the new-pin driver against an SDK built by it; host oracles tools/boids-sim.c and tools/truchet-sim.c):
    ```

    PASS. Both changed objects are this defect's failing configurations and
    shrink; there is nothing to gate by optimization level.

7. ~~Differential~~ (`newpin-gates.txt`, `newpin-census-summary.txt`):

    ```
    corpus-a16: MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh corpus-a16
    progress snapshot: A16 [####################] 100% 83/83 complete | 0 remaining | 4685s | finished | PASS 83 FAIL 0 XFAIL 0
    rc=0 2026-10-10T05:05:23Z
    xy16xreload: MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh xy16xreload (stack MIR from the pin checkout, same blob c421564b55aa as the old vendor)
    SMOKE: PASS addr=0x7E0020 len=2 got=0xD77B (ran 1200 ticks)
    SMOKE: PASS off=0x20 len=2 got=0xD77B (ran 1200 frames, bsnes-jg)
    SMOKE: PASS addr=0x7E0020 len=2 got=0xD77B (ran 1200 ticks)
    SMOKE: PASS off=0x20 len=2 got=0xD77B (ran 1200 frames, bsnes-jg)
    SMOKE: PASS addr=0x7E0020 len=2 got=0xD77B (ran 1200 ticks)
    SMOKE: PASS off=0x20 len=2 got=0xD77B (ran 1200 frames, bsnes-jg)
    SMOKE: PASS addr=0x7E0200 len=2 got=0xD77B (ran 1200 ticks)
    SMOKE: PASS off=0x200 len=2 got=0xD77B (ran 1200 frames, bsnes-jg)
    rc=0 2026-10-10T05:07:08Z
      SMOKE: PASS off=0x6C6 len=2 got=0xA8AB (ran 1400 frames, bsnes-jg)
      SMOKE: PASS off=0x6C6 len=2 got=0xA8AB (ran 1400 frames, bsnes-jg)
      SMOKE: PASS addr=0x7E06C6 len=2 got=0xA8AB (ran 1400 ticks)
      SMOKE: PASS addr=0x7E06C6 len=2 got=0xA8AB (ran 1400 ticks)
      SMOKE: PASS off=0x15EE len=2 got=0xB3E6 (ran 800 frames, bsnes-jg)
      SMOKE: PASS off=0x15EE len=2 got=0xB3E6 (ran 800 frames, bsnes-jg)
      SMOKE: PASS addr=0x7E15EE len=2 got=0xB3E6 (ran 800 ticks)
      SMOKE: PASS addr=0x7E15EE len=2 got=0xB3E6 (ran 800 ticks)
    ```

    PASS: `corpus-a16` 83/83 (host == default == A16 == XY16, MAME and
    bsnes-jg), `xy16xreload` 8/8, and both changed ROMs match their host oracle
    (`0xA8AB`, `0xB3E6`) on both emulators before and after. The SDK built by
    the new compiler fails only `ascast`, `ascast_sim` and `lzss-gallery`, the
    open TODO item for the three demo build failures.

8. ~~`0002` scope~~: `dev/regen-patch.sh` (`LLVM_MOS_SOURCE` = the pin
   checkout, temporary worktrees on disk) round-tripped the unmodified checkout
   to main's `0002` byte for byte, and after the two-file change produced
   exactly the committed spliced `0002` (`RESULT: PASS — 0002 round-trips`, no
   diff). PASS.

### Results (2026-10-10, pin `0f031168a7cc`, current)

Main re-pinned again (`0910a44b`). The branch was rebased onto `95d122f1`, the
two `0002` sections re-spliced in the re-pin tool's full-index format, the two
files copied into the bootstrapped `vendor/llvm-mos-0f031168a7cc`, and the
toolchain built in the container into `build/llvm-mos-0f031168a7cc-install`
(cold unfixed build 88m16s, then the fixed incremental build). Shared
`build/llvm-mos-install/bin/llc` stayed `6f303945…`.

1. ~~Baseline replay~~: unchanged (PASS).

2. ~~Red on the downstream `llc`~~ (unfixed pin build `build/xy16px/pin2-unfixed/llc`):

    ```
    2026-10-10T15:41:36Z COMMAND: build/xy16px/pin2-unfixed/llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs -filetype=obj docs/defects/evidence/2026-09-29-xy16-preserve-x-p-save/boids.xy16.ll -o /dev/null
    llc sha256: e8dcef6480b04aa1a3e85697deaa25236a5d223af07372a42b66abc39dcb022d
    *** Bad machine code: Using an undefined physical register ***
    - function:    main
    - instruction: PH $p
         1054080 Done                       | grep -E 'Bad machine code|^- function|^- basic block|^- instruction|^- operand|LLVM ERROR'
    EXIT: 134
    EXIT: 134
    EXIT: 134
    - function:    live_undefined_nz
    LLC_EXIT: 134 FILECHECK_EXIT: 2
    ```

    PASS.

3. ~~Series~~: unchanged; round seven carries the fold (PASS).

4. ~~Green on the record input~~ (`build/xy16px/pin2-fixed/llc`):

    ```
    2026-10-10T15:44:46Z COMMAND: build/xy16px/pin2-fixed/llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs -filetype=obj docs/defects/evidence/2026-09-29-xy16-preserve-x-p-save/boids.xy16.ll -o /dev/null
    llc sha256: a78958b0194092f58a62c779b5059330a31a6c365620343cb4031f24a9fad16b
    EXIT: 0
    EXIT: 0
    EXIT: 0
    LLC_EXIT: 0 FILECHECK_EXIT: 0
    ```

    PASS.

5. ~~Downstream~~ (`pin0f03-toolchain-and-gates.txt`):

    ```
    ==> done in 88m 16s: clang version 24.0.0git (https://github.com/llvm-mos/llvm-mos.git 0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63)
    rc=0 2026-10-10T15:40:38Z; free: 9.1Gi avail; disk 11G free; shared llc 6f303945beb17ab3c8a568ca135b926633533b592b01dd6677c22d49fcceca19
    ==> done in 1m 1s: clang version 24.0.0git (https://github.com/llvm-mos/llvm-mos.git 0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63)
    rc=0 2026-10-10T15:44:38Z; free: 9.2Gi avail; disk 13G free; shared llc 6f303945beb17ab3c8a568ca135b926633533b592b01dd6677c22d49fcceca19
      installed llc sha256 a78958b0194092f58a62c779b5059330a31a6c365620343cb4031f24a9fad16b mtime 2026-10-10T15:44:34Z
      build-tree llc build/llvm-mos-0f031168a7cc/bin/llc sha256 a78958b0194092f58a62c779b5059330a31a6c365620343cb4031f24a9fad16b
    shared install unchanged: build/llvm-mos-install/bin/llc 6f303945beb17ab3c8a568ca135b926633533b592b01dd6677c22d49fcceca19
    MOS lit (dev/lit.sh in the container, build-tree llc above):
    ==> llvm-lit -s /work/vendor/llvm-mos-0f031168a7cc/llvm/test/CodeGen/MOS /work/vendor/llvm-mos-0f031168a7cc/llvm/test/MC/MOS
    Total Discovered Tests: 208
      Unsupported:   4 (1.92%)
      Passed     : 204 (98.08%)
    rc=0 2026-10-10T15:51:11Z
    ```

    PASS at the separate prefix; the shared install was not swapped.

6. Code effect: not rerun at this pin; the `f24948c7d1a4` census above stands
   (the pass is unchanged between the two pins).

7. ~~Differential~~ (`pin0f03-toolchain-and-gates.txt`):

    ```
    ==> built 296 program(s)
    ==> FAILED (3): ascast ascast_sim lzss-gallery
    xy16xreload:
    2026-10-10T15:50:00Z xy16xreload MOS_TOOLCHAIN=/work/build/llvm-mos-install llc a78958b0194092f58a62c779b5059330a31a6c365620343cb4031f24a9fad16b (hardlink of /home/will/llvm-mos-65816/build/llvm-mos-0f031168a7cc-install); stack MIR blob c421564b55aa33b1e52103b5cb10b1d50cd79c67
    SMOKE: PASS addr=0x7E0020 len=2 got=0xD77B (ran 1200 ticks)
    SMOKE: PASS off=0x20 len=2 got=0xD77B (ran 1200 frames, bsnes-jg)
    SMOKE: PASS addr=0x7E0020 len=2 got=0xD77B (ran 1200 ticks)
    SMOKE: PASS off=0x20 len=2 got=0xD77B (ran 1200 frames, bsnes-jg)
    SMOKE: PASS addr=0x7E0020 len=2 got=0xD77B (ran 1200 ticks)
    SMOKE: PASS off=0x20 len=2 got=0xD77B (ran 1200 frames, bsnes-jg)
    SMOKE: PASS addr=0x7E0200 len=2 got=0xD77B (ran 1200 ticks)
    SMOKE: PASS off=0x200 len=2 got=0xD77B (ran 1200 frames, bsnes-jg)
    rc=0 2026-10-10T15:51:11Z
    ```

    PASS for `xy16xreload` 8/8. `corpus-a16` was not rerun at this pin.

8. ~~`0002` scope~~:

    ```
    0002: dev/regen-patch.sh (LLVM_MOS_SOURCE=vendor/llvm-mos-0f031168a7cc) after the change: RESULT: PASS — 0002 round-trips (MOS dir + focused tests == live vendor)
      Its output equals the committed 0002 except for format: regen writes 9-character index abbreviations and empty blank-context lines, the committed file (from task upstream:repin) uses full 40-character indexes and ' ' blank-context lines. The committed 0002 keeps main's format and differs from main only in the MOSInsertREPSEP.cpp and insert-rep-sep-cloned-kills.mir sections (index ..98c349c371cf, ..1c6b2f9947aa); grep -c live_undefined_nz = 2.
    ```

    PASS.

Plan and results: Claude Code 2.1.295 (t4-opus-high agent
`a469d5bd6fc11cf09`), model Claude Opus 5.5 (`claude-opus-5-5`), high
reasoning effort; session `72f6d6de-6687-477a-bb4c-b186f9d1ba7f`.
