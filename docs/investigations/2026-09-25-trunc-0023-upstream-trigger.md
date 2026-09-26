# Patch 0023: independent `Imag8 → i1` reachability

**2026-09-26 follow-up:** the [matcher-contract audit](2026-09-26-trunc-imag8-i1-contract.md)
disproves the independent claim that the `Imag8` source class rejects the
pattern. It preserves the historical far-pointer uncertainty. The September 25
observations and attribution below remain as recorded.

The independent plain-MOS failure is **not reproduced on the comparison
build**. The downstream patch contains an `s8 → s1` selector fallback as well
as an a16-only `Imag32 → i16` pattern. This investigation assesses whether the
first part has a standalone upstream trigger. It does not reclassify the
earlier far-pointer observation from the #320 fork. Its structured status
record is [mos-trunc-imag8-i1](../defects/mos-trunc-imag8-i1.json).

## Producer and observed result

[The C input](../defects/evidence/2026-09-25-trunc-imag8-i1/source.c)
converts an `unsigned char` to `unsigned _BitInt(1)` and uses that byte as the
right operand of a subtraction. Clang `-target mos -O1` emits
[`trunc i8 to i1`](../defects/evidence/2026-09-25-trunc-imag8-i1/clang-o1.ll)
and `sub i8` from the same byte. The independent, reduced
[IR input](../defects/evidence/2026-09-25-trunc-imag8-i1/input.ll) retains
those operations. Before selection, its [MIR](../defects/evidence/2026-09-25-trunc-imag8-i1/pre-select.mir)
contains `G_TRUNC` and `G_SUB` on the same `s8` value. After selection, the
subtraction uses `Imag8`, and truncation uses an `Imag8 → Ac` copy followed by
`ANDImm 1`.

The same input passes with a locally reconstructed selector **with 0023's
fallback removed** and with the patched compiler. Their selected instruction
bodies agree. The direct `Imag8` MIR case carried by 0023 also passes on the
unpatched selector. All six commands and tool/input hashes are retained in
[runs.json](../defects/evidence/2026-09-25-trunc-imag8-i1/runs.json); the
[unpatched](../defects/evidence/2026-09-25-trunc-imag8-i1/unpatched-selected.mir)
and [patched](../defects/evidence/2026-09-25-trunc-imag8-i1/candidate-selected.mir)
outputs are retained separately. They differ in module data layout from the
two compiler versions, not in the selected body.

## Why the fallback is not reached here

The MOS register-bank selector maps these registers to the `Any` bank. The
generated GlobalISel matcher for `(i1 (trunc Ac:$s))` checks that bank, then
constrains the `ANDImm` input to `Ac`. When the value is already `Imag8`, that
constraint creates the copy. The matcher succeeds before
`MOSInstructionSelector::selectTrunc` can run. Removing 0023's fallback
therefore leaves the conversion working on both the C-derived and direct MIR
inputs.

The relevant pattern, subtraction constraint, `Any` bank mapping, and
`selectTrunc` fallback shape are also present in the clean vendor HEAD
`8be0546128a55e78c63ca571d466aa72a782cd36`. This source comparison
supports the plain-MOS applicability of the probe; it does not substitute for
a failing upstream build.

The comparison compiler was reconstructed from the current vendor selector by
removing only the fallback block, compiling that file, and relinking against
the same vendor build. Its source is
[retained](../defects/evidence/2026-09-25-trunc-imag8-i1/unpatched-selector.cpp),
and its binary is preserved under
`build/defect-baselines/2026-09-25-trunc-imag8-i1/bin/llc` with the hash in
`runs.json`. It is a comparison build, not a captured historical upstream
failure. The original far-pointer path mentioned in 0023's comment depends
on the separate #320 feature series and has not been used as independent
upstream evidence.

No red baseline has been established for the independent half of 0023. Keep
the downstream patch with its feature series. A standalone submission needs a
valid stock-upstream input that fails for this selector contract; a passing
comparison must not be presented as the fix's regression test.

Investigation: OpenAI Codex API (version unknown), GPT-6 (exact model ID and
version unknown), reasoning effort unknown. Earlier patch authorship is
unchanged.
