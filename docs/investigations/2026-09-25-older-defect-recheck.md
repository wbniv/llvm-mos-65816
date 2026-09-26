# Fresh reproduction of three older compiler reports

**Subsequent evidence:** the [historical baseline recovery](2026-09-25-historical-baseline-recovery.md)
recovers the original source edits and diagnostics, confirms the full shift
caller still fails in the fork's a16/xy16 modes, and isolates existing patch 0028
as the inline-bitboard repair. Both recovered C inputs pass the saved unpatched
upstream build in its supported configurations. The measurements below remain
the earlier recheck's results; their missing-evidence assessment is superseded.
Recovery attribution: OpenAI Codex CLI 0.157.0 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort.

OpenAI Codex, 2026-09-25. Requested by the user after the near-store fixes.
The shift and undefined-register reports no longer reproduce on the current
compiler for the inputs exercised here. Their status is **not reproduced on this
build**, not proven fixed. The reentrant behavior remains, but is a contract
question rather than a demonstrated ordinary-C miscompile. No compiler
implementation was changed.

## Compiler and isolation

Measurements ran in `.scratch/older-defect-recheck`, branch
`throwaway/older-defect-recheck`, at `2ded248f`, using main's current compiler
read-only. It includes the reviewed patch stack and both local near-store fixes.

- Clang SHA-256: `5c1552885a1c273943ac3eb96c1e0778f96d010eca2f96f771e4a856fcacd0dc`.
- opt SHA-256: `97199a8e07f875b6ea5d7e60b65f7b6540bdb688cdc65cef43d20af8102ab116`.
- All object checks use `-fno-lto -mllvm -verify-machineinstrs`.
- The [132-row compile record](2026-09-25-older-defect-recheck.tsv) has no failures.

## Narrow-count 64-bit shifts: not reproduced on this build

The retained `examples/65816/shift64seam-narrow.c` compiles at `-O0`, `-O1`,
`-O2`, `-O3`, `-Os`, and `-Oz`, in default/a16/xy16: 18 passes. A direct
`1ULL << uint8_t` function also passes those 18 combinations.

An additional runtime fixture restores byte-sized parameters on all three shift
helpers, keeps the volatile count byte-sized, and exercises every count 0–63 over
96 steps. All 18 object combinations pass. Optimized IR retains `shl i64`,
`lshr i64`, and `ashr i64` in helpers taking an `i8` count. Host `0x6A2B` equals
default/a16/xy16 in MAME and a16 in bsnes-jg, using 480 ticks/frames.

The retained minimal input reaches today's legalizer as a `G_ZEXTLOAD` of the
byte count and a `G_SHL`; legalization emits the shift libcall successfully.
This does not establish general support for arbitrary `G_ANYEXT s8 -> s64`
machine IR, nor identify the commit that changed the C reproducer. No new
backend failure is demonstrated by these measured inputs. The historical report
remains unresolved until its failing compiler/input combination is recovered or
a causal fix is identified.

The published [Limb-Seam Barrel](https://biohack.net/snes/shift64seam/) and its
[second published page](https://indri.studio/apps/llvm-mos-65816/snes/shift64seam/)
remain supporting evidence for the original wide-count operation coverage.
This recheck uses newly compiled narrow-count fixtures; it does not redeploy or
claim a new hash for those published ROMs.

## Register pressure and undefined registers: not reproduced on this build

The precise historical failing bitboard input and compiler were not recovered.
The current probe reconstructs the described inline shape; it is not proof of
byte-for-byte identity with the original failing translation unit.
The bitboard fixture forces `popcount`, `ctz`, and `clz` helpers inline, removing
the helper boundary used in the published demo. Optimized IR confirms that all
three i64 intrinsics occur inside `bitboard64_step`, with no helper definitions.
All six optimization levels in default/a16/xy16 pass non-LTO verification: 18
passes. The full SNES demo compiled against the same modified header also passes
at `-O1` and `-Os` in all three modes: six more passes.

Nine additional witnesses pass at `-O1` and `-Os` in default/a16/xy16: 54 passes.
They are `rcundef.c`, `rcundef2.c`, `a16regpress.c`, and the `newton`, `trimerge`,
`lsystem`, `gouraud`, `msquares`, and `mandel-double` corpus slices. This is a
specific witness set, not a claim that all possible register-pressure defects
are solved. The integrated undef-lane/copy-liveness fixes remain credited to
their existing authors; this recheck does not bisect the bitboard improvement
to a particular patch.

The forced-inline bitboard runtime fixture retains the tour's host result
`0xC074`; default/a16/xy16 in MAME and a16 in bsnes-jg agree. Its constant-shift
one-hot loop stays intact to isolate the inline-pressure question; the direct
variable one-hot form is checked separately above.

The original [Bitboard Knight Tour](https://biohack.net/snes/bitboard64/) and
[second published page](https://indri.studio/apps/llvm-mos-65816/snes/bitboard64/)
remain published evidence. Their historical helper workaround is no longer
evidence of an active compiler failure on this build, but these passing probes
do not invalidate the original observation or establish its cause as fixed.

## Reentrant attribute: behavior reproduced, semantics issue retained

The existing two-function reproducer was compiled at `-O1` for both mos6502 and
mosw65816, with and without `-fnonreentrant`. The resulting IR was run through
`opt -passes=mos-nonreentrant,verify`.

| Configuration | Annotated function before pass | Ordinary function before pass | After pass |
|---|---|---|---|
| Default frontend | No `nonreentrant` | No `nonreentrant` | Both `nonreentrant` |
| `-fnonreentrant` | No `nonreentrant` | `nonreentrant` | Both `nonreentrant` |

Both CPUs produce the same result. The attribute effectively suppresses the
frontend assumption. It does not encode a positive backend prohibition on static
frames; both leaf functions are inferred `norecurse`. An end-to-end mos6502
assembly check places their volatile arrays in the shared four-byte static stack.

This confirms that the attribute is not a force-soft-stack switch. It does not
demonstrate a supported-program miscompile or failure of compiler-visible
interrupt/recursion handling. Keep the [semantics report](../upstream-reentrant-soft-stack-issue.md)
open; a stronger contract needs to be specified before selecting a compiler fix.
No issue was posted and no attribute behavior was changed.

## Status and evidence limits

Machine-checked records: [narrow shifts](../defects/shift64-narrow-count.json),
[inline bitboard pressure](../defects/bitboard-inline-register-pressure.json), and
[reentrant contract](../defects/reentrant-attribute-contract.json).


The user correctly challenged treating failure to reproduce as closure. These
checks establish only the current input/build results. They do not establish
that the historical reports were false, that every triggering optimization
sequence was exercised, or that a particular patch fixed the bitboard/shift
reports. Preserve both as historical reports awaiting a captured failing
baseline. Known individual undef-lane fixes keep their separately proven status.

Future reports follow the [defect evidence workflow](../howto-defect-evidence.md):
freeze a failing baseline and exact input, preserve C plus a relevant IR/MIR
reproducer, and require a discriminating before/after test for a fixed verdict.

## Reproduction and artifacts

```sh
python3 dev/recheck-older-defects.py
cc -O2 -DHOST_MAIN build/older-defect-recheck/shift-runtime.c -o /tmp/shift-host
/tmp/shift-host
cc -O2 -DHOST_MAIN build/older-defect-recheck/bitboard-runtime.c -o /tmp/bitboard-host
/tmp/bitboard-host
dev/container.sh -- env SMOKE_SETTLE=480 BSNES_FRAMES=480 \
  python3 tools/a16_fuzz.py check \
  --src /work/build/older-defect-recheck/shift-runtime.c \
  --expected 0x6A2B --name shift64-narrow-recheck
dev/container.sh -- env SMOKE_SETTLE=480 BSNES_FRAMES=480 \
  python3 tools/a16_fuzz.py check \
  --src /work/build/older-defect-recheck/bitboard-runtime.c \
  --expected 0xC074 --name bitboard-inline-recheck
```

The script accepts `--clang`, `--opt`, and `--out` for an isolated worktree. It
performs 126 object checks, validates the generated IR shapes, and records the
four reentrant configurations. The additional six full-demo compilations and
their exact commands are retained in `build/older-defect-recheck/demo-report.json`.
They use the generated `bitboard-inline.h`, replace the demo's bitboard include,
and compile with the existing SNES SDK config and `-I examples/snes`.

Raw inputs, objects, commands, diagnostics, and reentrant IR are retained in
`build/older-defect-recheck` and the isolated worktree's `build/older-defect-recheck/final`.
The run was assembled from the 108-case main matrix plus an 18-case one-hot
extension; `report.json` and `onehot-report.json` preserve those separate logs.
Runtime logs are `/tmp/older-defect-{shift,bitboard}-runtime.log`.

## Attribution

OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`), `xhigh` reasoning
effort: fresh reproduction, restored narrow-count/inline-pressure inputs,
compile and runtime validation, reproducible check script, and documentation
reconciliation. Existing Claude discovery, demo, and compiler-patch attribution
is retained. This work confirms the current compiler state; it does not claim
authorship of the fixes already present in that compiler.
