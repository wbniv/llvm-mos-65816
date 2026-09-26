# Independent MOS submission-artifact review

Reviewed September 26, 2026. No upstream post, push, pull request, issue, comment,
or deployment was made. This is an audit of existing repairs, not a new defect
discovery or a replacement for their preserved baselines.

## Verdict

The implementations in 0039, revised 0043, 0044, revised 0046, revised 0047,
and 0050 are approved on source review and the replays below. Refreshed isolated
compilation and final submission packaging belong to the preparation coordinator;
this reviewer did not perform a new compiler build. Two scope distinctions must
survive that packaging:

- 0050's upstream test must omit the two downstream native-width feature RUNs.
  0049 is a backport of already-upstream prerequisites, not an additional new
  contribution to post.
- 0051 is a repair to the downstream wide-index decomposition. It is **not a
  standalone upstream defect**: upstream already handles the byte-sized index.
  Preserve the local repair and its regression with the feature that needs it.

| Artifact | Review disposition |
|---|---|
| 0039: constant modifier width | Approve. Modifier width now constrains the candidate encoding before constant evaluation. This preserves the addressing-mode distinction when page wrapping matters. |
| 0043: inline-asm register width | Approve revised artifact. Single-letter and explicit physical names are both checked; named register pairs, flag extension, and untyped clobbers retain their contracts. |
| 0044: long-address printing | Approve. Disassembly constants and bare symbolic MC operands receive the needed width marker. Its low-constant reassembly coverage depends on 0039; make that dependency explicit. A supplementary symbolic MIR regression is recommended below. |
| 0046: fixup table completeness | Approve. The explicit zero-width `AddrAsciz` row preserves current behavior, and inferred array size plus the assertion catches a missing initializer. Count checking does not prove ordering. This is invariant hardening, not a demonstrated live miscompile repair. |
| 0047: decimal directive text output | Approve revised artifact, independently of 0039. Raw text retains the expression and character count; object output and the internal marker's contract remain unchanged. |
| 0050: floating-vector arithmetic | Approve the scalarization rule; prepare a 6502-only upstream test variant. Its original three-mode test passes on the integrated compiler. |
| 0051: zero-page byte index | Approve for local integration, not a separate upstream bug PR. See the source and executable comparison below. |

No new implementation blocker was established. Code and test comments in the
reviewed patches explain present contracts rather than narrating a fix history.

## Prior-work reconciliation

Read the [0039 validation](../2026-09-24/0039-validation.md), the
[September 25 independent revision review](../2026-09-25/claude-batch-review.md),
the initial [0043](../2026-09-25/0043-validation.md),
[0046](../2026-09-25/0046-validation.md), and
[0047](../2026-09-25/0047-validation.md) evidence and their supersession notices,
the corresponding current PR drafts, and the
[0044 plan and original verification](../../plans/2026-09-24-asmprinter-long-address.md).
The floating-vector and byte-index findings already have canonical records:
[floating vectors](../../defects/mos-float-vector-legalization.json) and
[byte index](../../defects/mos-zp-index-same-width-trunc.json).

Searched the investigation, preparation, TODO, upstream-summary, structured-record,
patch, and Git-history entries by patch number and responsible operation. Inspected
the actual parser, printer, fixup, inline-asm hook, and legalizer implementations.
The exact 0043/0046/0047 hashes still match the September 25 revised artifacts;
earlier isolated binaries must not be credited with those later revisions.

Current MOS main source was inspected read-only at
`7bd67c0ae4e8bb65a3f980912bf201df22131e34`. No source or build product in the
coordinator's isolated checkout was modified. Existing compiler executables were
used read-only; all execution output from this review is under
`build/post-ready-review-mos/`.

## Fresh test replays

The scratch extractor copied each new lit test directly from its patch and
asserted byte equality against the live test file. The modified existing
`addr-asciz.s` was copied from the live source. A separate lit execution directory
prevented test outputs from changing the source or existing build trees.

Command:

```sh
build/llvm-mos/bin/llvm-lit -v \
  -o build/post-ready-review-mos/candidate-lit.json \
  build/post-ready-review-mos/tests
```

Result: **10 tests passed, zero failed**. These comprise:

- Three constant-modifier MC tests, including the refusal path.
- The complete revised inline-asm-width test: twelve rejected cases and six
  valid functions, including explicit names and clobbers.
- The long-address disassembly and reassembly test.
- Three decimal-directive tests, including all eight character counts,
  byte-for-byte object comparison, forward constants, label differences, and
  rejection of `addrasciz()` as an instruction modifier.
- The floating-vector and byte-index tests, each with their three original
  CPU/feature RUN lines and machine verification enabled.

The initial lit attempt could not create its Python worker socket in the
sandbox; the approved rerun executed normally. That harness restriction was not
a compiler-test failure. The existing integrated build reports optimized mode
with assertions off. No assertions-on candidate claim is inferred from this run.

The additional replay driver retained exact commands, executable hashes,
return codes, and diagnostics in `build/post-ready-review-mos/runs.json` and
the adjoining logs. It confirmed:

| Same input / check | Preserved or upstream control | Current integrated compiler |
|---|---|---|
| Canonical `baseline/float-vector.ll` | Exit 1, `unable to legalize instruction` on the recorded failing binary | Exit 0 |
| Canonical full `baseline/legalizer.mir` | Exit 1, `G_TRUNC %1:_(s8)` in `load_zp_constant_ptradd_8` on the recorded failing binary | Exit 0 |
| Two positive modifier-width MC files | Assemble, but fail the encoding FileChecks on pristine pin | Both FileChecks pass |
| Symbolic `.mos_addr_asciz` text output | Signal abort, `Don't know how to emit this value` on pristine pin | Exit 0; full lit round trips also pass |
| Supplementary bare-symbol long-address MIR | Produces unmarked operands; fails the width-marker FileCheck on pristine pin | Produces all expected `mos24(...)` operands; FileCheck passes |

These replays corroborate the existing mechanism and retained evidence. They
are not new same-source A/B builds and do not replace the canonical records'
causal build evidence. No runtime/emulator run was performed in this initial
replay pass; earlier runtime claims remain attached to their dated evidence.
The subsequent standalone 0039 emulator run is recorded separately below.

## 0051 is downstream-scoped

At both pristine pin `8be0546128a55e78c63ca571d466aa72a782cd36` and current MOS
main, `tryAbsoluteIndexedAddressing` contains:

```cpp
Index = Builder.buildZExtOrTrunc(S8, NewOffset).getReg(0);
```

That operation accepts an already-byte-sized source. The downstream replacement
uses an explicit truncation plus wider reconstructed value to preserve its
register-allocation contract. 0051 ensures an s8 index does not enter that
wider-value path. Its source hunk consequently depends on downstream code absent
from upstream, not merely on an upstream line-number rebase.

The exact new `zp-byte-index.ll` passed `-verify-machineinstrs` and its assembly
FileChecks with both:

- The preserved **pristine-pin** `before-bin/llc` from 0043 validation.
- The existing assertions-on cross-target compiler based on
  `742d554bf08042b8df93d791c335260fadd16643`. Its source contains unrelated
  TwoAddressInstructionPass edits; it is not described as a pristine build.

Their assembly was byte-identical, SHA-256
`c5e8ee954a7bb59454fe22fe170260fa5aa67b8d885383aef81acb0235444d45`.
The recorded **fork** baseline still fails the preserved full legalizer input,
and the integrated candidate passes it. Thus the original local closure is
supported, while an independent upstream-bug submission would misstate scope.

## Supplementary 0044 symbolic coverage

The shipped 0044 lit regression exercises low numeric operands through the
disassembler. The bare-symbol path is separately important for assembly generated
by the compiler. The scratch probe `build/post-ready-review-mos/long-symbol.mir`
contains `LDA_AbsoluteLong`, `STA_AbsoluteLong`, `LDA_AbsoluteXLong`, and
`JSL_AbsoluteLong` with external symbol operands, followed by `RTS`.

```sh
build/llvm-mos/bin/llc -mtriple=mos -mcpu=mosw65816 \
  -start-after=machine-opt-remark-emitter -verify-machineinstrs \
  build/post-ready-review-mos/long-symbol.mir -o -
```

Pristine pin prints `lda long_data`, `sta long_data`, `lda long_data,x`, and
`jsl long_target`; the candidate prints `mos24(...)` around each symbol.
This is a stock-65816 printer regression and does not require downstream native
features. Include equivalent coverage in the prepared upstream artifact.

An initial scratch jump-only MIR was invalid because its external jump target
was not a CFG successor; the machine verifier rejected it. It was replaced with
the valid load/store/call fixture above. That input-construction error is not
reported as a compiler defect or included in successful regression counts.

## Reviewed identities

Exact patch SHA-256 values:

```text
36a5787a07b72287ebbb98a49d1f2358407805483151d57fc50b91f2c8c2d909  0039
8ffad5b5b6ac9d94dfcf2953d79327b88cba130150350419e30f6f6d9ac0aef6  0043
2afad4b164bb771db8166c93ffee43584c53f06b488b9329d8501cc1632219f0  0044
d42701fa045a3f4c4a3cf73807cfb50e0dc838e51b3bc1b06e95be61d935e442  0046
c6feb148fcc3430cb061ef57b48a2f1bf60fa5e08405157a31ec13d29f3831c4  0047
7a2fc01b9501617b8b6e054a1fd49c7551a7894886690876f8a0a788ab7f23fb  0050
a556854efd35934b4c9d4554ff85fc083ca5145426cd20f3a6bd237fb5ab2c6c  0051
```

Executable SHA-256 values:

```text
f965b29659e9fc708b595f705393b3bcabf3d414e1acac14217e97c22b57d445  build/llvm-mos/bin/llc
743ba7d42e3537b7557677c3b02a4528edb20810b89360fecd93480d0f6c80e5  build/llvm-mos/bin/llvm-mc
ccc7e32369eb2983d3f66a31e4749a24ef4e1cfb7a69d1563c0cfa13ef42a58c  preserved mos-correctness baseline llc
3d6b3f91996fc4a7f82807d355c69316ab9c5d9d2b773b3217540360c499c5c3  preserved pristine-pin llc
a54056ed33e22fc883173f8c4c57eda9325d7b3bdb93e0f0fc6706f377480499  preserved pristine-pin llvm-mc
149af7e3d2547e574ac72e8ed80d75572d87dfef7fe921bc982960fe5acd3e95  build/0029-cross-target-build/bin/llc
```

The local integrated binary is identified by its bytes and replayed behavior,
not assumed to contain exactly one patch or to equal the currently edited source.

## Attribution and integration

Independent review and the fresh replays above: **OpenAI Codex CLI 0.157.1
(`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort**, agent
`/root/review_mos`. Verified from this agent's session metadata and turn context:
`01a0db96-e0ef-75e2-89ad-2939c4954446`. This credit applies only to this review;
earlier implementation and evidence contributors retain their recorded credits
in the linked plans, reviews, and canonical defect records.

The coordinator owns final dependency registration, current-summary review,
submission variants, isolated compilation, and inventory refresh. This reviewer
changed no current summary, canonical defect record, patch, or inventory.

## Follow-up: standalone 0039 assembler runtime differential

After the coordinator's clean, assertions-on builds were available, this reviewer
independently executed a new deterministic stock-6502 check using the preserved
`build/post-ready-validation-mos/0039/{baseline,candidate}-bin/llvm-mc` snapshots.
Their build receipt identifies base
`7bd67c0ae4e8bb65a3f980912bf201df22131e34`, no prerequisite patches, and candidate
patch 0039 SHA-256
`36a5787a07b72287ebbb98a49d1f2358407805483151d57fc50b91f2c8c2d909`.
The saved CMake configuration records `Release` and `LLVM_ENABLE_ASSERTIONS=ON`.
This reviewer consumed those executables read-only, not their mutable build tree.

The exact assembly initializes different bytes at the two possible effective
addresses, executes the explicit-width indexed load, prints the observed byte
through mos-sim's `$FFF9` interface, and exits through `$FFF8` with the byte XOR
the expected value:

```asm
.text
.globl _start
_start:
    lda #87
    sta 0
    lda #80
    sta 256
    ldx #16
    lda mos16(240),x
    sta 65529
    eor #80
    sta 65528
```

With `X=$10`, the requested absolute address is `$00F0+$10=$0100`, containing
`P` (`$50`). Zero-page indexing instead wraps to `$0000`, containing `W` (`$57`).
Both binaries assemble the same source successfully; the differing runtime
value, not a compiler diagnostic, is the failing observation.

| Assembler | Encoding at `$020B` | Observed byte | Emulator exit |
|---|---|---|---:|
| Clean MOS main baseline | `B5 F0` — zero-page,X | `W`, `$57` | 7 |
| Same base plus 0039 only | `BD F0 00` — absolute,X | `P`, `$50` | 0 |

The output object has **no relocations**. `llvm-objcopy` extracts only `.text`;
the runner packages those unmodified bytes at `$0200` and a reset vector pointing
there into mos-sim's documented little-endian block-image format. No C frontend,
linker, SDK library, SNES platform, 65816 native-width feature, or unrelated
compiler patch participates. Each emulator process has a ten-second timeout;
the retained instruction trace confirms the load's opcode and accumulator value.

Exact invocation, from the repository root:

```sh
python3 build/post-ready-review-mos/runtime0039/run.py \
  --baseline build/post-ready-validation-mos/0039/baseline-bin/llvm-mc \
  --candidate build/post-ready-validation-mos/0039/candidate-bin/llvm-mc \
  --out build/post-ready-review-mos/runtime0039/standalone
```

The output directory is intentionally created only if absent; use a new directory
when replaying so this captured run remains intact. The runner checks the exact
index-load bytes, absence of relocations, expected output, and expected exit on
both sides. Its overall exit was zero. An earlier smoke run against different
historical/integrated tools remains separately under `runtime0039/smoke/` and is
not used to claim standalone validation.

Retained local artifacts: `runtime0039/modifier-width-runtime.s`, `run.py`, and
`runtime0039/standalone/` under `build/post-ready-review-mos/`. The latter contains
both objects, raw code, executable `.simg` memory images, complete command and
instruction-trace logs, tool versions, and a manifest hashing each artifact.

```text
868699f0bca17c9dd1af7a11ed2a61c8fd1cd79c481d5ec19a2a7793b4ab0ceb  modifier-width-runtime.s
cb137beb57a38d61d659b6750cf06716bbf0c6f47b0a5932fcbcd520760dad99  run.py
ce6392596b1f8c65827b37fd5ff8ddb2b151b6e25e8422427526f4e8911a31d3  baseline llvm-mc
dd80b4ba2fddb42884864c57b412c20606f7d6278fdf3bb4a8372591942a04e6  candidate llvm-mc
e7bf3477fc14e12603bed35963fbcd38cfba8a50b8901529429f3f6eee441593  build/utils/sim/mos-sim
d03714a2fbbebeca260b096f3fb5c57c464906338fd2287f7ba9886062c2181e  baseline.simg
a30cc5ba0a11a1fe629ab2046a2f789ed4812be0c5e3a5e83c2568bc40b19b50  candidate.simg
777f3f3962c9d830ab5e4c2aab7891f4545e66c88a311f25d8c9d00059d6b7fd  standalone/manifest.json
```

**Conclusion:** the standalone 0039 runtime gate passes, with matching-source
wrong-addressing evidence before the patch and correct addressing afterward.
This supplements the earlier integrated corpus runs without relabeling them as
0039-only validation. It says nothing about closure of the separate historical
#320/0023 failure or native-series extraction.

Follow-up harness, execution, and this appended evidence: OpenAI Codex CLI
0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort,
agent/session `/root/review_mos` / `01a0db96-e0ef-75e2-89ad-2939c4954446`, as
verified above. The coordinator's build authorship remains in its own receipt.

## Final-package follow-up: 0044, 0045, and current-main 0047

Independently reviewed the final posting variants against their carried patches,
the stock MOS definitions at `7bd67c0ae4e8bb65a3f980912bf201df22131e34`, and
the coordinator's completed isolated-build receipts. **All three final variants
are approved.** This follow-up is source and retained-evidence review; the
coordinator, not this reviewer, built these compilers and ran these suites.
No posting, shared-source edit, or additional compiler build was performed.

### Exact extraction and adaptation

- [0044](0044-llvm-mos.patch) retains the reviewed implementation and MC test
  byte-for-byte, adding only `long-address-symbol-printer.mir`. That valid
  late-pipeline MIR exercises bare symbolic long load, store, indexed load, and
  call operands without far-pointer IR lowering. It fulfills the supplementary
  coverage recommendation above. The numeric round-trip test still needs 0039;
  the isolated receipt explicitly applies that prerequisite to both sides.
- [0045](0045-llvm-mos.patch) keeps the carried `printImm16Operand` implementation,
  declaration, and operand `PrintMethod` unchanged. The source-hunk context is
  rebased away from 0044, and the downstream `+mos-a16` IR regression is replaced
  by `immediate-width-printer.mir`. This starts with existing stock
  `Immediate16` opcodes, checks small constants including zero and 255, preserves
  bare 256 and 65535, and includes a genuine 8-bit ADC control. It also compares
  direct object `.text` with reassembled printed `.text`, covering encoding as
  well as spelling. The test is a printer fixture, not an executable M/X-state
  program; it makes no claim to validate native IR lowering or runtime mode
  transitions. Stock `isImmInRange` already rejects `MOS::Imm16` for an 8-bit
  candidate before constant evaluation, so this extraction has **no semantic
  dependency on 0039, 0044, or #321**. `imm16at5` remains unchanged, preserving
  HuC6280 block-length printing. Existing explicit modifiers retain their
  contract; a mismatched narrower modifier on a 16-bit opcode remains outside
  this repair, as the original plan already records.
- [0047](0047-llvm-mos.patch) differs from the previously approved carried patch
  in exactly one member-access token: `getContext().getAsmInfo()->printExpr`
  becomes `getContext().getAsmInfo().printExpr`. Current `MCContext.h` returns
  `const MCAsmInfo &`, and `MCAsmInfo::printExpr` is a const member. This is the
  appropriate current-main API adaptation, with no change to directive
  semantics, object fixups, or the three reviewed tests. The carried fork patch
  was not changed. The first failed current-main build remains dated evidence;
  the final approval uses the separate `post-ready-validation-mos-r2` receipt.

The source and test comments describe present contracts, not repair history.
The [original 0045 plan](../../plans/2026-09-24-asmprinter-a16-immediate.md) was
reconciled, not treated as a new discovery. Its former fork-only assessment and
0039-dependency prose need a visible dated qualification when the coordinator
integrates the new stock-MIR evidence; its original measurements must remain.

### Audited isolated results

Each receipt identifies current MOS main, exact patch hashes, matching baseline
and candidate input hashes, tool identities, commands, and retained logs. Saved
CMake configurations specify `Release` and `LLVM_ENABLE_ASSERTIONS=ON`. The
durable receipt copies compared byte-for-byte equal to the build-local copies.

| Packet / retained receipt | Baseline observation | Candidate evidence | MOS MC + CodeGen suites |
|---|---|---|---|
| [0044](validation/runs/post-ready-validation-mos/0044/receipt.json) | Numeric and bare-symbol width-marker FileChecks fail | All three regression RUNs pass | 136 passed, 1 unsupported, 0 failed |
| [0045](validation/runs/post-ready-validation-mos/0045/receipt.json) | Emits unmarked small 16-bit immediates; FileCheck fails | All seven regression RUNs pass, including `.text` comparison | 132 passed, 1 unsupported, 0 failed |
| [0047 r2](validation/runs/post-ready-validation-mos-r2/0047/receipt.json) | Symbolic text output aborts; object and invalid-modifier controls pass | All nine regression RUNs pass, including whole-object comparison | 133 passed, 1 unsupported, 0 failed |

The unchanged unsupported test is `CodeGen/MOS/getchar-regression.ll`. This
review checked the retained assembly, comparison artifacts, suite summaries,
and receipt contents; it does not relabel those coordinator-run commands as
independent reruns. The direct and reassembled 0045 `.text` files have matching
SHA-256 `3278ab46b10d4db3156dbee11f3ab43d3de76b0a49941b7523155eac73222b5e`.
The corresponding 0047 whole objects both hash to
`b146310b736535221ca87e66678a665604b6225496543a89fdfcaa9fa18e1a0d`.

Final posting-packet identities, distinct from the earlier carried-patch hashes:

```text
6b48a04ae47c924af4cc777454985a6e2489596047edc2e6253fd188a36f4de1  0044-llvm-mos.patch
ce595a69e81c2ec6732bd4d9cf8a5bf01aaa3c7ff4d254228188a678a9f9559c  0045-llvm-mos.patch
b641d19787bcf09329b8535190f09c0d924d51177a4273cb258bacd211dd9d61  0047-llvm-mos.patch
a8ce6f7dd07f5b109b11ffc4667e8a0ec8acae9d23377ec572a275539d67e17c  post-ready-validation-mos/0044/receipt.json
53c72e3cedae2ee6a573ecf6f11f6202c1d1f7d77c9c85be663adc6d0bde60f0  post-ready-validation-mos/0045/receipt.json
68e768f8366c6151dbf97f3c67df55bbffb920e77cab0a346888376651fd12de  post-ready-validation-mos-r2/0047/receipt.json
```

This final-package source and evidence review: OpenAI Codex CLI 0.157.1
(`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; agent/session
`/root/review_mos` / `01a0db96-e0ef-75e2-89ad-2939c4954446`, verified above.
Earlier implementation, extraction, and isolated-test credits are preserved in
their original records. This section does not review any subsequently revised
0043 packet or change the native-series extraction and historical #320 status.
