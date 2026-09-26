# Patch 0033: audit of Claude's analysis, patch, and PR draft

September 23, 2026. Reviewed the Claude-authored
[validation record](0033-validation.md),
[patch](../../../patches/llvm-mos/0033-llvm-spill-hoist-no-new-vregs.patch),
[PR draft](../../upstream-spill-hoist-scratch-vregs-pr.md), source, saved binaries,
and test artifacts. No separate 0033 review document was present.

**Follow-up complete September 23:** the revised per-group spill accounting is
correct. The current patch passes a fresh standalone MOS suite run and its
reduced regression. The original compiler-provenance finding below is withdrawn:
Claude's container-mount explanation is confirmed by the original invocation.
The test's reduction history has moved to the PR/validation record, following
AGENTS.md. No further implementation change is requested.

## Findings

1. **Withdrawn — the cross-target run did use the guarded build.**
   I compared a host path with a container path without checking its bind mount.
   The original invocation at `2026-09-22T23:43:09.579Z` mounts
   `build/newton-postra-build` onto `/work/build/0029-cross-target-build` before
   running `xtarget-hoist.sh`. The guarded `llc-hoist-fix` came from that build.
   Claude's response is correct; my earlier assertion was not. The historical
   count still needed correction: 11,436 passes and 23 expected failures after
   helper-tool reruns. The separately built 0033-only results below remain valid.
2. **Resolved — rollback decremented `NumSpills` per instruction, but insertion
   incremented it per spill-hook call.** The added `--NumSpills` sits inside the loop over
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
5. **Submission scope was narrowed too broadly.** The initial audit removed
   downstream details under the earlier presentation instruction. Will later
   clarified that published ROM demos are encouraged as linked evidence; the
   restriction is premature submission of SNES code/configs, not mentioning
   demos. The [current scope rule](../../upstream-pending-work.md#snes--separate-platform-track)
   supersedes the blanket internal-only interpretation. Broad claims that
   passing three target suites proves every other target unchanged remain
   removed because the tests do not establish that claim.

The revised implementation increments a local `NumHoisted` once per accepted
hook call and commits it to `NumSpills` only after the whole group succeeds.
Refused groups leave the statistic unchanged; instruction count no longer
controls accounting. No real MOS trigger for mixed multi-instruction rollback
has been established, so this part is verified by source inspection, not a
claimed runtime witness.

The test now explains the soft-stack scratch-register contract without narrating
its reduction. Passing the comment-history hook did not override AGENTS.md's
explicit prohibition on test-writing history.

## Follow-up validation

- Exact revised regression: pristine fails with hoisting enabled and passes with
  it disabled; the revised compiler passes both RUN lines.
- Fresh pinned source plus revised 0033 only: 84 MOS CodeGen and 46 MC tests
  pass, one unsupported. The earlier complete cross-target run below covers the
  initial accounting implementation; Claude's later stacked run covers the
  revision. Replacing its failed new AArch64 CHECK with the passing rerun yields
  **11,437 passes and 23 expected failures**, not 11,436 passes.
- Original container invocation retained in
  `build/review-followups-0033-0037/0033-mount-provenance.json`.
- Current test replay, standalone suite, and saved-result accounting are in
  that directory's `run-tests.json`, `0033-lit.json`, and `saved-evidence.json`.
  `provenance.json` identifies the final patch and frozen standalone binaries.
  Final patch SHA-256:
  `354df5d23df68133ce5196fd9c1a5a49fbe986bce074c77585e6d3bb92a91c59`.

## Initial independent checks (before the accounting revision)

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
audited compiler. This independent run confirms the initial implementation; it does not cover
the later rollback-accounting revision, whose checks are recorded above.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`, `xhigh`
reasoning effort) for the initial audit, follow-up review, validation, comment
cleanup, correction of the provenance finding, and documentation.
