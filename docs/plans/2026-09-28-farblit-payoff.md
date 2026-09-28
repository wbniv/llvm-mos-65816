# Farblit word indexing and range-proof investigation

**Later September 28 speed-policy follow-up:** [0070 is integrated and installed locally](../investigations/2026-09-28-far-word-policy.md). Native word indexing is enabled for speed at `-O2`/`-O3`; `-Os`/`-Oz` retain their existing output. The A16 size tradeoff is settled by the build policy. Independent upstream review remains separate work.

Follow-up attribution: OpenAI Codex CLI 0.157.1 (session source: `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.

## Earlier September 28 evidence

**Later September 28 follow-up:** the [bounded range proof is integrated and installed](../investigations/2026-09-28-farblit-range-integration.md) as patch 0069. The current gate requires Y8 for both `cp8` accesses in A16 and XY16; native-word `rdw` retains its fallback. All 36 LTO configurations pass both emulators, and 16 checker sensitivity tests pass.

Follow-up attribution: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e61c-c24c-7053-aa56-a4a4e43f12ab`.

## Dated snapshot before range-proof integration

Status: investigation complete, September 28, 2026. [Measured results and disposition](../investigations/2026-09-28-farblit-payoff.md). Production integration and the A16 native-word size policy remain separate work in [TODO](../../TODO.md).

Attribution: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e61c-c24c-7053-aa56-a4a4e43f12ab`.

## Scope and acceptance

Investigate the original Farblit `rdw` and `cp8` shapes on an identified compiler. Use the same input and flags for baseline and candidate. Require actual selected instructions, bank-crossing and wrapping correctness, and measured linked size and execution time before considering adoption. A documented decision to retain the fallback because of a measured tradeoff completes an investigation.

## Completed work

1. Reconcile `0002`, `0061`, `0062`, `0066`, the canonical Farblit record, reports, Git history and live lowering. Capture source identities and input MIR before experimenting.
2. Build an isolated baseline and candidate. Admit word loads through both byte-only gates, keep Y8 for the existing word pseudo, and prove bounded single-block unit induction with either branch orientation. Retain wrapping and unsupported-loop fallbacks.
3. Check the original marked accesses and M/X widths. Add boundary and pressure inputs that execute the candidate, including a word straddling a bank and the 255/256 scaled-index limit. Compare host, MAME and bsnes results.
4. Measure the original loops and complete `main` with the calibrated master-clock probe. Retain repeated raw samples, linked function sizes and the A16 whole-function growth. Correct and preserve the rejected initial timing intervals.
5. Package reproducible evidence, document the adoption decision, update the original TODO entry points and review document dependencies.

The final evidence has fourteen ROM configurations passing both emulators and eighteen timing intervals with identical repeated results. The range-only A16 function saves 101 bytes; adding the word fold costs 62 bytes relative to that candidate while speeding up `rdw` by 25.44%. The preserved patch remains an experiment with both switches off by default.
