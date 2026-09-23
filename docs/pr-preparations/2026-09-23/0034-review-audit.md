# Patch 0034: audit of Claude's analysis, patch, and PR draft

September 23, 2026. Reviewed the existing [analysis/validation](0034-0035-validation.md),
[patch](../../../patches/llvm-mos/0034-mos-legalize-prefetch.patch), and
[PR draft](../../upstream-prefetch-legalize-pr.md). No implementation defect
found. The patch is suitable for submission after normal branch preparation.

The [LLVM intrinsic contract](https://llvm.org/docs/LangRef.html#llvm-prefetch-intrinsic)
allows unsupported prefetch hints to have no effect. The custom legalization
erases only `G_PREFETCH`, leaving instructions that compute its address or
perform other observable work intact. Its use of `eraseFromParent` matches
other custom MOS legalizations and the legalizer's change-observation setup.

## Corrections to the draft

- The original cross-target analogy was misleading: AMDGPU/SPIR-V marking
  prefetch legal does not mean they erase it. The PR now states MOS's own
  lowering and the intrinsic contract directly.
- The bundled test checks one read locality (3) and all four write localities,
  not every read/write combination. The draft describes that scope accurately;
  the independent matrix below supplies broader coverage.
- The original 137-pass suite count belongs to the stacked integration build.
  The new 0034-only suite has 130 passes and one unsupported test.
- The frontend signature defect is independent. Backend rejection and Clang's
  ill-typed intrinsic must not be described as one universal failure mechanism.

## Independent checks

Base: `742d554bf08042b8df93d791c335260fadd16643`, assertions enabled. Candidate
is the isolated `build/asm-symbol-work` / `build/asm-symbol-build` tree with
0034 alone. Patch SHA-256:
`3547c979ca3f46a9016ffacc0af1e4a3650a0416c94821c4797fec30b3d0f155`.
Saved `llc-0034-only` SHA-256:
`c57ad6acfe30def2c45a95f22e42589329edf45e60a34c94eb94fd5ed554b0b8`.

| Check | Result |
|---|---|
| Apply patch to pristine source | Clean |
| Full standalone MOS CodeGen / MC suites | 84 + 46 pass, one unsupported, zero failures |
| Expanded input on all 14 stock MOS CPUs, `-O0` and `-O2` | All 28 pristine runs fail to legalize `G_PREFETCH`; all 28 patched runs pass MachineVerifier through legalization |
| Hints in expanded input | Every `G_PREFETCH` removed |
| Observable work beside the hints | Volatile store and address-producing call retained in all 28 runs |

The expanded IR contains 24 hint forms: address spaces 0 and 1, all four
localities, read/data-cache, read/instruction-cache, and write/data-cache.
It is verified before compilation. These runs stop after legalization to
exercise the affected pass uniformly across CPUs; they are not a claim of
full code-generation coverage on every CPU. The committed regression and MOS
suite exercise the full pipeline on 6502.

Artifacts: `build/0034-review-audit/`, including `lit.json`, `probe.py`,
`matrix.json`, the expanded IR, before/after logs and MIR, and the saved
standalone compiler. The original combined 0034/0035 C-torture evidence remains
in the shared validation record.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`, `xhigh`
reasoning effort) for independent review, validation, and evidence corrections.
