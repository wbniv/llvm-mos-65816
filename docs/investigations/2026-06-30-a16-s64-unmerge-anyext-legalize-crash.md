# `+mos-a16`/`+mos-xy16` backend crash: `G_UNMERGE_VALUES s64→s16` / `G_ANYEXT s24→s32` unlegalized

**Status:** ✅ **FIXED (2026-06-30)** — real backend legalization crash, surfaced by Round-4 demo **#61**
(Diffie-Hellman 64-bit modular exponentiation). Fixed in **patch `0017-321-a16-s64-unmerge-anyext-legalize`**;
minimal repro at `docs/investigations/repro/a16-s64-unmerge.c`; regression guard = the #61 demo
(`dev/run.sh dhmix`, `0x69AA`) + the corpus slice. Queued upstream in
[`docs/upstream-contribution-status.md`](../upstream-contribution-status.md).

## The fix (patch 0017)

`MOSLegalizerInfo.cpp` / `.h`, all `hasAccum16()`-gated (default 8-bit codegen byte-for-byte untouched):
- **`G_MERGE_VALUES` / `G_UNMERGE_VALUES`**: added the s64↔s16 glue mirroring the existing s32↔s16 glue —
  `{S64,S32}`/`{S32,S64}` as the direct legal 2-lane form, and `{S64,S16}`/`{S16,S64}` custom-rewritten to
  the 2-level shape (`s64 ↔ 2×s32 ↔ 4×s16`) via new `legalizeMergeS64FromWords` /
  `legalizeUnmergeS64ToWords` (exact analogues of the s32 `…FromBytes`/`…ToBytes` handlers, one level up).
- **`G_ANYEXT`**: an odd source width (e.g. an `s24`) has no s16-lane decomposition; since anyext's high
  bits are don't-care, any non-{8,16,32}-source is now routed through `G_ZEXT` (via the existing
  `legalizeAnyExt`, which sets `G_ZEXT` and narrows through bytes). Only the previously-crashing widths
  change behaviour; the working `{S16,S8}`/`{S32,*}` cases are unchanged.

**Validation:** minimal repro + #61 demo now compile under `+mos-a16`/`+mos-xy16`; **all 62 corpus slices
compile under both modes (0 regressions)**; the 64-bit demos (avalanche `0x27EA`, sodo `0xD2A2`, cosmzoom
`0x502F`, multibase `0x371A`, mandel-double `0x0EDF`) and a non-64-bit sample (gf256 `0xC028`, medfilt
`0x87FE`) all keep `host==default==+mos-a16==+mos-xy16`; `-verify` clean. The anyext→zext routing only
*zeroes don't-care high bits* — a valid refinement, never a miscompile.

## Symptom

Building the #61 corpus under `+mos-a16` (and `+mos-xy16`) aborts in the GlobalISel Legalizer:

```
fatal error: error in backend: unable to legalize instruction:
  %..(s16), %..(s16), %..(s16), %..(s16) = G_UNMERGE_VALUES %..(s64)   (in function: main)
```

The minimal repro reports the *related* gap first:

```
fatal error: error in backend: unable to legalize instruction:
  %..(s32) = G_ANYEXT %..(s24)   (in function: main)
```

**Default 8-bit mode compiles cleanly** — the crash is specific to the 16-bit-register modes
(`+mos-a16`, `+mos-xy16`).

## Minimal repro (`docs/investigations/repro/a16-s64-unmerge.c`)

```c
#include <stdint.h>
volatile uint16_t out;
volatile uint32_t vi;
int main(void){
  uint64_t e = (uint64_t)((vi * 2654435761u) & 0xFFFFFu);   // u32 mul + 20-bit mask, widened to u64
  uint16_t h = 0;
  while (e) { h ^= (uint16_t)e; e >>= 1; }                  // 64-bit variable-shift loop
  out = h;
  for (;;) {}
}
```

`build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang
+mos-a16 -Os -c a16-s64-unmerge.c` → crash. Drop `+mos-a16` → compiles.

## Ablation (what the trigger needs — removing ANY one compiles cleanly)

| variant | result |
|---|---|
| `(uint64_t)((vi * 2654435761u) & 0xFFFFF)` in a 64-bit shift-loop | **CRASH** |
| …without the `& 0xFFFFF` mask (`(uint64_t)(vi * 2654435761u)`) | OK |
| …without the multiply (`(uint64_t)(vi & 0xFFFFF)`) | OK |
| …s64 var directly, no u32→u64 widen (`ve & 0xFFFFF`) | OK |
| …without the shift-loop (single `a*a % m`) | OK |
| exponent `(uint64_t)i` (no mul/mask) fed to the same modpow | OK |
| default 8-bit (any of the above) | OK |

So the trigger is the conjunction: **a 32-bit multiply by a large constant** → **`& 0xFFFFF` (a 20-bit
mask, which known-bits narrows to an `s24`)** → **zero-extend to `uint64`** → **consumed by a 64-bit
variable-shift loop**, under `+mos-a16`/`+mos-xy16`.

## Root cause (two legalizer gaps in the #321 a16 rules)

`vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp`:

1. **`G_ANYEXT`** (line ~109) under `hasAccum16()` is `legalFor({{S16,S8},{S32,S16},{S32,S8}})` then
   `.unsupported()`. The `& 0xFFFFF` value is an **`s24`**, so the widen to `u64` emits
   `G_ANYEXT {S32, S24}` — not in the legal set, no widen/clamp fallback → unlegalized.

2. **`G_UNMERGE_VALUES`** (line ~168) under `hasAccum16()` is `legalFor({{S16,S32}})` +
   `customFor({{S8,S32}})` then `.unsupported()`. Splitting a **`s64`** into 16-bit lanes emits
   `G_UNMERGE_VALUES {S16, S64}` (4 dests) — only `s32` sources are handled → unlegalized. (The fork
   added the s32↔s16/s8 (un)merge glue but not the s64↔s16 glue; `selectUnmergeValues` only takes a
   2-dest unmerge, so the 4-dest s64 form must be custom-rewritten into the legal 2-level shape, exactly
   like `legalizeUnmergeS32ToBytes` does for `{S8,S32}`.)

Both are pre-existing gaps in the `+mos-a16` GlobalISel legalization of wide/odd-width integers; they do
not affect default 8-bit codegen (gated on `hasAccum16()`).

## Fix direction

Mirror the existing s32 glue up one level:
- **`G_MERGE_VALUES`/`G_UNMERGE_VALUES`**: add `{S32,S64}` as the direct legal 2-lane form and
  `{S16,S64}` as a custom 2-level rewrite (`s64 ↔ 2×s32 ↔ 4×s16`), analogous to
  `legalizeMergeS32FromBytes` / `legalizeUnmergeS32ToBytes`.
- **`G_ANYEXT`**: give the a16 rule a width fallback so a non-{8,16,32}-source (e.g. `s24`) is widened to
  a legal source width before the extend, without disturbing the working `{S16,S8}`/`{S32,*}` cases.

Reverify: the minimal repro + the whole differential corpus (`dev/run.sh corpus-a16`) + the shipped
demos must stay green (the comments in the legalizer warn these rules are regression-prone).
