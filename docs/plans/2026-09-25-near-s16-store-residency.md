# Near s16 stores from byte-register values

Owner: OpenAI Codex. Completed locally 2026-09-25 at the user’s request to take the next open defect.
Source, tests, patch bundle, and installed main compiler are updated.
Claude identified and measured the loss in the [far-scalar investigation](../investigations/2026-09-25-far-scalar-split-measurement.md#43-loss-vectors-governing-lesson-2--what-an-ungated-rule-would-do).

## Scope and approach

`void set(uint16_t v) { g = v; }` is reported as 14 bytes with `+mos-a16`
versus 7 bytes with default lowering. Diagnose the legalizer’s value-residency
assumption, retain profitable native stores, and add regression coverage for
argument stores and native producers. Far-native memory operations remain a
separate TODO.

Worktree: `.scratch/near-store`, branch `wt/321-near-store`, based on `2ded248f`
with the current reviewed patch stack overlaid. It has an independent vendor
checkout and warm build. The main checkout contains other uncommitted work.

## Validation plan

1. Capture assembly and legalizer MIR for argument, constant, load, arithmetic,
   indirect, indexed, volatile, and mixed-use store shapes.
2. Compare default, a16, and xy16 output before/after; preserve native copy paths.
3. Run focused and full MOS lit tests, machine verification, a representative
   size census, and a runtime differential using both emulator cores.
4. Regenerate and round-trip `0002`; update this record and the TODO with results
   and OpenAI Codex attribution. No upstream submission is part of this task.

## Diagnosis and candidate

IRTranslator builds the ABI argument as `G_MERGE_VALUES` of the `A` and `X`
bytes. The absolute-store arm previously always emitted `G_STORE16_ABS` for a
nonconstant value, forcing an Imag16 spill and reload. OpenAI Codex’s candidate
narrows an absolute store when the value is a direct merge of two bytes and every
use is an absolute store or byte unmerge in the same basic block, without an
intervening call or inline assembly. Native arithmetic/load producers, native
consumers, indirect/indexed stores, and uncertain cross-block residency keep their
existing lowering. Default feature mode is unaffected.

An initial producer/use-only predicate was insufficient: `opaque(); g = v;`
grew 29→30 bytes because the call already forced the value into preserved
storage. The final predicate excludes this case and a conditional-call case
(33 bytes unchanged). These exclusions have lit coverage; inline-assembly
clobbers have a separate check. This is a conservative local optimization, not
a full register-residency analysis. The broader near-store and far-store cases
remain separate work.

Measured `-Os` micro shapes (same sizes in a16 and xy16):

| Shape | Before | Candidate |
|---|---:|---:|
| `g = v` argument setter | 14 B / 27 estimated cycles | 7 B / 14 estimated cycles |
| Volatile argument setter | 14 B | 7 B |
| Store and return the argument | 16 B | 7 B |
| Store argument into two globals | 19 B | 13 B |
| Store a call result | 17 B | 10 B |
| Store, then tail-call another function | 16 B | 9 B |
| Native arithmetic on another global, then store argument | 24 B | 22 B |
| Call before store | 29 B | 29 B |
| Conditional call before store | 33 B | 33 B |
| Argument also consumed by native arithmetic | 23 B | 23 B |

The plain indirect setter was left at 13 B under a16/xy16 versus 8 B by default.
The [next focused fix](2026-09-25-near-indirect-s16-store-residency.md) addresses
that shape and records its separate measurements.

## Validation complete

- The new lit test fails against the baseline on the unwanted spill/reload and
  passes on the candidate in default/a16/xy16 modes, with machine verification.
- Full MOS lit: 167 tests, 161 passed, 2 unsupported, the same 4 existing failures:
  `legalizer.mir`, `scavenger-p-undef-6502.ll`, `shift-rotate.ll`, and
  `MC/MOS/addressing-modes-65816.s`. The inline-assembly case was subsequently
  added to the same test and checked in all three modes.
- New runtime fixture: host `0xDBA7` equals default/a16/xy16 on MAME and a16 on
  bsnes-jg, including the final installed main compiler. Main and isolated
  candidate clang binaries have identical SHA-256 hashes.
- Existing `a16abs` native global-copy gate passes its disassembly checks and
  returns `0x5A3D` on MAME and bsnes-jg.
- Seventeen reduced functions at `-Os`, `-Oz`, and `-O2`, in all three feature
  modes: 153 comparisons, 42 smaller and 0 larger. Inputs are
  [`dev/near-store/shapes.c`](../../dev/near-store/shapes.c) and
  [`context.c`](../../dev/near-store/context.c).
- Final `-Os` size/machine-verifier census:

  | Mode | Successful pairs | Smaller | Larger | Total text delta |
  |---|---:|---:|---:|---:|
  | Default | 371 / 406 | 0 | 0 | 0 B |
  | a16 | 406 / 406 | 52 | 0 | −410 B |
  | xy16 | 406 / 406 | 52 | 0 | −413 B |

  Default output is byte-identical for every successful pair. Its 35 failures
  have identical legalization-error diagnostics before/after; native modes have
  no failures. In a16 and xy16 only the 52 smaller objects change code.
  [Complete census](../investigations/2026-09-25-near-store-census.tsv).
  The totals include the new fixture (−29 B in each native mode). The 405 existing
  inputs account for 51 improvements: −381 B in a16 and −384 B in xy16.
- `dev/regen-patch.sh` round-trip passes in both the isolated worktree and main
  checkout; only the legalizer and new lit test change within `0002` for this task.
  The comment-history check on changed lines and `git diff --check` pass.

## Reproduction

```sh
dev/run.sh toolchain
dev/run.sh lit vendor/llvm-mos/llvm/test/CodeGen/MOS/a16-byte-store.ll
dev/run.sh a16storebytes
dev/run.sh a16abs
python3 dev/measure-near-store.py BEFORE_INSTALL/bin AFTER_INSTALL/bin \
  --assets "$PWD/build" --out "$PWD/build/near-store-census"
```

`measure-near-store.py` compares all 406 C inputs in `examples/65816`,
`examples/snes/corpus`, and `examples/snes`, at `-Os -fno-lto` with machine
verification. It retains compile failures, disassembly, objects, and a JSON report.
Results describe individual object text sections, not linked ROM savings or
measured execution time. The cycle figures above use the existing static W65C816S
model in `dev/longx-shapes/cycles.py`.

The pre-change compiler is retained locally in
`build/near-store-review/baseline-install`; the candidate is in
`.scratch/near-store/build/llvm-mos-install`. Baseline clang SHA-256:
`38e2cf4138c99609082db7cd33625455a7b61fc49182b3f2307637d8a1c22555`.
Candidate and installed main clang SHA-256:
`98e39d7f635aff36aa8af24dfe2155a5f7bcc5a19795a8c95adc039569ec46ab`.
Final `0002` SHA-256:
`f1e691e432a89b677b44a1f983e6b99f155efd5fe75c23d2fe0e1f279208cde1`.
Logs and detailed local artifacts use `build/near-store-review/` and
`/tmp/near-store-*.log`.

## Subsequent atomic-store correction (2026-09-25)

During the indirect-store follow-up, OpenAI Codex found that this predicate
rejected a previously accepted register-valued atomic absolute word store:
`narrowScalar` cannot split an atomic access. The follow-up excludes atomic
stores and values shared with them from byte-only classification, with lit
coverage for absolute, indirect, and shared-value atomic stores. The earlier
validation above did not cover this input. The compiler/patch hashes above are
historical snapshots; the reused worktree and installed compiler advance with
the [indirect-store record](2026-09-25-near-indirect-s16-store-residency.md).

## Attribution

Claude: original discovery and size/cycle measurements in the far-scalar study.
OpenAI Codex: MIR diagnosis, store-use and call-preservation predicate,
implementation, regression tests, context counterexamples, validation, and this
follow-up documentation. Earlier Claude and Codex patch-stack credits are retained.
