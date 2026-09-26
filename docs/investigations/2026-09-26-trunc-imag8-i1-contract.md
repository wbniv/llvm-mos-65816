# Imag8 → i1: disposition of the independent rejection claim

The independent claim that an `Imag8` source makes the `s8 → s1` matcher
decline is **invalid** at both inspected upstream revisions. The reporting
error is a register-class constraint being mistaken for a register-bank
predicate. This conclusion follows from the matcher contract, with compiler
runs as corroboration. No failing baseline or compiler fix is claimed.

The [structured record](../defects/mos-trunc-imag8-i1.json) covers that
independent claim. The original #320 far-pointer failure still lacks its exact
input and failing compiler, so its validity and root cause remain unknown.
Patch 0023, its tests, and all
[September 25 evidence](2026-09-25-trunc-0023-upstream-trigger.md) are retained.
The [prior record](../defects/evidence/2026-09-26-trunc-imag8-i1-contract/prior-record.json)
preserves the preceding status and attribution.

## Why Imag8 cannot cause this rejection

The [source excerpts](../defects/evidence/2026-09-26-trunc-imag8-i1-contract/source-contract.txt)
retain exact line numbers and file hashes for vendor pin
`8be0546128a55e78c63ca571d466aa72a782cd36` and saved unpatched upstream
`742d554bf08042b8df93d791c335260fadd16643`.

1. `MOSRegisterBankInfo::getRegBankFromRegClass` returns `Any` for every
   register class. `RegisterBankInfo::getRegBank` uses that mapping for a
   register that already has a class. `Imag8`, `Ac`, and the one-bit result
   classes therefore satisfy the same bank predicate.
2. The generated `G_TRUNC` rule checks result type `s1`, source type `s8`,
   result bank for `GPR_LSB`, and source bank for `Ac`. It has no CPU feature,
   constant-value, producer, use-count, or register-class intersection
   predicate. An `Imag8(s8)` source with a properly banked `s1` result
   satisfies every check.
3. After those checks, `GIR_ConstrainSelectedInstOperands` constrains the
   `ANDImm` source to `Ac`. `constrainRegToClass` allocates a new register if
   the existing class is incompatible, and `constrainOperandRegClass` inserts
   the copy. An incompatible class does not reject the matcher.
4. `GIR_EraseRootFromParent_Done` completes selection. The custom
   `selectTrunc` fallback is reached only after `selectImpl` declines. The
   `Imag8` class by itself cannot make this valid byte-to-bit rule decline.

The [regenerated upstream matcher](../defects/evidence/2026-09-26-trunc-imag8-i1-contract/upstream-MOSGenGlobalISel.inc)
is byte-identical to the saved upstream build's generated matcher. Its exact
TableGen command, binary hash, source identities, and attribution are in
[provenance.json](../defects/evidence/2026-09-26-trunc-imag8-i1-contract/provenance.json).
This proves the disposition for the specified valid MIR contract; it does
not establish what malformed or differently constructed MIR an unrecovered
historical far-pointer combiner might have supplied.

## Replayed compiler checks

All **72 compiler runs and 48 FileCheck selections pass**:

| Dimension | Coverage |
|---|---|
| Compilers | Saved unpatched upstream `742d554`; preserved September 25 comparison with the s8 fallback removed; current patched compiler |
| CPUs | `mos6502`, `mos65c02`, `mos65ce02`, `mosw65816` |
| Retained inputs | September 25 reconstructed direct MIR, reduced IR, and Clang-generated IR, unchanged |
| Additional MIR | `Imag8(s8)` input with result bank/class `Any`, `GPR_LSB`, `Cc`, `Vc`, or `Anyi1` |
| Selection | Explicit `Imag8 → Ac` copy, `ANDImm 1`, low-bit extraction, and machine verification |
| Complete code generation | Both retained IR files through assembly emission at `-O1`, with machine verification |

The [run manifest](../defects/evidence/2026-09-26-trunc-imag8-i1-contract/runs/runs.json)
records exact commands, input hashes, binary hashes, exits, and output hashes.
Its directory retains stdout and stderr for every command. The preserved
comparison binary still has its September 25 hash
`939ab87bd091133be116f3cecb615bd6f8cd16e75a8f91620cbc37e5becbc3f2`.
The upstream binary matches its
[archived checksum](../defects/evidence/2026-09-26-trunc-imag8-i1-contract/upstream-build-SHA256SUMS.txt).
It was run directly on the host: the container image named in the
[original build manifest](../defects/evidence/2026-09-26-trunc-imag8-i1-contract/upstream-build-manifest.json)
is no longer installed. That environment limitation is recorded explicitly.

Replay with a new output directory:

```sh
python3 dev/check-trunc-imag8-i1.py \
  --llc upstream=build/upstream-reference/742d554bf08042b8df93d791c335260fadd16643/bin/llc \
  --llc comparison=build/defect-baselines/2026-09-25-trunc-imag8-i1/bin/llc \
  --llc patched=build/llvm-mos/bin/llc \
  --filecheck build/llvm-mos/bin/FileCheck \
  --output /tmp/trunc-imag8-i1-replay
```

These are positive selector-contract checks. They are not red/green evidence,
and they make no new runtime-correctness claim.

## Patch and submission disposition

The [original comment](../defects/evidence/2026-09-26-trunc-imag8-i1-contract/original-0023.patch.txt)
asserted that the `Imag8` class makes `selectImpl` decline. The patch and vendor
source now describe the fallback's actual behavior without that assertion.
The build-script comment also describes register classes accurately. There
is no executable compiler change and no test or fallback removal.

Patch 0023 reverses and reapplies byte-for-byte across all four affected files.
The defect-evidence check passes for all 14 worktree records. The comment
checker passes the new runner, MIR checks, and updated patch. A full isolated
index check also includes the pre-existing, untracked September 25 frozen
selector source: it flags `Used to ensure` and `Used to fold` there as historical
narration. Those phrases describe current uses, but the frozen snapshot is
preserved unchanged; no comment-hook bypass or commit was performed.

The independent extraction is retired as an unsupported diagnosis. Keep 0023
with the feature series, including its separate native `s32 → s16` pattern.
Revisiting the historical #320 observation requires its original failure or a
new valid reproducer and identified failing compiler. An unrelated crash or
MIR with missing bank assignments would not establish the rejected claim.

## Evidence packaging

The September 25 frozen `unpatched-selector.cpp` is published as
[`unpatched-selector.cpp.txt`](../defects/evidence/2026-09-25-trunc-imag8-i1/unpatched-selector.cpp.txt),
a byte-identical documentary snapshot with SHA-256
`5acb907b79ab94de4d6580b4c246e437f3d6d2797d14da59ce103a790c676b95`.
The local original remains intact. Its inherited comments are not new source
changes; no captured bytes or baseline were rewritten to pass a comment check.
The retained prior record keeps the historical filename; the current record
uses the published text-artifact path. Packaging and publication checks:
OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning
effort, verified session `01a0db16-f6a0-7e32-ada6-0c8098813933`.

Investigation, contract checks, and disposition: OpenAI Codex CLI 0.157.0
(`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort, verified from
session `01a0dafb-5a4b-7562-bec3-0488c07748a1`. Earlier attribution is preserved
in the linked dated investigation and prior structured record.
The [previous summary review receipts](../defects/evidence/2026-09-26-trunc-imag8-i1-contract/prior-summary-receipts.json)
also retain their earlier review attribution.
