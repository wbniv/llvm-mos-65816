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

## Toolchains

| Role | Path | sha256 | Source |
|---|---|---|---|
| Record baseline (red) | `build/near-proof-upstream/candidate/bin/llc` | `c8fb18cbdc4f6e40…` | `06bc967d2668` + #321 prerequisite + near-index recovery (`980fe1f29381`), container build |
| Candidate (green) | `build/xy16px/np/llc` | `ec3535c9bfaa1e9f…` | the same build directory with only `MOSInsertREPSEP.cpp` replaced |
| Downstream (red) | `build/llvm-mos/bin/llc` | `6f303945beb17ab3…` | installed toolchain, `0002` at `dfeb5c9b` |
| Downstream fixed (green) | `build/xy16px/ds/llc` | `1fa2d01a54e9d1ec…` | the same build directory with only `MOSInsertREPSEP.cpp` replaced |
| Series #321-4 (red) | `build/split-320-321/llc/r3-321-04` | `7cb9426a2de329bf…` | tree `bda6806cfddb`, identical to #321-4 `e7943fff59cc` |

Full hashes are in each log. The two fixed `llc` binaries are host rebuilds:
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

## Red / green

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

## Series fold

[`321-04-fold.diff`](321-04-fold.diff) is the change to fold into #321-4. Both
files it touches have the same blob (`76749c510e43`, `f193abc81071`) from #321-4
through the round-six top `edefc9174713`, the near-index packet `5eee035fdf5c`
and the 0065 packet `8520db898e70`, so every later commit rebases without
conflict and changes by exactly this diff. [`321-04-message.txt`](321-04-message.txt)
is the amended commit message.

## Code effect and runtime

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
smaller and faster wherever it fires (here `-O3`; no `-Os`/`-Oz` object
changes).

## Not run here

The rootful Docker socket is `root:root 0600`, and the active rootless daemon has
no `llvm-mos-65816-dev` image; building one needs about 2 GB on a disk with
3 GB free. So the container toolchain rebuild and install (which also refreshes
`clang-23` and `lld`, where LTO codegen runs), the in-container MOS lit run, the
full `corpus-a16` differential and the series' per-commit gates did not run.
With every other object byte-identical, the full differential can only differ
on truchet XY16 `-O3`, which passes above.
