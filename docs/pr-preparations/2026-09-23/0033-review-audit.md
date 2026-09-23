# Patch 0033: audit of Claude's analysis, patch, and PR draft

September 23, 2026. Reviewed the Claude-authored
[validation record](0033-validation.md),
[patch](../../../patches/llvm-mos/0033-llvm-spill-hoist-no-new-vregs.patch),
[PR draft](../../upstream-spill-hoist-scratch-vregs-pr.md), source, saved binaries,
and test artifacts. No separate 0033 review document was present.

The underlying late-allocation defect is confirmed, and the guard repairs its
reduced test on pristine upstream. The review found a small rollback-accounting
defect and material errors in the validation and scope claims. The patch needs
the accounting correction before submission; the audit does not change its
implementation.

## Findings

1. **The claimed cross-target run used an unpatched compiler.**
   `xtarget-hoist.sh` runs `build/0029-cross-target-build/bin/llc` through lit.
   That binary predates the guard, lacks its diagnostic string, and its source
   tree has no `HookMadeVRegs` implementation. The actual guarded binary is
   `build/0030-claude-review/llc-hoist-fix`. Therefore the saved X86/ARM/AArch64
   results do not establish 0033 coverage. The historical results also total
   11,436 passes and 23 expected failures after the 75 helper-tool failures
   were rerun, rather than 11,361 passes. Fresh validation uses a separate
   build containing 0033 alone; its result is recorded below.
2. **Rollback decrements `NumSpills` per instruction, but insertion increments
   it per spill-hook call.** The added `--NumSpills` sits inside the loop over
   mapped instructions. If an accepted hook emits two instructions and a later
   hook in the same group requires scratch registers, rollback subtracts two
   for the one accepted insertion. This can corrupt or underflow the statistic.
   Count completed hook calls, or defer committing the group's maps/statistics
   until all candidate hooks pass. This is a source-level accounting defect;
   the audit does not claim a demonstrated machine-code miscompile or a MOS
   input reaching that mixed multi-instruction rollback path.
3. **The claimed all-soft-stack corpus is not established and the stated
   reason is false.** `MOSPassConfig::addIRPasses` runs `MOSNonReentrant` at
   optimized levels, including under `llc`. A leaf function with no input
   attributes gains `"nonreentrant"` before instruction selection. Furthermore,
   the static-stack hook can create GPR scratch registers and Imag16 temporaries.
   The defect is about late scratch registers, not exclusively soft-stack spills.
4. **Standalone and stacked results were conflated.** The saved 18 repaired
   compilations use a build carrying 0011/0030/0031/0032. With 0033 alone,
   all 18 clear the `Remaining virtual register` failure, but `ashrdi-1` at
   `-O2` and `-Os` then reaches the independent scavenger assertion
   `expected N to be free when saving scavenger register`. Sixteen finish
   successfully. These results must be stated separately.
5. **The PR exposed downstream platform and feature details.** Those details
   belong in the internal validation record. The reviewer-facing draft is
   corrected to use upstream evidence. Broad claims that passing three target
   suites proves every other target unchanged are also removed.

The regression preamble's reduction history should also move out of the patch's
test comments into the PR/validation record, as required by this repository's
comment contract. Its explanation of the current soft-stack test input can stay.

## Independent checks

Base: `742d554bf08042b8df93d791c335260fadd16643`. Candidate source/build:
`build/asm-symbol-work` / `build/asm-symbol-build`, with assertions enabled and
0033 alone. Patch SHA-256:
`7b6794225bf1b4a7f906d503a5100b01ef2192e59556e540b115e2e73b9e3a5f`.
Candidate `llc` SHA-256:
`02d08726ff03a742e09f1c093bc2195cb77c0e53f4178c22115b4ab3d59480b5`.

| Check | Result |
|---|---|
| Patch application to pristine source | Clean |
| Reduced regression, pristine / 0033-only | `Remaining virtual register` assertion / verifier clean |
| Reduced regression with hoisting disabled | Both compilers pass |
| Forced-nonreentrant variant of the reduction | Both compilers pass; this variant is a control, not an additional reproducer |
| 18 repaired corpus cases regenerated with pinned Clang | All 18 original assertions removed; 16 complete, two expose the independent scavenger assertion |
| Saved differential, guarded hoisting enabled vs disabled | 4,109 successful pairs, 61 failures on both sides; 16 changed assemblies |
| Reassemble the 16 changed pairs and sum `.text` | 290,375 → 285,865 bytes, a 4,510-byte reduction |
| Leaf IR without `nonreentrant`, through pristine `llc -O2 -stop-before=irtranslator` | Output carries `"nonreentrant"`; disproves the all-soft-stack inference |
| Fresh standalone MOS CodeGen / MC suites | 84 + 46 pass, one unsupported, zero failures |
| Fresh standalone X86 / ARM / AArch64 CodeGen suites | 11,436 pass, 23 expected failures, zero failures |

The saved differential is a comparison of two modes of the same guarded,
stacked compiler. It is not a pristine-versus-0033-only corpus differential.
Frontend rejection accounts for 266 files at each level; 1,390 accepted files
produce 4,170 backend comparisons. The previous emulator evidence remains
internal and was not rerun for this audit.

Artifacts: `build/0033-review-audit/`, including `binary-provenance.json`,
`probe.py` / `probes.json`, `corpus.py` / `corpus.json`, source reductions,
compiler diagnostics, assembled size-comparison objects, and `leaf.mir`.
The cross-target helper tools were built/relinked in the isolated candidate
build before running its suites. `lit.json` records all 11,590 tests: 11,566
pass, 23 expected failures, one unsupported. `llc-0033-only` preserves the
audited compiler. This fresh run closes the original cross-target validation
gap; it does not cover the requested rollback-accounting revision.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`, `xhigh`
reasoning effort) for the independent audit, validation, and documentation.
