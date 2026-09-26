# Independent preparation review: inline assembly 0056–0059

Review date: 2026-09-26. Reviewer: OpenAI Codex CLI 0.157.1, model
`gpt-6-astra`, `xhigh` reasoning effort; child session
`01a0db96-a6cd-7800-82a5-6b871eb7e177`, agent `/root/review_inline_asm`.
Tool version, model, and effort were verified from that child session's metadata.
This is a separate review pass using the same model family as the implementation,
not a human or different-model review. Earlier implementation credits remain in
the canonical records. Nothing was posted, pushed, or deployed.

Current disposition: the final exact LLVM packages passed the clean-base
validation audited in [the final follow-up below](#final-exact-llvm-package-validation).
0056/0057 are standalone; 0058/0059 remain stacked on 0057. The initial artifact
assessment and original replay evidence are retained below as dated evidence.

## Initial verdict and posting prerequisites

No implementation correctness defect was found in the reviewed bounds checks,
diagnostic recovery, unknown-type guards, or vector conversions. The existing
canonical fixed dispositions are supported by independently replayed matching-input
red/green evidence. The reviewed algorithms and regression content are approved.
This does **not** certify unexamined rebased artifacts or a build of current LLVM
main: the coordinating agent owns that preparation and validation.

| Item | Reviewed implementation | Exact posting-artifact disposition |
|---|---|---|
| 0056 | Approved | Vendor patch is not the upstream posting artifact; rebase the retained upstream-based variant, preserving upstream `OpInfo.RegClass` assignment and `getNumRegisters` call |
| 0057 | Approved | Applies to downloaded LLVM main source; final build checks remain; retain the `callbr` recovery hunk and full regression |
| 0058 | Approved | Full regression must be based on 0057 recovery; standalone guard-only posting must not claim the `callbr` tests pass without it |
| 0059 | Approved | Full original regression requires 0057; preserve that prerequisite and validate the extracted target-base artifact |

All four patches already contain only generic compiler/AArch64 source and tests.
They require no MOS test removal. The destination is `llvm/llvm-project`, not an
SNES platform submission. Earlier MOS validation remains supporting evidence,
not a reason to carry `llvm/test/CodeGen/MOS` or native-width features into these
four submissions.

The coordinator supplied current reference pins
`e59a0c697552ae7d1c3aeed5774e829cdc5e16b5` for LLVM main and
`7bd67c0ae4e8bb65a3f980912bf201df22131e34` for llvm-mos main. The follow-up below
inspects downloaded source from the LLVM pin and verifies application of
0057–0059; this reviewer did not fetch, modify, or build either pin. New source
adaptations need a corresponding review/test receipt before being called ready
to post.

## Findings and code audit

There are no P0/P1/P2 implementation findings. The following are concrete
packaging/dependency gates, not newly discovered compiler defects.

1. **Posting blocker for the unadapted 0056 vendor bundle.** At
   `patches/llvm-mos/0056-llvm-gisel-inline-asm-register-bounds.patch:30`, the
   vendor-context hunk lacks upstream's intervening `OpInfo.RegClass = RC`.
   The retained
   [upstream-based variant](../../defects/evidence/2026-09-25-shift-inlineasm-fixes/0056-upstream-based.patch)
   preserves that assignment and is a starting point, not a current-main-ready
   artifact: the current-main adaptation must also retain `getNumRegisters`
   instead of introducing the prior stack's `getNumRegistersForInlineAsm`.
   The upstream variant also avoids a duplicate diagnostic include. The
   vendor-versus-upstream distinction was already
   documented in the original investigation; it is not a new repair.
2. **Posting-order requirement for 0058 and 0059.** The 0058 `callbr` tests at
   `patches/llvm-mos/0058-aarch64-inline-asm-unknown-type.patch:40` require the
   0057 landing-pad recovery at
   `patches/llvm-mos/0057-llvm-selectiondag-inline-asm-register-bounds.patch:48`.
   The original 0059 64-lane regression at
   `patches/llvm-mos/0059-llvm-selectiondag-vector-asm-parts.patch:86` additionally
   requires 0057's unbounded virtual-register allocation. Explicit stacked PR
   prerequisites are sufficient for opening; prerequisite merges are separate.

The 0056 physical walk checks `I != end` before dereferencing and validates the
entire range before populating operands. Virtual allocation does not advance a
physical-class iterator. On diagnostic recovery, the uninserted invalid asm is
omitted and every result vreg receives an undef definition; returning success
here means translation recovered, not compilation succeeded. GlobalISel inline
`callbr` is unsupported in the inspected `IRTranslator`; this patch should not
claim to add that support.

The 0057 range check uses the existing register/type error route. Its landing-pad
guard intentionally uses context-wide error state, rather than proving that this
specific `callbr` failed. That broad recovery is acceptable for a compilation
already carrying an error; it must not be described as normal successful-code
lowering. In the inspected `LLVMContext::diagnose`, `HasErrors` is set before a
returning handler is called. With no returning handler, the error exits before
the landing pad. Scalar and aggregate recovery results remain well typed.

The two 0058 guards reject `MVT::Other` before any size query, without changing
known-type selection or named-register clobber handling. Unsupported integer
register types are rejected; this is not arbitrary-width inline-asm support.

The 0059 split/join checks retain the former assertions' count/type contract,
after custom target lowering hooks. Recovery constructs the requested vector
undef on joining and initializes every requested part on splitting. Equal-width
bitcasts occur before the lossy-conversion guard. The `CallBase` diagnostic
change includes `callbr`. Positive scalarized, floating-point, small-vector, and
LS64 paths remain in the test. No new vector ABI or runtime semantics are claimed.

## Reconciliation and immutable evidence

Reviewed the four existing canonical records and their original investigations:

- [GlobalISel register bounds](../../defects/gisel-inline-asm-register-bounds.json)
  and [original report](../../investigations/2026-09-25-shift-inlineasm-fixes.md).
- [SelectionDAG register bounds](../../defects/selectiondag-inline-asm-register-bounds.json)
  and [original report](../../investigations/2026-09-25-selectiondag-inlineasm.md).
- [AArch64 unknown type](../../defects/selectiondag-inline-asm-nonstandard-integer.json)
  and [original report](../../investigations/2026-09-25-aarch64-inlineasm-unknown-type.md).
- [Vector parts](../../defects/selectiondag-inline-asm-vector-parts.json)
  and [original report](../../investigations/2026-09-25-selectiondag-vector-parts.md).

Also reconciled the 0041 multi-register plan, TODO, upstream tracker, relevant
Git history, standalone patches, 0002 symbol searches, and live vendor source.
The four reviewed artifacts were published locally in repository commit
`8c19c703`; the fixes are already present in the live compiler source. No new
canonical record or discovery claim is warranted. Source/binary evidence uses
the preserved upstream-based builds described in those records, not a claim that
the preserved baseline is unpatched or current LLVM main. Earlier baselines and
records were not modified.

## Checks executed for this review

Fresh scratch results are under `build/post-ready-review-inline/`. They do not
replace the already tracked immutable evidence. The scripts use existing
binaries read-only, disable core dumps, and write only to this review's scratch
directory. No compiler sources or build libraries were modified.

| Check | Result |
|---|---|
| Exact original input and recorded SHA256 for each of four baselines and four candidates | All binary/input identities match |
| Original baseline replays | Four expected assertion aborts, each matching its canonical failure signature |
| Same-input candidate replays | Four normal compiler exits of 1 with the expected single diagnostic |
| Every RUN line extracted from the exact current four patch files | 49/49 commands pass: 4, 2, 19, 24 respectively; counts include two split-file setup commands |
| Seven SelectionDAG operand forms run independently at O0/O2 | 14/14 emit exactly the expected single diagnostic, including all three `callbr` forms |
| Additional GlobalISel aggregate/mixed-output recovery at O0/O2, abort/fallback modes | 4/4 invocations pass, each with two expected diagnostics and no verifier failure |

Reproduction commands for the fresh review:

```sh
python3 build/post-ready-review-inline/replay.py
python3 build/post-ready-review-inline/regressions.py
python3 build/post-ready-review-inline/recovery.py
```

The additional GlobalISel inputs were a live `{ i64, i128 }` result using
`"=r,={cc}"`, and a live valid i64 result with an invalid i128 input using
`"=r,{cc}"`. Both exercise result definition after an error on a later operand.
The existing broad cross-target suite results were inspected, not rerun by this
reviewer. Runtime execution is inapplicable to the rejected inputs. Positive
controls establish continued compilation, not a new runtime-correctness claim.

## Reviewed artifact identities

| Artifact | SHA256 |
|---|---|
| 0056 vendor patch | `5e9371ff0b8657706cb84b4fcaff87ede306f2b7b974f5e661e7afba6ac8d132` |
| 0056 retained upstream-based patch | `bf24ab99f8d8bc68c7bb8ddef83235fee2e234ac54b123fe768ed86fa3b6575c` |
| 0057 patch | `8c4213521cb578f7ff2c9acb331fa260087e286f943fcb2f775a841824bc5035` |
| 0058 patch | `87710e8424951a95f0a0f40a59b748817fbc46d76466c12b0f2ce0c92711251d` |
| 0059 patch | `2a3f0424702a4e714b91b4336e8b992b984455f541739707396b6a5774706162` |

## Current-LLVM-source applicability follow-up

Inspected the coordinator's downloaded LLVM main files under
`docs/pr-preparations/2026-09-26/upstream-source/llvm/` after the initial replay.
The coordinator subsequently retained these byte-identical source snapshots
with a `.txt` suffix as documentary evidence. The commands below record their
original unsuffixed scratch names; restore those names in a scratch directory
to repeat the apply check, or use the pinned upstream Git checkout.
Their exact inspected SHA256 values are:

| Source | SHA256 |
|---|---|
| `lib/CodeGen/GlobalISel/InlineAsmLowering.cpp` | `77a7c45827a3025b0fe83021d7846d837061d65f840e4412c28d1901eec3789c` |
| `lib/CodeGen/SelectionDAG/SelectionDAGBuilder.cpp` | `b01b4237aa23210613b16a4be3624d0b95f5d94e3e233735274aa2cb06f15047` |
| `lib/Target/AArch64/AArch64ISelLowering.cpp` | `40e88cc2bd7a833389c13435fe017d9ffa6d7767aa8a0f9321264cb7d6dc6c43` |

Independent read-only checks succeeded for the unchanged 0057, 0058, and 0059
patches, each against those downloaded sources:

```sh
git apply --check --directory=docs/pr-preparations/2026-09-26/upstream-source patches/llvm-mos/0057-llvm-selectiondag-inline-asm-register-bounds.patch
git apply --check --directory=docs/pr-preparations/2026-09-26/upstream-source patches/llvm-mos/0058-aarch64-inline-asm-unknown-type.patch
git apply --check --directory=docs/pr-preparations/2026-09-26/upstream-source patches/llvm-mos/0059-llvm-selectiondag-vector-asm-parts.patch
```

The 0059 prerequisite on 0057 is semantic and test-related; the source hunks do
not themselves require application of 0057 first. Neither SelectionDAG patch
depends on the GlobalISel changes in 0037 or 0041.

For 0056, current upstream already has `OpInfo.RegClass = RC` and an error helper,
but uses `TLI.getNumRegisters` at `InlineAsmLowering.cpp:129`. The earlier
stack-specific `getNumRegistersForInlineAsm` wrapper defaults to
`getNumRegisters`; neither inspected AArch64 implementation overrides it.
Preserving the current-main call and retaining the existing `RegClass` assignment
is the appropriate minimal adaptation. Do not import 0041's multi-register
lowering or 0037's indirect-output support into the bounds patch.

The four shipped 0056 negative functions do **not** need 0037 or 0041:

- Current upstream already reads the `elementtype(i128)` indirect operand at
  `InlineAsmLowering.cpp:272`, before any operand lowering.
- All four requests select the single-member NZCV class with an i128 value;
  the new range check rejects them at the call to `getRegistersForValue`
  immediately before the output/input switch at `InlineAsmLowering.cpp:335`.
- The tied case fails while allocating its output, before the single-register
  matching-input assertion is consulted. The direct and indirect output cases
  likewise return before result copying or any indirect-output store.
- The input-only case returns before the unsupported multi-register input path.
  Its call is void, so no recovery-result registers are needed.

The extra aggregate/mixed-output negative controls also fail before output
materialization, with the preceding valid i64 output allocated but not emitted.
This is source-level dependency analysis, not a substitute for the coordinator's
standalone assertion-enabled build. Positive multi-register or indirect-output
controls taken from the earlier patched stack must not be claimed as pristine
main coverage without separate checks; their successful lowering is a different
contract.

The coordinator owns registering this review's dependencies, integrating final
submission applicability/build receipts, and reviewing affected current
summaries. This reviewer did not alter maintained-summary receipts, the
dependency manifest, or the generated inventory.

## Final exact LLVM-package validation

The coordinator completed isolated Release/assertion-enabled builds on LLVM
`e59a0c697552ae7d1c3aeed5774e829cdc5e16b5`, with X86/AArch64 enabled and no
experimental targets. All runs pin image
`sha256:eeecfab76840167d9f16982b1efddae90d4969c5d7891ec16e87e46150ac94c1`.
The final packages and archived receipts are:

| Item | Final patch SHA256 | Focused candidate RUNs | Candidate filtered suite | Receipt |
|---|---|---|---|---|
| 0056 | `2407d97531303a071e4e7df3a3b9a45a3200fbafe8dae0a7cc9f8683fc0b058b` | 4 | 168 passed, 3 XFAIL | [receipt](validation/runs/post-ready-validation-llvm/0056/receipt.json) |
| 0057 | `8c4213521cb578f7ff2c9acb331fa260087e286f943fcb2f775a841824bc5035` | 2 | 168 passed, 3 XFAIL | [receipt](validation/runs/post-ready-validation-llvm/0057/receipt.json) |
| 0058 | `87710e8424951a95f0a0f40a59b748817fbc46d76466c12b0f2ce0c92711251d` | 19 | 169 passed, 3 XFAIL | [receipt](validation/runs/post-ready-validation-llvm/0058/receipt.json) |
| 0059 | `2a3f0424702a4e714b91b4336e8b992b984455f541739707396b6a5774706162` | 24 | 169 passed, 3 XFAIL | [receipt](validation/runs/post-ready-validation-llvm/0059/receipt.json) |

0056 retains the current `getNumRegisters` API and existing `OpInfo.RegClass`
assignment. Its exact-main build is standalone, without 0037 or 0041. 0057 is
also standalone. For 0058 and 0059, **both baseline and candidate include 0057**;
only their own change differs within each comparison. The receipt dependency
hash is exactly the 0057 packet hash in the table. Neither needs the other.

The baseline failures are causal compiler failures, not just FileCheck errors:

- 0056 reaches `InlineAsmLowering.cpp:148`, the physical-register exhaustion
  assertion `Ran out of registers to allocate!`.
- 0057 reaches the corresponding SelectionDAG assertion at
  `SelectionDAGBuilder.cpp:10290`.
- 0058 reports `Value type is non-standard value, Other` followed by
  `MachineValueType.h:375`'s unreachable path, while 0057 is already applied.
- 0059 reaches `getCopyToPartsVector` at `SelectionDAGBuilder.cpp:775`, asserting
  that the part type matches the vector breakdown, while 0057 is already applied.

Each baseline stops at its first failing regression RUN (0058/0059 first run
`split-file` successfully). All 49 candidate RUNs pass, including those two
setup commands. Negative inputs produce the expected ordinary diagnostics;
the 0058/0059 positive controls still compile. The existing broader historical
independent per-form checks remain distinct evidence, not fresh exact-main
baseline totals.

The suite filter is `(inline.?asm|asm-goto|callbr)` over AArch64 and X86.
Standalone baselines have 167 passes plus three expected failures; 0057-based
baselines have 168 passes plus three expected failures. All candidate suites
have zero unexpected failures and exclude 9,786 unrelated tests. These are
filtered suites, not full target, all-target, runtime or upstream-CI results.

Final audit rehashed the four patches and prerequisites, all eight baseline/
candidate test snapshots, and 71 referenced logs in both local and archived
copies. Every test snapshot also matches the input reconstructed from its
patch. Archived runners and configurations match; the 32 `llc`, `FileCheck`,
`not`, and `split-file` tool snapshots rehash to their receipt identities.
The pristine LLVM baseline `llc` is
`93b6a35c447f85042c65830e1daea85e0f6103c1fb380c3df78cec658009c81c`;
the 0057 candidate and 0058/0059 baselines are
`8d358a8087e1fde481949a09022b399d52d34e1feed22fca9c1ae9b6fb4c3be6`.
The receipts identify every corresponding candidate binary and command.

Build/test execution: OpenAI Codex CLI 0.157.0 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort; coordinator session
`01a0db16-f6a0-7e32-ada6-0c8098813933`. Final independent receipt/source audit:
the reviewer identified at the top; no compiler build or test rerun was performed
by this audit. Its read-only checker is
`build/post-ready-review-inline/audit-llvm-final.py`.

**All four exact packages are approved and ready to post, unposted.** 0058/0059
must advertise their 0057 stacking/merge prerequisite. None of these results
authorizes publication or changes the separate #320/#321 presentation hold.
