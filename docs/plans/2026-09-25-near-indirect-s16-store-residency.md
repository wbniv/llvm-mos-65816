# Near indirect s16 argument stores

Owner: OpenAI Codex. Completed locally 2026-09-25.
Source, tests, patch bundle, docs, and installed main compiler are updated.
This is the next fix after the [absolute-store change](2026-09-25-near-s16-store-residency.md),
requested by the user on 2026-09-25. It records the implementation and its validation.

## Reproduced defect

`void set(unsigned short *p, unsigned short v) { *p = v; }` emits 13 bytes in
a16/xy16: spill A:X into an Imag16 pair, `rep`, reload, store indirectly, `sep`,
return. Default mode stores the two ABI bytes directly in 8 bytes:
`sta (dp); ldy #1; txa; sta (dp),y; rts`.

Baseline compiler SHA-256:
`98e39d7f635aff36aa8af24dfe2155a5f7bcc5a19795a8c95adc039569ec46ab`.
The baseline includes the completed absolute-store fix and reviewed patch stack.
Measurements and MIR snapshots are under `build/indirect-store-review/`.

## Implementation sequence

1. Reuse `.scratch/near-store` (`wt/321-near-store`), whose independent source and
   warm compiler match the starting main baseline. Preserve that compiler;
   keep unrelated uncommitted work intact.
2. Extend the byte-value profitability analysis in `legalizeLoadStore16` only for
   an explicitly supported plain near-pointer shape. Start with ABI pointers in
   an existing Imag16 register pair. Preserve native indexed selection and far
   addressing. Do not classify every 16-bit pointer as equivalent.
3. Check all uses of the stored value. Keep native producers, native arithmetic
   consumers, cross-block uses, calls, and inline-assembly preservation on their
   current paths. An absolute store must not be marked byte-only while a sibling
   indirect/indexed use still requires its native value.
4. Measure the candidate on the cases below before broadening the rule. If byte
   stores lose in a context, retain the native path with an explainable gate.
5. Add lit coverage for the winning shape and exclusions, plus a runtime fixture
   with nonzero high bytes, adjacent sentinels, aliasing, and near page crossings.
   Use the existing host/MAME/bsnes differential harness.
6. Compare the examples/corpus under default, a16, and xy16 with machine
   verification. Regenerate and round-trip `0002`, update the installed main
   compiler, rerun the focused gate, and record results and credits here and in TODO.

## Baseline and negative controls

All sizes include the return instruction, at `-Os`.

| Shape | Default | a16 | xy16 |
|---|---:|---:|---:|
| Plain or volatile indirect setter | 8 | 13 | 13 |
| Store and return value | 12 | 15 | 15 |
| Two indirect stores | 17 | 17 | 17 |
| Indirect plus absolute store | 19 | 18 | 18 |
| Constant offset `p[1]` | 26 | 15 | 15 |
| Runtime word index | 55 | 31 | 32 |
| Value retained across call | 50 | 48 | 48 |
| Conditional call before store | 54 | 52 | 52 |
| Store a call result | 31 | 36 | 36 |
| Native addition producer | 19 | 17 | 17 |
| Native volatile-load producer | 14 | 10 | 16 |
| Value also used by arithmetic | 18 | 22 | 22 |
| Independent native arithmetic before store | 30 | 23 | 23 |
| Pointer loaded through another pointer | 20 | 17 | 17 |
| Zero-extended byte value | 9 | 13 | 13 |
| Later argument stored, another argument used | 21 | 16 | 16 |

The reduced input contains 17 functions (plain and volatile are separate).
The indexed, loaded-pointer, later-argument, and native-context cases are controls,
not promises that this increment will optimize them. Mixed arithmetic-use cost
remains a separate follow-up.

## Acceptance

- The plain indirect setter reaches 8 bytes in a16 and xy16, without an Imag16
  value spill or REP/SEP bracket. Memory order, pointer preservation, high-byte
  value, and neighbouring memory remain correct.
- Reduced cases at `-Os`, `-Oz`, and `-O2` show no size regressions; measured native
  producers and indexed forms stay profitable.
- Default code stays unchanged. The example/corpus comparison has no newly failing
  compiles or size regressions; report actual counts and retained failures.
- Lit adds passing coverage; the four existing MOS failures are separately recorded,
  not silently rebaselined. Current suite baseline: 167 tests, 161 pass, 2 unsupported.
- Host == default/a16/xy16 on MAME == a16 on bsnes-jg for the new runtime fixture;
  retain the absolute-store runtime and native-copy controls.
- Patch round-trip, comment-history check, whitespace check, docs, and attribution
  are complete. Code/test comments describe present contracts rather than bug history.

## Implementation and validation results

The candidate recognizes a near pointer copied from a physical Imag16 pair and a
value merged from the ABI's A and X bytes. The only other value consumers may be
byte splits in the same block. Between that merge and each consumer, only copies,
debug instructions, byte splits, and the store itself are allowed. The gate runs
after indexed-address selection, so it cannot displace a native indexed form.
Atomic stores remain on the native path, including when an absolute store shares
a value with an atomic store.

The initial candidate allowed independent arithmetic before the store and grew
`native_context` from 23 to 24 bytes. The stricter instruction filter keeps that
case at 23. Multiple stores, native producers/consumers, later imaginary-register
arguments, calls, inline assembly, and cross-block uses retain native stores.
The call-result example also stays native: its intervening call-frame adjustment
is outside this deliberately narrow gate.

Atomic controls exposed two rejected-input cases: the initial indirect candidate
tried to narrow an atomic word store, and the preceding absolute-store fix had
introduced the same problem for an absolute atomic store. The compiler before
that absolute fix accepts the reduced absolute input; the immediate baseline
rejects it. `LegalizerHelper` refuses to split an atomic memory operation.
OpenAI Codex corrected both predicates and added indirect, absolute, and shared-value
atomic IR cases. All require a native single-instruction word store. This restores
previously accepted register-valued atomic stores; it does not add general atomic
support (constant atomic stores already fail on the pre-change native path).

Completed validation:

- 153 reduced function comparisons (17 shapes × three optimization levels × three
  feature modes): 18 smaller, 0 larger. Plain/volatile setters are 13→8 bytes;
  store-and-return is 15→12 bytes, in a16 and xy16 at `-Os`, `-Oz`, and `-O2`.
- New lit test rejects the baseline's spill/reload sequence. The candidate suite
  reports 168 tests: 162 pass, 2 unsupported, the same four existing failures:
  `legalizer.mir`, `scavenger-p-undef-6502.ll`, `shift-rotate.ll`, and
  `MC/MOS/addressing-modes-65816.s`.
- Runtime fixture: host `0x8509` equals default/a16/xy16 on MAME and a16 on bsnes-jg.
  Packed word subobjects at offsets 254 and 255 in aligned storage provide valid
  odd-address/page-crossing coverage; adjacent bytes are included in the hash.
  Linked native-mode maps place the odd word at `$02FF/$0300` and the even word
  at `$04FE/$04FF`; `put` is 8 B and `put_return` is 12 B.
- Full `-Os -fno-lto` example/corpus comparison with machine verification:

  | Mode | Successful pairs | Smaller | Larger | Total text delta |
  |---|---:|---:|---:|---:|
  | Default | 372 / 407 | 0 | 0 | 0 B |
  | a16 | 407 / 407 | 1 | 0 | −8 B |
  | xy16 | 407 / 407 | 1 | 0 | −8 B |

  All successful default objects are identical; its 35 failures have identical
  fatal diagnostics before/after. Both native modes compile every input. The only
  changed corpus object is the new fixture (581→573 B a16, 587→579 B xy16);
  existing inputs are identical. This conservative rule improves the measured
  setter shapes without claiming broad existing-corpus savings.
  [Complete census](../investigations/2026-09-25-indirect-store-census.tsv).
- Final main compiler matches the isolated candidate byte for byte. Both store
  lit files pass with the main build's tools. The installed main compiler passes
  `a16indirectstore` (`0x8509`) and `a16storebytes` (`0xDBA7`) across all four
  emulator legs; `a16abs` retains its native-copy disassembly and returns `0x5A3D`
  in MAME and bsnes-jg.
- `dev/regen-patch.sh` round-trip passes; this increment changes only the legalizer
  and adds `a16-indirect-byte-store.ll` inside `0002`. Changed comment-history,
  shell syntax, and whitespace checks pass.

Candidate and installed main clang SHA-256:
`5c1552885a1c273943ac3eb96c1e0778f96d010eca2f96f771e4a856fcacd0dc`.
Logs: `/tmp/indirect-store-runtime.log`, `/tmp/indirect-store-census-final.log`, and
`/tmp/near-store-lit.log` (the reused worktree's current suite run). Final main
build and checks: `/tmp/indirect-store-main-{toolchain,lit,runtime,absolute,native-copy}.log`.

## Reproduction and artifacts

```sh
dev/run.sh toolchain
dev/run.sh lit vendor/llvm-mos/llvm/test/CodeGen/MOS/a16-byte-store.ll \
  vendor/llvm-mos/llvm/test/CodeGen/MOS/a16-indirect-byte-store.ll
dev/run.sh a16indirectstore
dev/run.sh a16storebytes
dev/run.sh a16abs
python3 dev/measure-near-store.py BEFORE_INSTALL/bin AFTER_INSTALL/bin \
  --assets "$PWD/build" --out "$PWD/build/indirect-store-census" --jobs 4
```

The micro inputs are [`dev/near-store/indirect.c`](../../dev/near-store/indirect.c);
`build/indirect-store-review/micro-sizes.json` retains all 153 results. Compile at
`-Os`, `-Oz`, and `-O2`, with `-fno-lto -mllvm -verify-machineinstrs`, then compare
function sizes using `llvm-nm -S`. The census measures individual object text
sections, not linked ROM savings or measured execution time. Its source set has
407 inputs (406 existing inputs and the new runtime fixture).

The baseline install is retained in `build/indirect-store-review/baseline-install`;
the candidate remains in `.scratch/near-store/build/llvm-mos-install`. The final
census artifacts are in `build/indirect-store-review/census-final`. Atomic
before/after IR, assembly, and diagnostic logs are alongside them in
`build/indirect-store-review`. The earlier partial `census` directory describes
an intermediate compiler and must not be used for final results.

Final `0002` SHA-256:
`3564d9b502df3c6ff9722d2417bfbff0f13ab71e1471033d46800b94c2f2af28`.

## Attribution and submission scope

OpenAI Codex: indirect-store reproduction, diagnosis, implementation plan,
implementation, atomic-store correction, tests, validation, and documentation.
Claude: the original broader A:X store-cost finding in the [far-scalar study](../investigations/2026-09-25-far-scalar-split-measurement.md).
Preserve both attributions and the preceding absolute-store evidence.
This fork-feature fix belongs in `0002`; it does not authorize an upstream posting
or a SNES platform submission.
