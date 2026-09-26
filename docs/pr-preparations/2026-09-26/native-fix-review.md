# Far-memory, immediate-printing, and native-extension review — September 26, 2026

Independent reviewer: OpenAI Codex CLI **0.157.1**, subagent
`/root/review_reducer_features`, exact model **`gpt-6-astra`**, **`xhigh`**
reasoning effort. Verified from this subagent's session metadata and turn
context, session `01a0db97-39fe-7452-bbab-73d26f1d19a9`.

This is a follow-up to the [dependency/ownership review](reducer-feature-review.md).
It reviews existing repairs, not newly discovered defects. Tests read retained
tools and inputs and write only to `build/post-ready-review-reducer/`. No vendor
source, preserved baseline, shared compiler build, canonical defect record, or
external service was modified. Nothing was posted.

## Decisions

| Patch | Review conclusion | Actual prerequisite |
|---|---|---|
| `0013` far memory libcalls | Approve the existing, qualified 4096-byte wrong-bank repair; fresh causal and routing checks agree with the canonical record. Not unrestricted far-memory intrinsic approval. | Extracted far-pointer compiler/ABI and documented far runtime entry points; preserve the length-domain limitation below. This is not a prerequisite to merge SNES platform implementation. |
| `0045` 16-bit immediate printing | Approve the printer change and the native-feature-free regression below, subject to the parent's isolated exact-current package build. | No semantic dependency on `0039`, `0044`, or `#321`. Reanchor stale `0044` hunk context and substitute raw existing opcodes for the downstream native-IR test. |
| `0055` native wide `G_ANYEXT` | Approve the existing native-width rule and discriminating regression; fresh checks reproduce the retained distinction. | Native-width legalization/ABI feature extraction (`#321`). Do not label the complete patch standalone-ready against current upstream without that feature base. |

These are preparation/review decisions, not permission to submit. The historical
`#320` failure behind `0023` is a separate record and is not closed by any result
here.

## Prior-work reconciliation

For `0013`, read the [canonical record](../../defects/mos-far-memset-wrong-bank.json),
[revalidation](../../investigations/2026-09-26-far-memset-revalidation.md), original
entry point and June implementation plan, standalone patch, live legalizer, and
`platforms/snes/mem-far.c`. The repair dates to
`a81874d89ffaac1c34b06cbb8539db9e4785c41b`; its implementation is also folded
into `0002`. This review does not rediscover it or replace the qualified
reconstructed baseline with a claim to possess the June compiler.

For `0045`, searched structured defects, current queue/TODO, historical audit,
patch history and live printer/parser/TableGen definitions. Its original entry
point is [the September 24 audit, section 6.3](../../investigations/2026-09-24-mos24-far-addressing-completeness-audit.md#63-the-second-instance--16-bit-immediates-under-mos-a16),
and the repair is commit `77524e40`. The audit already states that both tested
assemblers understood `#mos16`; the defect is the omission by the printer.
The 15 existing top-level structured records reviewed here contain no separate
immediate-printer record. Any canonical migration should preserve that entry
point and repair credit, not represent this new stock-MIR witness as a new
discovery.

For `0055`, read the [canonical shift record](../../defects/shift64-narrow-count.json),
[fix investigation](../../investigations/2026-09-25-shift-inlineasm-fixes.md),
historical recovery qualifications, patch and current legality/custom-lowering
code. The earlier exact compiler remains unavailable; retained September
red/green evidence establishes the recovered input's backend mechanism, not an
unqualified reconstruction of every historical build.

## 0045: standalone stock-opcode regression

Proposed package test:
`build/post-ready-review-reducer/native-immediates.mir`, SHA-256
`75d60dd4aceca2d33ee8602813fa4f500eeb6b7608671a78f6d05dbfba710f3c`.
It is complete with current-pass RUN lines, assembly FileCheck, direct object
emission, assembly reassembly, `.text` extraction with `llvm-objcopy`, and binary
comparison. Use this test instead of the carried `+mos-a16` IR regression for
the independent package; retain the native IR test in the feature series.

The MIR explicitly contains these already-existing instructions:

```text
ADC_Immediate16 66
EOR_Immediate16 255
CMP_Immediate16 5
LDA_Immediate16 256
LDX_Immediate16 0
LDY_Immediate16 65535
ADC_Immediate 66
RTS_Implied
```

Run with `-mtriple=mos -mcpu=mosw65816 -verify-machineinstrs`, **without native
feature flags**, starting after `prolog-epilog` on the stock LLVM 24 toolchain.
The older fork spells that pass `prologepilog`. This tests printer/MC transport
of valid explicit opcodes, not their natural reachability from stock C, and
does not claim execution of this instruction stream or validate M/X setup.

| Observation | Stock MOS `742d554b` | Existing repaired fork |
|---|---|---|
| MIR accepted; direct object produced | Yes | Yes |
| Small wide immediates carry `mos16` | No; FileCheck exits 1 | Yes; FileCheck exits 0 |
| Direct `.text` size | 21 bytes | 21 bytes |
| Printed/reassembled `.text` size | 17 bytes | 21 bytes |
| Direct/reassembled bytes identical | No | Yes |
| Values 256/65535 stay bare, 8-bit ADC stays narrow | Yes | Yes |

Direct bytes on both builds are
`69420049ff00c90500a90001a20000a0ffff694260`; unpatched reassembly yields
`694249ffc905a90001a200a0ffff694260`.

The parser dependency was checked separately: the **unpatched stock**
`llvm-mc` reassembled `native-checks/fixed-fork.s`, producing
`native-checks/fixed-text-stock-parser.o`; extracting `.text` and comparing it
against stock direct output succeeds. Both binary sections have SHA-256
`3278ab46b10d4db3156dbee11f3ab43d3de76b0a49941b7523155eac73222b5e`.
Current MOS main `7bd67c0ae4e8bb65a3f980912bf201df22131e34` retains
the explicit `FixupKind == MOS::Imm16 && High < 0xFFFF` parser rejection.
Consequently the immediate wrapper does not need `0039`'s broader address-width
guard, even though `0044`'s long-address roundtrip does.

`0044` appears only in the carried printer/header hunk context. The new function
can be anchored before `printBranchOperand`, with its declaration next to
`printOperand`; `MOSMCExpr`, the operand methods, and `imm16` already exist
upstream. Apply the print method only to `imm16`; leave `imm16at5` (HuC6280
block-transfer length, which has no narrow immediate sibling) unchanged.

The existing-modifier early return avoids double wrapping. Bare small constants,
symbolic expressions and out-of-range constants get explicit width; representable
constants above 255 need none. The fresh fixture covers constant boundaries and
the narrow control, not every symbolic expression/modifier combination. The
parent's exact-current isolated build and MC suite remain required; the green
binary tested here contains the full fork, not only isolated `0045`.

## 0013: scoped repair and runtime ABI

`anyFarPointerOperand` selects a far libcall only after the inline memory-family
lowering declines. `createFarMemLibcall` passes AS2 32-bit pointers to the named
far routines, widening near/zero-page pointers under the documented DBR=0
model. Fill-byte and 16-bit length placement agree with the existing runtime's
void-returning ABI. Near operations retain generic lowering.

Fresh replay uses the immutable `june-c-entry/input.ll`, not another reconstructed
source. The archived baseline and candidate share the archived SDK, linker and
emulator. `dev/check-far-memset.py` records the exact archived options under
`native-checks/0013-{pre0013,with0013}-runtime/`:

- Baseline without `0013`: near relocation, target checksum `0x0000`, all 4096
  physical target bytes wrong, runner exit 1.
- Candidate with `0013`: far relocation, checksum `0x2000`, all 4096 bytes at
  `$7E2000..$7E2FFF` equal `0x42`, runner exit 0 after 300 bsnes-jg frames.
- The retained focused `far-memset.ll` compiles with both backends in a16 and
  xy16. Its far-routing FileCheck fails on the baseline and passes on the
  candidate in both modes; the near control is retained.

Do not enlarge this evidence's scope. The helper truncates lengths wider than
16 bits; the source comment's `size_t` argument is not itself a proof that an
arbitrary i32 memory intrinsic is bounded. The canonical record already
excludes lengths above 65535 and does not certify every memcpy/memmove
combination. This is an existing qualified limitation, not a new defect report.
Before approving an unrestricted intrinsic contract in an extracted feature
package, establish the length-domain guarantee or a guarded wider-length
lowering. The qualified 4096-byte closure remains valid.

## 0055: discriminating evidence, not control-only approval

The added custom rules apply only under `hasAccum16()` to s8/s16/s32-to-s64
extensions. `legalizeAnyExt` changes `G_ANYEXT` to `G_ZEXT` with observer
notifications; choosing zero for unspecified upper bits preserves the required
source bits and reuses existing byte extension lowering. Default-mode rules
remain unchanged.

Fresh `extend-masked.ll` checks, all with MachineVerifier:

- Retained pre-0055 backend: default O0/O2 pass; a16 and xy16 O0 pass, but both
  optimized O2 cases exit 1 at the recorded unsupported `G_ANYEXT`.
- Current fork: all six default/a16/xy16 × O0/O2 compilations pass.
- `anyext-wide.mir`: both backends pass all three modes and FileCheck with
  `--implicit-check-not=G_ANYEXT`. As the canonical investigation explains,
  these controls are not discriminating: the artifact combiner can remove
  their extension before the omitted rule is needed.

Keep `anyext-masked-byte.ll` as the failure-sensitive regression. The canonical
record also retains recovered-source, runtime and LTO coverage; this reviewer
read that evidence but did not rerun its nine runtime checks. No frontend
workaround is used to claim a backend repair.

## Exact fresh provenance

All fresh arguments, exit codes, input/tool hashes and log hashes are in
`build/post-ready-review-reducer/native-checks/results.json`, SHA-256
`77e261a6fa800780d3144f2381eb18cf19b0e7f73f45c6c804e200225476fc72`.
The runner is `native-review.py`, SHA-256
`ed3043aed3b62360878bb956c4c46799c07bb82beb5e55c58a8f9f83922da9ab`.
The subsequent cross-parser comparison is separately described above and is
not represented as part of that unchanged results manifest.

| Tool/input | SHA-256 |
|---|---|
| Stock `build/upstream-reference/742d554bf08042b8df93d791c335260fadd16643/bin/llc` | `d7ecc0c644292f0ac657f1868a0b1756e44c715fbbe4a6761821bd94aab25915` |
| Stock reference `llvm-mc` | `16dfaa40cd2c6b8b7824fd8507aee2b2eaddb8bd399d617bd5769ee7cded7683` |
| Current `build/llvm-mos/bin/llc`; archived far-memset candidate | `f965b29659e9fc708b595f705393b3bcabf3d414e1acac14217e97c22b57d445` |
| `build/defect-baselines/2026-09-25-historical-recovery/bin/llc` | `758f71c2eb2dd33052a641dac6a0d673e323a7645ebb2b3b202572f321293421` |
| `build/defect-baselines/2026-09-26-far-memset/bin/llc-without-0013` | `e39ec79bfa3c0fd76a6f99d65b8a1b7b79ba2ed3da7767220fdf7b695614aed8` |
| Far-memset `june-c-entry/input.ll` | `e7e885ad88c0494e042953196ccbe9b9f1197aed8e9028d4e9b0682b2056321e` |
| `extend-masked.ll` | `1b324275286694768015be6809a8d50e00d180299d1d497812ca061bdc7d58e1` |

The baseline/candidate far-runtime logs respectively have SHA-256
`323b0a817a2e8be8965e60ee94c9b2e1cd6ab613315dd18694a13b9d77cadf4c`
and `290b940dd85a7f9ec58f5cedaf9cd5e2e35fe53705b31ac319c7154f6c50231a`.
Earlier contributors' attribution and immutable evidence remain in the linked
canonical investigations; this review does not replace them.
