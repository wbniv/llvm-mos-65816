# XY16 `preserveX` P-save repair: validation evidence

Record: [`mos-xy16-preserve-x-p-save`](../../mos-xy16-preserve-x-p-save.json).
Plan: [2026-10-09-xy16-preservex-p-save](../../../plans/2026-10-09-xy16-preservex-p-save.md).

## Mechanism

`MOSInsertREPSEP::preserveX` asked backward liveness whether the flags and the
accumulator held values worth saving. Liveness says a register is read later,
not that it is defined here. The scavenger's `PH killed $p` (carry defined, so
valid) reads all of P; `MOSCopyOpt` propagates that read as N/Z/V live-ins back
to the block whose `JSR` clobbered them. In that block, after the call,
`preserveX` saw N/Z live, chose the A/P shuffle instead of `PLX`, and pushed
`PH $p` without `undef`. Walking forward, the verifier finds no defined part of
P and reports `Using an undefined physical register`.

The repair requires a register to be both live after the save point and
defined before it (forward availability, the verifier's own criterion and the
one the scavenger's `hasNoAvailableValue` already uses). It decides the `undef`
flags on `PH $p` and `PHA16 $a16` and the `PLX` shortcut.

## October 10, later: pin `0f031168a7cc` (current closing evidence)

Main re-pinned to `0f031168a7cc`, where both files are again unchanged. The
repair was rebased onto it and copied into the bootstrapped checkout
`vendor/llvm-mos-0f031168a7cc`; `dev/toolchain.sh` built it in the container into
`build/llvm-mos-0f031168a7cc-install` (shared install untouched). Details, hashes,
lit, SDK and `xy16xreload`: [`pin0f03-toolchain-and-gates.txt`](pin0f03-toolchain-and-gates.txt).

| Check | Unfixed `e8dcef64…` | Fixed `a78958b0…` |
|---|---|---|
| Record input `boids.xy16.ll`, baseline configuration | [134](pin0f03-boids-original-red.log) | [0](pin0f03-boids-original-green.log) |
| Recovered IR | [134](pin0f03-recovered-ir-red.log) | [0](pin0f03-recovered-ir-green.log) |
| truchet `-O3` XY16 | [134](pin0f03-truchet-o3-red.log) | [0](pin0f03-truchet-o3-green.log) |
| MIR regression | [`llc` 134](pin0f03-mir-regression-red.log) | [`llc` 0, FileCheck 0](pin0f03-mir-regression-green.log) |

MOS lit 204 passed, 4 unsupported; `xy16xreload` 8/8. `dev/regen-patch.sh`
reproduces the committed `0002` content; it writes abbreviated index lines and
empty blank-context lines, so the committed file keeps the re-pin tool's format
and changes only the two repair sections. The census and the boids/truchet
runtime checks below were run at `f24948c7d1a4`.

## October 10: container build at the new pin (previous pin)

Main moved to pin `f24948c7d1a4`, where `MOSInsertREPSEP.cpp` and the test file
are unchanged. The selected checkout (`vendor/llvm-mos-f24948c7d1a4` →
`.scratch/upstream-pin-2026-10-09/source`) is sparse; `runtimes/` was added to
its patterns, nothing else ([before](sparse-before.txt), [after](sparse-after.txt);
restore with `git sparse-checkout set --no-cone --stdin < sparse-before.txt`).
`dev/toolchain.sh` then built the pin in the dev container into the separate
prefix `build/llvm-mos-f24948c7d1a4-install`; the shared `build/llvm-mos-install`
stayed `6f303945…` ([identities and lit](newpin-toolchain-and-lit.txt)).

| Check | Unfixed `2acf2f54…` | Fixed `f68dae29…` |
|---|---|---|
| Record input `boids.xy16.ll`, baseline configuration | [exit 134](newpin-boids-original.log), `PH $p` in `main` | [exit 0](newpin-boids-original-green.log) |
| Recovered IR | [134](newpin-recovered-ir-red.log) | [0](newpin-recovered-ir-green.log) |
| truchet `-O3` XY16 | [134](newpin-truchet-o3-red.log) | [0](newpin-truchet-o3-green.log) |
| MIR regression | [`llc` 134](newpin-mir-regression-red.log) | [`llc` 0, FileCheck 0](newpin-mir-regression-green.log) |

At this pin the defect reproduces from the original IR without the recovery
replay, and from C: [`newpin-census-summary.txt`](newpin-census-summary.txt)
(5,088 configurations, rows in [`newpin-census.tsv.gz`](newpin-census.tsv.gz))
finds it in `boids.c` XY16 `-Os` and `truchet.c` XY16 `-O3`, the only two objects
that change (−19 B and −59 B). Every other object is byte-identical, which also
settles the October 9 host-rebuild question. Both ROMs return their host
oracle on bsnes-jg and MAME before and after. MOS lit: 202 passed, 4
unsupported; `corpus-a16` 83/83; `xy16xreload` 8/8 ([gates](newpin-gates.txt)).

There is nothing to gate by optimization level: the `undef` flags change no
emitted byte, and `PLX` only removes instructions, so the changed objects are
smaller and faster at the level where they change (`-Os` and `-O3`).

## October 9: host rebuilds on the previous pin

### Toolchains

| Role | Path | sha256 | Source |
|---|---|---|---|
| Record baseline (red) | `build/near-proof-upstream/candidate/bin/llc` | `c8fb18cbdc4f6e40…` | `06bc967d2668` + #321 prerequisite + near-index recovery (`980fe1f29381`), container build |
| Candidate (green) | `build/xy16px/np/llc` | `ec3535c9bfaa1e9f…` | the same build directory with only `MOSInsertREPSEP.cpp` replaced |
| Downstream (red) | `build/llvm-mos/bin/llc` | `6f303945beb17ab3…` | installed toolchain, `0002` at `dfeb5c9b` |
| Downstream fixed (green) | `build/xy16px/ds/llc` | `1fa2d01a54e9d1ec…` | the same build directory with only `MOSInsertREPSEP.cpp` replaced |
| Series #321-4 (red) | `build/split-320-321/llc/r3-321-04` | `7cb9426a2de329bf…` | tree `bda6806cfddb`, identical to #321-4 `e7943fff59cc` |

Full hashes are in each log. The two fixed `llc` binaries were host rebuilds, removed on October 10 once the container build reproduced every result:
the container daemon was unavailable (see below), so
[`tools/hostbuild.py`](tools/hostbuild.py) recompiled the one changed
translation unit with host g++ 15.2.0 (clang-only warning flags and the PCH
dropped) and relinked `llc` with GNU ld 2.46 from the existing build
directory's objects and archives, inside [`tools/wrap.sh`](tools/wrap.sh)'s
private mount namespace so the `/work` paths resolve. Fixed object hashes:
near-proof `405175bd5bd482e8…`, downstream `0d91e4f621c1a5e2…`.
[`control-host-rebuild.log`](control-host-rebuild.log) shows the rebuilt
near-proof `llc` emits the baseline's object byte for byte where the repair
cannot apply (recovery off).

### Red / green

| Check | Red | Green |
|---|---|---|
| Record input `boids.xy16.ll`, baseline configuration | [baseline-replay.log](baseline-replay.log) exit 134 | [candidate.log](candidate.log) exit 0 |
| Recovered IR, `-start-after=loop-reduce` | [downstream red](downstream-recovered-ir-red.log) 134 | [downstream](downstream-recovered-ir-green.log) 0, [candidate](candidate-recovered-ir.log) 0 |
| truchet `-O3` XY16 repeat sighting | [downstream](downstream-truchet-o3-red.log) 134, [baseline](baseline-truchet-o3.log) 134 | [downstream](downstream-truchet-o3-green.log) 0, [candidate](candidate-truchet-o3.log) 0 |
| MIR regression ([`insert-rep-sep-cloned-kills.mir`](insert-rep-sep-cloned-kills.mir)) | [#321-4](mir-regression-321-04-red.log), [downstream](mir-regression-downstream-red.log), [near-proof](mir-regression-near-proof-red.log): `llc` 134 | [downstream](mir-regression-downstream-green.log), [near-proof](mir-regression-near-proof-green.log): `llc` 0, FileCheck 0 |

The truchet input is `zcat` of
`../2026-10-01-carry-pressure-contract/truchet-o3-xy16/truchet.c.a16xy16.ll.gz`
(decompressed sha256 `c0282601da97d578…`); the logs name the decompressed
scratch copy.

### Series fold

[`321-04-fold.diff`](321-04-fold.diff) is the change to fold into #321-4. Both
files it touches have the same blob (`76749c510e43`, `f193abc81071`) from #321-4
through the round-six top `edefc9174713`, the near-index packet `5eee035fdf5c`
and the 0065 packet `8520db898e70`, so every later commit rebases without
conflict and changes by exactly this diff. [`321-04-message.txt`](321-04-message.txt)
is the amended commit message.

### Code effect and runtime

[`census-summary.txt`](census-summary.txt) (rows in
[`census.tsv.gz`](census.tsv.gz)): 424 C files × default/A16/XY16 ×
`-Os`/`-Oz`/`-O2`/`-O3` = 5,088 configurations, before and after `llc` on the
same frozen IR. One object differs: `truchet.c` XY16 `-O3`, the repeat
sighting, which the old `llc` rejects with this signature; with the repair it
verifies and its `.text` shrinks by 59 B (21,771 to 21,712) because restores
become `PLX`. Every other object is byte-identical, and the 174 pre-existing
failures (far pointers in default mode and similar) fail identically on both
sides. That ROM, built from each `llc`'s object, returns the host oracle's
`0xB3E6` on bsnes-jg and on MAME, before and after.

[`lit-downstream.txt`](lit-downstream.txt): the MOS CodeGen and MC suites keep
192 passes and 4 unsupported with the fixed `llc` and the new test bound into
the build tree; the new test alone fails on the unfixed `llc`.

There is nothing to gate by optimization level: the `undef` flags change no
emitted byte, and the `PLX` shortcut only removes instructions, so it is
smaller and faster wherever it fires (here `-O3`).

### Limits on October 9

The container daemon was unusable on October 9, so these results stood on host rebuilds; the October 10 section above repeats them with container builds and adds the gates that were missing.
