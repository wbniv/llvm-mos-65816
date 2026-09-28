# Broader near-store profitability (T3)

Date: September 27, 2026. Status: complete, committed and pushed to downstream `main`; upstream extraction and independent review remain separate.

Requested by the user to finish the [T3 item](../../TODO.md#M2--Optimizing-Payoff).
Plan and subsequent work: OpenAI Codex CLI 0.157.1 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort; verified session
`01a0e0ee-df60-7d80-8629-5ad167a8c407`. Earlier contributors retain the credits
in the linked records.

## Upstream preparation follow-up — September 28, 2026

The [0065 review packet](../pr-preparations/2026-09-28/0065/README.md) completes extraction with native-only #321 prerequisites and 0063, reconciliation against upstream `26d7c2c1eebf98ca194b92609ba4e7540bfc6ef6`, fresh validation, and a separate independent 0065 review. The extracted series passes 145 supported MOS tests; the 486-function replay has 72 smaller and zero larger results, loaded pointers remain native at 17 B versus 22 B, and all six emulator assertions return `0xFA36`. The compiler PR remains unposted, its #321/0063 merge dependencies remain explicit, and the native feature posting hold remains in force. The September 27 implementation, binaries, baselines, and measurements below are preserved dated evidence.

Preparation attribution: OpenAI Codex CLI 0.158.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e75a-a9ed-7372-9bac-b19b732a46a2`.

## Repository delivery and remaining upstream work

The implementation, regression tests, retained evidence and current summaries
were committed as [4d7136cb](https://github.com/wbniv/llvm-mos-65816/commit/4d7136cb15cf85a676b624a5892e5e8ce7ae0217)
and pushed to `wbniv/llvm-mos-65816` branch `main` on September 27. The commit
passed the comment-history, defect-evidence, document-dependency and SNES
display-quality hooks. T3 implementation and validation are complete.

**September 27 prerequisite list (completed by the September 28 packet above):**

1. Extract it with the #321 native-width prerequisites and 0063.
2. Reconcile and validate the extracted change against the exact destination
   revision, including its guards, callers, tests and history.
3. Obtain independent review of 0065; the retained 0063 review covers its own
   artifact.

The compiler PR remains unposted. The downstream push does not change these
submission prerequisites or the separate SNES platform track.

## Outcome and completion rule

Decide whether byte stores improve each remaining near-memory shape under
`+mos-a16` and `+mos-xy16`. Implement narrowly supported wins and retain native
lowering where measurements favor it. Each case needs a recorded decision,
compiler identity, reproducible inputs, and measurements. A measured decision
to retain native lowering completes a case. Merely leaving a restrictive
predicate in place does not.

Close T3 after all cases have a disposition, accepted changes pass the checks
below, the tracked patch stack recreates the implementation, and current
summaries agree with the evidence. Isolated #321 extraction and upstream
publication remain separate work.

## Reconcile the existing work

- [Absolute stores](2026-09-25-near-s16-store-residency.md): direct byte-built
  stores, including an absolute store of a call result, are already optimized.
  The simple argument setter measured 14 to 7 bytes. This implementation is
  carried in `0002`.
- [Indirect stores](2026-09-25-near-indirect-s16-store-residency.md): a plain
  pointer argument and A:X value already use byte stores; the setter measured
  13 to 8 bytes. Calls, arithmetic consumers, loaded pointers, and zero-extended
  bytes remain outside the narrow predicate. Atomic exclusions are implemented.
- [Patch 0063](../../patches/llvm-mos/0063-mos-near-shared-store.patch): an absolute
  store followed by unit increment can stay in bytes. It is present in the live
  legalizer. The [September 26 review](../pr-preparations/2026-09-26/native-optimization-review.md)
  establishes that ordinary decrement becomes `G_ADD -1` and misses the
  positive-one predicate.
- Search the structured defect registry, original investigations, TODO/upstream
  summaries, Git history, standalone patches, and live `legalizeAddSub`,
  `legalizeLoadStore16`, `isByteBuiltStoreValue`, and `isByteIndirectStore`
  implementations before changing code. Preserve the search results with the
  measurement evidence. Reuse an existing canonical defect if a correctness
  failure is encountered; a new source shape alone does not justify a new record.

The tracked checkout was clean when this task began at `624f4006`. The vendor
checkout contains the integrated patch stack. Existing binaries must be
identified and checked against that source before serving as a baseline.

## Cases to resolve

The sizes below are September 25 evidence at `-Os`, including return. They are
orientation for the new comparison, not measurements of a new candidate.

| Case | Representative source | Historical default / a16 bytes | Work required |
|---|---|---:|---|
| Indirect store and arithmetic | `*p = v; return v + 1;` | 18 / 22 | Compare coordinated store/arithmetic narrowing against native lowering; check increment and decrement, returned and additional uses. |
| Indirect store of call result | `*p = produce();` | 31 / 36 | Inspect pointer preservation and call-frame adjustment; allow only a measured safe result-to-store sequence. Distinguish this from keeping a value alive across a call. |
| Loaded pointer | `**p = v;` | 20 / 17 | Measure pointer materialization and A:X clobbers. Keep native lowering if the complete sequence remains cheaper. |
| Zero-extended byte | `*p = byte_value;` | 9 / 13 | Measure a byte store plus zero high byte, including argument and loaded-byte producers, and inspect extension legalization. |
| Absolute store and decrement | `g = v; return v - 1;` | Re-measure | Evaluate canonical `G_ADD -1` alongside literal `G_SUB 1`; keep the arithmetic and store predicates consistent. |

Use [`dev/near-store/indirect.c`](../../dev/near-store/indirect.c),
[`shapes.c`](../../dev/near-store/shapes.c), and
[`context.c`](../../dev/near-store/context.c) as starting inputs. Include multiple
stores, mixed absolute/indirect uses, later ABI arguments, volatile operations,
native arithmetic/load producers, indexed pointers, calls, inline assembly,
and cross-block uses as controls.

## Work sequence

### 1. Preserve and reproduce the baseline

- [x] Retain compiler tools and resource headers, hashes, version output, vendor
  revision and diff, patch hashes, build configuration, and container identity
  under `build/near-store-broad/`. Keep the baseline immutable.
- [x] Compile the five cases and controls in default/a16/xy16 modes at
  `-Os`, `-Oz`, and `-O2`, without LTO and with machine verification. Retain
  source, preprocessed input, IR, relevant legalized MIR, assembly, objects,
  commands, exit statuses, and diagnostics.
- [x] Record current sizes and static cycle estimates, stating branch-path and
  timing assumptions. Keep estimates separate from measured emulator timing.
- [x] If a compiler correctness failure or defect status change is involved,
  capture its trigger before a fix and follow the
  [defect evidence workflow](../howto-defect-evidence.md), including `prior_work`
  and matching-input baseline/candidate evidence in the canonical JSON record.

### 2. Measure candidate rules

- [x] Change one source-shape rule at a time and retain its exact diff and
  measurements. Inspect final assembly and legalized MIR to identify why a
  sequence wins or loses.
- [x] Keep the arithmetic and store decisions consistent when a value has both
  consumers. Account for preservation of the original value and branch costs.
- [x] Accept a rule only when the targeted complete sequence improves without
  unexplained losses in the reduced controls. If a broader rule loses, either
  constrain it with a defensible predicate or retain native lowering and record
  the counterexample.
- [x] Give every case a final disposition: implemented, already covered, or
  measured native preference. An unresolved experiment keeps T3 open.

### 3. Validate accepted changes

- [x] Add focused LLVM IR/MIR tests for each accepted boundary and relevant
  exclusions, with machine verification in default/a16/xy16 modes. Verify that
  a new optimization expectation fails on the preserved baseline for the
  intended code-generation reason and passes on the candidate.
- [x] Run the focused near-store tests and the full MOS lit suite. Compare any
  failures against the actual captured baseline; historical suite counts are
  not the current baseline.
- [x] Extend the existing runtime fixtures as needed to execute changed paths:
  high-byte values, `0x00ff`/`0x0100` carry and borrow, `0xffff` wrapping,
  zero-extended values, call results, aliases, and adjacent sentinels. Preserve
  valid odd-address and near-page-crossing inputs.
- [x] Require host == default/a16/xy16 on MAME and native-mode checks on bsnes-jg.
  Run the absolute, indirect, and native-copy gates (`a16storebytes`,
  `a16indirectstore`, `a16abs`); use the existing harness for added cases.
- [x] Run `dev/measure-near-store.py` on the preserved baseline and candidate.
  Require unchanged successful default code, no new compile/verifier failures,
  and no unexplained size losses. Report the actual corpus count, failures,
  improvements, regressions, and total text delta. Corpus object sizes do not
  establish linked ROM savings or runtime speedups.

### 4. Integrate and close

- [x] Carry the accepted changes in a reproducible tracked patch, preserving
  the standalone 0063 lifecycle and the `0002` regeneration rules. Update
  bootstrap/regen registrations if a new standalone artifact is used. Check a
  complete patch round trip against live source and tests.
- [x] Rebuild and identify the installed compiler; repeat the focused tests and
  runtime gates with that compiler. Preserve the tested candidate identity.
- [x] Retain a compact measurement report and evidence manifest in Git; link
  larger local artifacts and give their reproduction commands and hashes.
- [x] Update the original absolute/indirect plan entry points with dated links
  to the result, preserving their historical measurements and attribution.
  Update TODO, the pending-work summary, dashboard curation, and affected
  pending PR drafts or previews without changing already-posted PR bodies.
- [x] Follow the [document dependency workflow](../howto-document-dependencies.md):
  inspect impacts, register this maintained plan and any new summaries/views,
  record substantive reviews, regenerate outputs, refresh the inventory, and
  check the staged sources, derivatives, receipts, and inventory together.
- [x] Run comment-history, defect-evidence, dependency, and whitespace checks.
  Mark T3 complete only after the results above are recorded.

## Contracts to preserve

Atomic word stores remain one memory operation. Values live across calls or
inline assembly retain valid preserved storage. A merge of byte values alone
does not establish physical A:X residency after intervening work. Native
arithmetic/load producers and profitable indexed forms retain appropriate word
lowering. Replacement operations preserve memory metadata and volatile order.
Default 8-bit code generation remains unchanged by native-feature rules.

Code and test comments describe those current contracts and the inputs under
test. Investigation history belongs in this plan, evidence records, or commit
messages. This task does not include publishing a PR or submitting SNES platform
implementation/configuration.


## September 27 results

[Canonical missed-optimization record](../defects/mos-near-store-profitability.json)
contains matching-input baseline/candidate code-generation checks and the prior-work
reconciliation. This migrates the existing T3 work into its first structured record;
it is not a new wrong-code finding. Patch
[0065](../../patches/llvm-mos/0065-mos-near-store-profitability.patch) is a separate
extension after 0063. The earlier 0002 and 0063 artifacts retain their scopes.

| Case, `-Os` | Baseline bytes | Candidate bytes | Decision |
|---|---:|---:|---|
| Indirect store, return `v + 1` | 22 | 18 | Byte store and byte arithmetic. |
| Indirect store, return `v - 1` | 22 | 21 | Native store followed by byte arithmetic. |
| Indirect call-result store | 36 | 31 | Ignore only zero-size call-frame teardown when checking the local byte sequence. |
| Indirect call-result store and return | 38 | 35 | Preserve the returned low byte through the stores. |
| Store through a loaded pointer | 17 | 17 | Keep native; an explicit byte-store alternative measured 22 bytes in both native modes. |
| Indirect store of a byte argument | 13 | 9 | Extend the ABI byte with a zero high byte. |
| Indirect store of an absolute byte load | 16 | 13 | Read the source once, then store the low byte and zero. |
| Indirect store of an indirect byte load | 15 | 11 | Preserve source-read/store order, including aliases. |
| Absolute store, return `v - 1` | 24 | 14 | Recognize canonical `G_ADD -1` as a unit step. |

These sizes match in a16 and xy16. The 54 functions at three optimization levels
and three feature modes produce **486 comparisons: 72 smaller, zero larger**.
The static fall-through estimates also decrease for the changed shapes; they
exclude callee execution and page penalties and are not measured execution times.
The [micro runner](../../dev/measure-near-store-shapes.py) retains its commands,
inputs, preprocessed source, IR, legalized MIR, assembly and objects.

The loaded-pointer experiment deliberately keeps the pointer load native while
splitting the destination store in LLVM IR. Its complete 17 versus 22 byte
comparison is retained in the
[evidence](../defects/evidence/2026-09-27-near-store-profitability/loaded-pointer/results.json).
Native-context, indexed, multiple-store, native-result, and call-live controls
remain unchanged in the reduced measurements. Atomic controls in the existing
near-store tests retain their single word operation.

An indirect decrement with both operations split measured 22 bytes. The accepted
21-byte sequence commits its one native store while legalizing the arithmetic.
A trial that changed the existing instruction descriptor was rejected by the
legalizer worklist; the accepted implementation builds an observed replacement
and erases the generic store. The rejected trial and its binary remain under
`build/near-store-broad/rejected-setdesc/`. This was an implementation experiment,
not an independently discovered compiler defect or a shipped regression.

### Corpus and runtime evidence

The `-Os -fno-lto` corpus comparison used machine verification:

| Mode | Successful pairs / inputs | Smaller | Larger | Text delta |
|---|---:|---:|---:|---:|
| Default | 375 / 412 | 0 | 0 | 0 B |
| a16 | 410 / 412 | 1 | 0 | -35 B |
| xy16 | 410 / 412 | 1 | 0 | -35 B |

The only changed corpus object is the new `a16storebroad.c` fixture, 1041 to
1006 bytes in both native modes. Existing successful corpus inputs have identical
disassembly. Every failed pair has the same diagnostic. The two native failures
are the already-recorded farblit byte-load rejection and a register-allocation
failure in `lzss-gallery.c:record_result`; neither is repaired or reclassified by
this optimization. The default mode has 37 matching failures.
[Full summary and diagnostics](../defects/evidence/2026-09-27-near-store-profitability/census-summary.json).

The supported baseline MOS suite passed 178 tests; the candidate passes 179 with
the added regression. Both have two unsupported tests. The regression passes in
default mode on both binaries, fails its native code-generation expectations on
the baseline, and passes both native modes on the candidate.

The new runtime fixture returns **0xFA36** on the host, default/a16/xy16 MAME,
and a16/xy16 bsnes-jg. It checks high bytes, carry/borrow and wrapping inputs, source
and destination aliasing, a packed word at a page boundary, and adjacent sentinels.
Existing indirect-store (**0x8509**), absolute-store (**0xDBA7**) and native-copy
(**0x5A3D**) gates also pass on both emulator cores.

### Toolchains and reproduction

The preserved baseline Clang SHA-256 is
`be9d0fa4025965ba6c588d4aa1c2c47f845d6256b8a3a7920498e5400e8a019a`;
the candidate Clang SHA-256 is
`f78b40b726eaee8dce6fa0a471759b39c83fe7c5b88c83ef3452e6481217cffa`.
Both are Release builds with assertions off; every relevant compiler invocation
uses machine verification. Their complete identities are in the linked record.
The baseline binaries/resource headers and the candidate binaries remain in
`build/near-store-broad/{baseline,candidate}`. Larger intermediate artifacts,
commands and the full corpus objects remain in `build/near-store-broad/`.

```sh
python3 dev/check-near-store-profitability.py build/near-store-broad/baseline/bin \
  docs/defects/evidence/2026-09-27-near-store-profitability/a16-near-store-profit.ll
python3 dev/check-near-store-profitability.py build/near-store-broad/candidate/bin \
  docs/defects/evidence/2026-09-27-near-store-profitability/a16-near-store-profit.ll
python3 dev/measure-near-store-shapes.py build/near-store-broad/candidate/bin \
  --out build/near-store-broad/replay-micro
python3 dev/measure-near-store.py build/near-store-broad/baseline/bin \
  build/near-store-broad/candidate/bin --assets "$PWD/build" \
  --out build/near-store-broad/replay-census --jobs 4
dev/run.sh a16storebroad
```

The first command intentionally fails the optimization expectations. The patch
round trip recreates the live MOS directory and focused tests. Regeneration only
lengthened 0002's Git index hash abbreviations; its non-index content was checked
byte for byte and the original artifact was retained. No source change was folded
into 0002. At this September 27 checkpoint, compiler #321 extraction, destination
reconciliation and independent review remained prerequisites; the September 28
follow-up above records their completion for this packet.

Installed-toolchain confirmation: installed Clang SHA-256 is `55ed2de7987a0785d8f960d9d304d89d0fff5801469e70832f27cad6d299c825`. It differs from the preserved candidate by exactly one byte: installation removes the trailing colon from the ELF RUNPATH string. All four runtime gates pass again with the installed tools; an additional xy16 bsnes-jg run also returns 0xFA36. The refreshed tool set repeats 179 MOS passes and two unsupported tests. [Installed identities and results](../defects/evidence/2026-09-27-near-store-profitability/installed/results.json).
