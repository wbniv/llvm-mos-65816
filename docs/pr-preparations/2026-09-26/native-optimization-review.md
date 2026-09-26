# Independent native-memory optimization review

September 26, 2026. Reviewed the existing 0061, 0062, and 0063 artifacts,
their live implementations, prior measurements, and focused regressions.
No compiler source, shared build, existing binary, or patch was changed by this
review. No upstream post, push, pull request, issue, comment, or deployment was made.

## Verdict and scope correction

Approve 0061 and 0062's implementations for their explicitly feature-dependent
series. Approve 0063 for the narrower **store followed by unit increment** scope.
The ordinary decrement shape is not optimized: IR canonicalization produces
`G_ADD -1`, while both new predicates require a constant positive one. It retains
correct native lowering. The coordinator chose to qualify the submission scope
rather than widen this optimization during preparation.

This approval is **not completion of #320/#321 extraction**, an isolated build of
those prerequisites, or approval to submit SNES platform implementation/configs.
The clean upstream MOS build does not contain these far-pointer and native-width
features. A patch can be source-reviewed and locally validated without being
independently applicable to current upstream.

| Exact artifact | Required compiler infrastructure |
|---|---|
| 0061 far-global `long,X` | #320 far address-space/data-layout/legalizer support; **#321 index-width machinery is also required by this exact patch**, which references `HasIndex16`, `Xc16`, and `XLow`. Its X8 subset could be separated, but this artifact is not that subset. |
| 0062 native far words | #320 far pointers and #321 accumulator/register/REP-SEP machinery, directly on 0061's generic indexed-opcode family. Its X16 forms also require the index-width slice. |
| 0063 near shared store | #321 native s16 legalization and the earlier absolute byte-store residency gate already carried in 0002. No far-address-space feature is needed. |

The `mos24()` printer and constant-modifier parser repairs (0044/0039) must also
be present when validating assembly round trips. Native immediate printing and
the existing mode-insertion implementation remain prerequisites of the native
series. `+mos-xy16` implies `+mos-a16`; it does not make the ambient ABI index
width permanently sixteen bits.

## 0061: range and addressing proof

The matcher retains a 24-bit constant/global base and accepts at most one
nonconstant offset. Constant displacement nodes are accumulated in the base,
not truncated into the index. It runs before the runtime-pointer `[dp],Y`
matcher, avoiding a needless pointer materialization for absolute bases.

| Offset form | Bound / action |
|---|---|
| Zero-extended i8, including a zero-extending byte load | 0 through 255: X8 |
| Zero-extended i16 | 0 through 65535: X16 only with `hasIndex16()` |
| A left shift by exactly one of a zero-extended i8 | 0 through 510: construct an s16 index, X16 only |
| Sign extension, unsupported scale, another variable offset, or unproven width | Reject the fold and retain pointer-address computation |
| Twice an unrestricted zero-extended i16 | May reach 131070, so cannot use X16; retain pointer-address computation |

The selected pseudos use explicit long encodings rather than relying on section
bank relaxation. Their typed X8/X16 operands and `XLow` flags feed the existing
mode insertion pass. That pass's memory/index-register classification enforces
X8 for byte-indexed accesses, while X16 pseudos request a bracket. Calls and
returns require the ABI's X8 state. Keeping the original memory operand on each
replacement preserves its alias, volatile, and ordering information. Extracting
a byte from an existing zero-extending load uses the existing register result;
it does not introduce another memory read.

No pointer-hoist or no-wrap claim is made. The separate
[pointer-hoist measurement](../../investigations/2026-09-25-farptr-hoist-measurement.md)
remains relevant: sixteen-bit wrapping integer arithmetic cannot generally be
reassociated into a wider pointer base plus another index.

The [long-X measurements](../../investigations/2026-09-25-longx-global-measurement.md)
compare compiler output with hand-written target shapes. Their large byte/cycle
potential is not a measured before/after result for 0061. In particular, the
exact implementation has no physical-X-free profitability predicate; register
allocation preserves live values, but this review does not prove a no-size-loss
bound under arbitrary pressure or scheduling. The earlier measurement's
recommended X-residency gate is not silently certified as implemented.

## 0062: width, memory, and ABI contracts

Native far accesses use dedicated `Ac16` long pseudos for absolute, absolute-X,
indirect-long, and indirect-long-Y forms. They do not flow through the near-only
STZ, X/Y load/store, or memory-RMW selection paths. Every native pseudo requests
`MLow`; the X16 variants additionally request `XLow`. Runtime far pointers are
kept in the far pointer register class, and physical address operands retain
their long width.

Loads used only by byte unmerges keep the byte path when non-atomic. Non-atomic
stores built directly from byte merges likewise avoid a wide spill/reload.
Other producers can use the native path. These are structural profitability
heuristics, not a complete live-register residency analysis; especially for
far stores, a merge is not proof that its bytes remain physically in A:X across
arbitrary surrounding work.

Atomic accesses are excluded from constant-store narrowing, all-unmerge load
narrowing, and byte-built far-store classification. The review's unordered
far-atomic argument store, constant-zero store, and returned load each retain
one native word access. This is a test of the supported word-access contract,
**not a claim of general atomics support, a hardware bus-lock guarantee, or a
cross-target memory-model audit**.

Replacement loads/stores retain the original machine memory operand. The shared
load-to-store folding helper refuses volatile source loads and does not move a
load across calls, side effects, ordered memory, or conflicting aliases. New
nonvolatile far-copy probes verified the direct native transfer; a volatile
store barrier kept the far load above the barrier rather than folding it below.
The separate volatile-order control retained both source reads and both
destination writes in order.

The [far-word measurement](../../investigations/2026-09-25-far-scalar-split-measurement.md)
retains the earlier two-emulator bank-seam evidence. Source inspection of the
vendored bsnes-jg `LongRead16`, `LongWrite16`, `IndirectLongRead16`, and
`IndirectLongWrite16` confirms low-byte then high-byte access through the full
long address, including carry into the next bank. This review did **not** rerun
that emulator experiment. The old hand-written target sizes/cycles remain
dated measurements, not fresh compiler-generated performance numbers.

## 0063: the supported increment and the decrement fallback

The optimization requires an s16 value merged from the ABI A/X bytes, local
absolute non-atomic store users, and the positive-unit arithmetic pattern.
Native producers, calls/inline assembly in the checked interval, atomic stores,
and unsupported uses keep their native lowering. Changing the arithmetic
lowering does not move or remove the store, change its value, or bypass its
memory metadata. SSA use/def tracking still preserves the original value when
needed later.

The supplied `store_mixed` test checks the positive increment and passes in
default, a16, and xy16 modes. The new decrement probe demonstrated why the
broader `+1/-1` preparation wording needed qualification:

```llvm
store volatile i16 %value, ptr @nearword, align 1
%result = sub i16 %value, 1
ret i16 %result
```

After IR translation, the arithmetic is:

```text
%4:_(s16) = G_CONSTANT i16 -1
%5:_(s16) = G_ADD %0, %4
```

Both 0063 gates use `isOne()`, so the compiler emits the original native
store/decrement sequence. Although a literal `G_SUB` with RHS one matches the
source predicate, ordinary LLVM IR subtraction by one does not normally reach
that spelling after canonicalization. The initial byte-path expectation fails
in both native configurations; that observation is preserved separately from
the final test that explicitly checks the expected native fallback. This is
an optimization limitation, not a new wrong-code defect or a claim that the
decrement feature was repaired here.

The earlier [absolute](../../plans/2026-09-25-near-s16-store-residency.md) and
[indirect](../../plans/2026-09-25-near-indirect-s16-store-residency.md) residency
fixes and their atomic corrections were read before this audit. Their historical
census/runtime results are retained with their original compiler identities;
this review does not attribute those executions to 0063 or to this reviewer.

## Fresh execution evidence

Used the existing integrated `build/llvm-mos/bin/llc`, SHA-256
`f965b29659e9fc708b595f705393b3bcabf3d414e1acac14217e97c22b57d445`.
It reports an optimized, assertions-off LLVM 23 build. Its executable was read
only; no fresh isolated or assertions-on native compiler was built here.

Scratch work is under `build/post-ready-review-mos/`. New 0061/0062 tests were
extracted from the patches and byte-compared with the live files. Existing
`a16-byte-store.ll` and `a16-indirect-byte-store.ll` were copied into a separate
execution tree, preserving the existing negative/atomic/call/ABI controls.

```sh
build/llvm-mos/bin/llvm-lit -v \
  -o build/post-ready-review-mos/native-current-lit.json \
  build/post-ready-review-mos/native-tests
```

**Result: five tests passed, zero failed.** Four are the existing regression
files. The fifth contains eight review controls, each checked under a16 and
a16+xy16: signed-byte offset fallback, doubled-i16 offset fallback, three far
atomic word cases, decrement fallback, call-preserved increment, and volatile
access ordering. Every RUN enables the machine verifier.

Four additional nonvolatile copy/barrier functions in
`native-copy-controls.ll` compile with machine verification in both native
modes. Inspection confirms native far-to-near, far-to-far, and
global-far-to-runtime copies, with a volatile barrier retaining the source load
before the intervening store. No runtime execution, new full-suite sweep, or
performance census was performed in this review.

Local evidence hashes:

```text
6eea467516667d7e92a6c7a6918d97de7d865dcf7c05b3457e2f96cd507ddad2  native-current-lit.json
f958bcb985620e8728869ef846bdc20a41424e91b9e8019043459ca599cf0a3f  native-controls-lit.json (initial decrement expectation failure)
99bfef155ce6b7b1b153e69c2b8ccddce92a3f024a736656f8f533e0ef52a7ea  native-tests/review-controls.ll
59270b609d4a065bcadcd8d075a5428445a50c94df196a0dae56c5187c4caee0  native-decrement-byte-expectation.ll
```

Reviewed patch SHA-256:

```text
c3fcae16d1e50d5f0eb97e33368672671cea7cb029e3567caa173f98279d99a9  0061-mos-far-global-long-x.patch
90ef140c82330e3115443acc71bc48ef50d5ebe99e78c2939dfe6c37a1f33236  0062-mos-native-far-word.patch
90ce87eb40a11216f79f8c46b5876c9930a8589ab920024421aa5eb031ee68ca  0063-mos-near-shared-store.patch
```

## Published supporting evidence

The published [Bank-Boundary Walk](https://biohack.net/snes/bankwalk/) documents
forward, reverse, and indexed reads across a 64K seam, with host/a16/xy16 results
agreeing on MAME and bsnes-jg. The published
[Bank/Direct-Page Windows](https://biohack.net/snes/dpbank/) exercises interrupt
entry/restoration while direct-page and data-bank state differ from the normal
C ABI. Both pages were fetched read-only during this review.

These are useful demonstrations of the prerequisite far-addressing and ABI
contracts. They are not asserted to have been rebuilt with the reviewed patch
hashes, and their publication does not discharge native-series extraction or
SNES platform merge prerequisites.

## Attribution and handoff

This independent source review, scratch controls, fresh compiler replays, and
scope finding were performed by **OpenAI Codex CLI 0.157.1 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort**, agent `/root/review_mos`, verified
from session `01a0db96-e0ef-75e2-89ad-2939c4954446` metadata and turn context.
Earlier authors' measurement, implementation, emulator, and demo credits remain
in the linked records; this review does not replace or infer their tool metadata.

The coordinator owns narrower current-summary/draft wording for 0063, exact
feature-prerequisite packaging, retained submission evidence, document dependency
registration, and inventory refresh. No current summary or canonical defect
record was altered by this reviewer.
