# Patch 0036: audit of Claude's independent review

September 23, 2026. Reviewed the [Claude review](0036-claude-review.md), patch,
PR draft, suite JSON, corpus runner/results, saved objects and frozen compilers.
**Verdict: no implementation defect found.** The section classification and
indexed-store address-operand correction are sound. The patch remains unchanged.

## Findings and corrections

- **Scope correction following Will's clarification:** I had removed the SNES
  corpus/emulator evidence based on an overly broad reading of the submission
  restriction. Published ROM demos are encouraged as validation context when
  linked. The PR now restores the 137-program and 79-program results and links
  [By-Value Boundary Trio](https://biohack.net/snes/byvaledge/) and
  [Newton's Fractal](https://biohack.net/snes/newton/). Both pages returned HTTP
  200, and both kernels occur in the saved corpus and runtime-gate records.
  The dependency restriction concerns premature submission of SNES code/configs,
  not citing published demos. These checks provide integration regression
  evidence; the focused tests establish the zero-page defect and fix.
- The corpus comparison must retain its failures: 4,170 backend comparisons
  comprise 4,109 successful pairs with identical assembly and 61 failures on
  both sides. This is not 4,170 successful compilations. The runner also rejects
  266 frontend inputs at each level before the backend comparison.
- The offset probes establish encoding and object round trips, not the runtime
  validity of arbitrary out-of-bounds accesses. The whole-object contract is
  sufficient for valid accesses; the review's assertion that absolute indexing
  is already broken at the page boundary is unnecessary and has been removed.
- The tracker said independent review was pending even though Claude's review
  existed. Review and this follow-up audit are now marked complete.

## Independent checks

- Replayed all RUN lines of the three exact bundled tests on the frozen before
  and after compilers. All three fail the direct/reassembled object comparison
  on the baseline and pass on the candidate, including the 65816 MIR run.
- Added nine offset/CPU probes: offsets -200, -129 and +300, each on mos6502,
  mos65c02 and mosw65816. Loads/stores verify and direct/reassembled objects
  match in every case. These are encoding checks, not runtime C tests.
- Recounted `lit-0036.json`: 140 pass, one unsupported, zero failed on the
  stacked assertion build. The earlier standalone 132-pass record remains
  separate; this audit did not rebuild another 0036-only compiler.
- Recounted `diff6-results.json` and rehashed every successful assembly pair:
  4,109 pairs identical, zero recorded-hash mismatches, 61 shared failures.
- Recounted the internal 137-program record: all round trips pass on both
  builds, summed `.text` is 214,821 bytes on each, and every saved direct object
  is byte-identical before/after. No fresh emulator run is claimed.

Artifacts: `build/review-followups-0033-0037/`, especially `run-tests.json`,
`more-checks.json`, `saved-evidence.json`, `provenance.json`, and the nine
`0036-offset-*` source/assembly/object sets. Frozen compiler hashes are recorded
there; the review's original source/build tree was not modified.

Remaining submission work: current-upstream applicability, branch preparation,
and publication when requested. The independent `mos16(constant)` parser bug
remains outside this patch.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`, `xhigh`
reasoning effort) for the review audit, independent checks, scope/evidence corrections, and tracking updates.
