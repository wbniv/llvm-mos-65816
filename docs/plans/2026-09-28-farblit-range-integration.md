# Farblit bounded-range production integration

**Later September 28 speed-policy follow-up:** [0070 is integrated and installed locally](../investigations/2026-09-28-far-word-policy.md). Native word indexing is enabled for speed at `-O2`/`-O3`; `-Os`/`-Oz` retain their existing output. The A16 size tradeoff is settled by the build policy. [Independent downstream AI source review](../pr-preparations/2026-09-28/far-word-index/independent-review.md) is complete: no valid-input compiler correctness defect was found. The P2 FileCheck finding is resolved: all 78 assertions have explicit opcode boundaries, all 156 wrong substitutions are rejected, the three real outputs pass, and four focused regression files pass. The preserved assertions accepted 104 of those substitutions; all 78 archived outputs already contained the intended exact opcode. The earlier evidence below is preserved. The [pinned extracted candidate](../pr-preparations/2026-09-28/far-word-index/upstream-series.md) now supplies ordered patches, an assertions build, expanded checks and backend/runtime replay. Independent review of the complete compiler/ABI series remains separate work.

Follow-up attribution: OpenAI Codex CLI 0.157.1 (session source: `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.

## Earlier September 28 evidence

Status: completed locally, September 28, 2026. [Implementation, measurements and qualifications](../investigations/2026-09-28-farblit-range-integration.md).

Attribution: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e61c-c24c-7053-aa56-a4a4e43f12ab`.

## Scope and completed acceptance checks

1. Review the experimental induction proof and narrow it to the lowered byte-comparison form used by the live legalizer. Preserve wrapping, bank crossing, all-users and call restrictions; retain the native-word fallback.
2. Add focused MIR coverage for accepted branches and rejected wrapping, scaling, flag and control-flow patterns. All 26 cases pass in A16, XY16 and disabled A16.
3. Rebuild isolated baseline/candidate Clang, llc and lld. Compare 16 fixtures at `-Os`, `-Oz` and `-O2`; all 192 objects pass the machine verifier. Record growing outputs explicitly.
4. Run original Farblit, pressure and boundary inputs through full LTO. All 36 ROM configurations pass both emulators; repeated timing profiles agree. Run the original per-probe gate and sensitivity tests.
5. Integrate standalone patch 0069 and the Y8 copy expectation, rebuild/install, reconstruct the patch stack, and verify installed outputs against the tested candidate. The installed compiler reproduces 96 objects and 18 ROMs; its disabled option reproduces the baseline set.
6. Preserve evidence and attribution, update current entry points, and review document dependencies.

The range proof is enabled locally. Native-word indexing remains experimental. The full MOS suite retained five known `opt` startup failures ([fixed September 29](../defects/mos-near-nowrap-option-clash.json)); independent review and exact-upstream preparation are separate follow-up work.

Independent-review coordination and summary update: OpenAI Codex CLI 0.157.1 (session source `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.
