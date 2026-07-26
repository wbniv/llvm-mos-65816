# [DRAFT — issue body for llvm-mos/llvm-mos; strip this preamble when posting]
#
# Status: drafted 2026-07-26 (campaign Wave 1, item 1a). Post together with the fix PR
# (upstream-scmp-ucmp-pr.md); the PR says "Fixes #<this>".
# Post command (after `gh auth login`):
#   gh issue create -R llvm-mos/llvm-mos \
#     -t "Backend abort: unable to legalize G_SCMP/G_UCMP (C three-way compare) " \
#     -b "$(sed '1,/^---$/d' docs/upstream-scmp-ucmp-issue.md)"
---
The standard C three-way-compare ("spaceship") idiom crashes the backend at every integer width, on
every `-O` level, with and without LTO:

```c
// crash.c — any qsort comparator written this way triggers it
int cmp(short a, short b) { return (a > b) - (a < b); }
```

```
$ mos-clang --target=mos -mcpu=mosw65816 -Os -c crash.c
fatal error: error in backend: unable to legalize instruction:
  %2:_(s16) = G_SCMP %0:_, %1:_ (in function: cmp)
```

Clang/instcombine canonicalize `(a > b) - (a < b)` to the generic `llvm.scmp`/`llvm.ucmp`
intrinsics (introduced LLVM 19), which reach GlobalISel as `G_SCMP`/`G_UCMP` — and
`MOSLegalizerInfo` has no rule for either opcode, so legalization aborts. Unsigned comparators
(`unsigned`/`unsigned long` operands) hit the same wall via `G_UCMP`.

Practical impact: any program that sorts with a spaceship comparator — the idiomatic `qsort`
callback — fails to build for MOS. We hit it via a SNES demo sorting with `qsort` at `-Os`
(both the `-fno-lto` object path and the LTO link path reproduce).

IR repro (same crash under `llc -mtriple=mos`):

```llvm
define i16 @cmp(i16 %a, i16 %b) {
  %r = call i16 @llvm.scmp.i16.i16(i16 %a, i16 %b)
  ret i16 %r
}
```

Fix incoming as a PR: a one-line legalizer rule routing `{G_SCMP, G_UCMP}` to `.lower()`, which
expands through LLVM's own `LegalizerHelper::lowerThreewayCompare` into the icmp+select shapes the
backend already legalizes — no generic-LLVM change. Verified on a pristine checkout of current
`main` plus a `llc` lit test covering s8/s16 results with s8/s16/s32/s64 operands, signed and
unsigned; downstream we have additionally soak-tested the exact change inside a 65816 fork where
sorted-demo output is differentially verified against a host oracle on two emulators — playable
in-browser at [qsortviz](https://biohack.net/snes/qsortviz/) (the demo that found this),
[spaceship](https://biohack.net/snes/spaceship/), [ucmprank](https://biohack.net/snes/ucmprank/),
[trimerge](https://biohack.net/snes/trimerge/), [keycmp64](https://biohack.net/snes/keycmp64/).
