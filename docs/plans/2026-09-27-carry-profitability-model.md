# Carry-scheduler profitability experiments

## Scope

Investigate whether combining carry preservation with virtual-register pressure improves patch 0064 and the competing-carry gate. Preserve the shipped policies and default as controls. Present results for LLVM discussion without turning a local percentage threshold into an adoption decision.

Implementation and measurements: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e126-2178-79f3-adba-51b951fb1f96`.

No product UI change is involved; the experimental compiler flags and retained report describe the work. **Status:** the bounded investigation and prototypes are complete. The generic contract and a useful cheaper predictor remain open; no default-policy decision is made.

## Reconciliation and hypotheses

The canonical [pressure record](../defects/mos-carry-scheduling-pressure.json), original completion plan, gate report, patches 0064/0067, their Git history and live scheduler were inspected. The physical-pressure-first trial already had no effect on the original growing cases. Earlier eligibility trials recovered some excluded wins while restoring growth. The generic TableGen contract remains unresolved. This work extends the same investigation and uses the preserved final 0067 compiler as its control.

MOSInstrCost already selects bytes for minsize, a bytes/cycles average for optsize, and cycles for ordinary optimized functions. Objective plumbing is available; accurately estimating allocation consequences is the experiment.

1. Test carry as a tie-break after generic virtual-register pressure, rather than just physical-register preferences.
2. Test a weighted carry/virtual-pressure cost using approximate carry preservation and zero-page spill/reload costs. Expose explicit size/speed selection plus the existing function-attribute policy. These are estimates, not a final-output guarantee.
3. If these local estimates cannot distinguish profitable schedules, measure completed-output selection at compilation-unit granularity as a concrete size-oriented fallback. Do not splice independently allocated functions.

## Verification

1. Preserve source, compiler identities, commands and controls; prove default output equivalence on the focused cases.
2. Screen the candidate models against original growth, remaining gated growth and lost wins, then run the selected model over the full fixed census. Separate exploratory selection from broader validation.
3. Measure execution time on affected cases and positive controls, with checksum oracles and repeated runs. Measure compilation overhead for any retained selection implementation.
4. Run appropriate MIR/backend tests with machine verification. Keep the known baseline XY16 VLA observation separate from this profitability question.
5. Update the LLVM-facing report, canonical record and current summaries, refresh document dependencies, and open the report in the browser.

## Verification results

The original five steps above are retained. Steps 1–4 use the [report and immutable receipt](../investigations/2026-09-27-carry-profitability-model.md); the completed-object selector is the full-census alternative evaluated after the pre-allocation models lost savings on the stress screen.

```text
PASS: 278 retained always/gated disassemblies match.
PASS: 1,668 corrected-screen compilations; zero policy-specific failures.
PASS: 10,776 object identities verified; 3,592 selected objects meet the chosen section budgets.
PASS: 260 emulator executions; all oracles and repetitions pass.
PASS: 41 selected links; eight shrink and 33 have equal allocated file-backed section bytes.
PASS: 240 outer compilation invocations; 144 selections and 336 object hashes match retained results.
PASS: two experimental builds each have 181 MOS lit passes and two unsupported tests.
PASS: four selector contract tests, relocated replay and both patch roundtrips.

```

**PASS, steps 1–4:** identities, matching controls, screening, selection, timings, compilation cost, MIR/backend validation and selector contracts are recorded. The screen is biased toward known growth and lost wins, and is not an unseen-source validation. No cheaper predictor is selected for the compiler.

**Step 5:** current entry points and summaries have been updated. The dependency inventory and generated views are refreshed and checked as part of the final documentation/commit checks; the report is opened in the browser at delivery. The prior 5% planning threshold remains historical context, and PR #609 remains withdrawn.
