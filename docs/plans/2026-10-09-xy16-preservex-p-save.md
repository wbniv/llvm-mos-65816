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

1. Replay the record's baseline: `c8fb18cb` on `boids.xy16.ll` exits 134 with
   `Using an undefined physical register`.
2. Red on the current downstream `llc` (`6f303945`): the recovered IR with
   `-start-after=loop-reduce`, and the new MIR regression, both fail with that
   signature.
3. Series: the new MIR regression fails on the unfixed #321-4 `llc` and passes
   on the fixed one; MOS CodeGen + MC lit pass at fixed #321-4, fixed #321-16
   and the fixed near-index packet.
4. Green on the record input: the fixed near-index packet `llc` compiles
   `boids.xy16.ll` with the baseline configuration (exit 0), and the recovered
   IR and the truchet `-O3` repeat sighting.
5. Downstream: the rebuilt toolchain compiles the recovered IR and truchet with
   the verifier; the full MOS lit suites pass (`dev/run.sh lit`).
6. Code effect: `llc` before/after over frozen IR of every corpus program and
   demo, default/A16/XY16 at `-Os`, `-Oz`, `-O2`, `-O3`; objects identical
   except where the `PLX` shortcut fires, which must only shrink.
7. Differential: `dev/run.sh corpus-a16` (host == default@MAME == +mos-a16@MAME
   == +mos-a16@bsnes-jg, plus XY16) and the hard-stack gate that runs
   `insert-rep-sep-stack.mir`.
8. The regenerated `0002` differs from `HEAD` only in `MOSInsertREPSEP.cpp`
   and `insert-rep-sep-stack.mir`.

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

Plan and results: Claude Code 2.1.295 (t4-opus-high agent
`a469d5bd6fc11cf09`), model Claude Opus 5.5 (`claude-opus-5-5`), high
reasoning effort; session `72f6d6de-6687-477a-bb4c-b186f9d1ba7f`.
