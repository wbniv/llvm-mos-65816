# [DRAFT — PR body for llvm-mos/llvm-mos; strip this preamble when posting]
#
# Status: POSTED 2026-07-26 as https://github.com/llvm-mos/llvm-mos/pull/577 ("Fixes #576"
# substituted for the #NNN placeholder below; body below is otherwise the as-posted text).
# Branch: wbniv:mos-scmp-ucmp-legalize
# (cut from main tip 8be054612; carries the one-line fix + llvm/test/CodeGen/MOS/scmp-ucmp.ll).
# Post command (after the issue is opened and `gh auth login`):
#   gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-scmp-ucmp-legalize --base main \
#     --title "[MOS] Legalize G_SCMP/G_UCMP via lowerThreewayCompare" \
#     --body "$(sed '1,/^---$/d' docs/upstream-scmp-ucmp-pr.md)"   # append "Fixes #<issue>" first
---
`MOSLegalizerInfo` had no rule for `G_SCMP`/`G_UCMP`, so the C three-way-compare idiom
`(a > b) - (a < b)` — which clang/instcombine canonicalize to `llvm.scmp`/`llvm.ucmp` — aborted the
backend (`unable to legalize instruction: ... = G_SCMP ...`) at every integer width, every `-O`
level, with and without LTO. Any `qsort` spaceship comparator fails to build for MOS.

The fix is one line, placed next to the analogous min/max lowering:

```cpp
getActionDefinitionsBuilder({G_SCMP, G_UCMP}).lower();
```

routing both opcodes through LLVM's existing `LegalizerHelper::lowerThreewayCompare` (an
icmp+select expansion the backend already legalizes end to end). No generic-LLVM change, no new
pseudo, no effect on any currently-compiling code (the opcodes previously always aborted).

Includes `llvm/test/CodeGen/MOS/scmp-ucmp.ll`: `llc -verify-machineinstrs` over signed and unsigned
three-way compares with s8/s16 results and s8/s16/s32/s64 operands — every case aborts without the
fix and compiles verifier-clean with it.

Testing beyond the lit test: the identical change has been soak-tested in our 65816 development
fork, where five qsort-based SNES demos are differentially verified — host-computed result ==
on-console result on two independent emulators (MAME + bsnes-jg), `-verify-machineinstrs` clean —
and are **playable in-browser** (bsnes-jg WASM, each page's "Verify fidelity" button re-runs the
WRAM self-check live):

- [qsortviz](https://biohack.net/snes/qsortviz/) — the demo that found the crash (libc `qsort`,
  spaceship comparator)
- [spaceship](https://biohack.net/snes/spaceship/) — signed comparators at int8/16/32/64 keys
- [ucmprank](https://biohack.net/snes/ucmprank/) — the unsigned half (`G_UCMP` at u16/u32/u64)
- [trimerge](https://biohack.net/snes/trimerge/) — the scmp result consumed as control flow
- [keycmp64](https://biohack.net/snes/keycmp64/) — chained 64-bit tie-break (`G_SCMP s64` ×2/call)

Fixes #NNN.
