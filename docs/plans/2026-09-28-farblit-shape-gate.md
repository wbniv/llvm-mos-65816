# Farblit checks for each instruction shape

Status: implemented and validated. This implements the [completed reconciliation](../investigations/2026-09-27-farblit-byte-load.md#instruction-shape-reconciliation-2026-09-28); the compiler and its optimization policy are unchanged.

Attribution: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `high` reasoning effort; verified session `01a0e529-62c6-7fc2-a0c6-357800272c63`.

## Contract

The gate must associate each generated far access with its C probe, then check its load/store operation, addressing mode, accumulator width and index width. The expected forms are the reconciliation table: native-word `rdw`; the supported byte runtime folds; global `long,X`; and the explicitly retained A16 computed-pointer cases, including `cp8`. Both pressure probes must be checked individually. Missing, duplicate, unlocated or unexpected accesses must fail. A count elsewhere in the object cannot compensate for a missing fold.

Line tables will identify accesses in the optimized, inlined program. Resolve `.file` identifiers rather than assuming file number 0. The September 28 frozen `analysis.json` incorrectly labels all accesses as readback because its capture script assumes 0; preserve it and record the correction with newly validated output. Source markers on memory-expression lines will give the checker stable probe names without changing C behavior or forcing different inlining.

Track M/X register widths through assembly control flow, including branches and joins, so an unrelated `rep` cannot satisfy a width check. Require the fused Y16 load/access pair to remain adjacent. Keep plain non-LTO objects as the code-generation reference and compare their disassembly and relocations with the object carrying line tables; fail if debug attribution changes the generated instructions. Runtime ROMs keep their existing build flags and oracles.

## Steps

1. Add the probe markers and correct fixture/gate comments to describe the current native-word, global-index and copy forms.
2. Implement a checker with explicit expected forms for both feature modes and both fixtures. Integrate it into `dev/farblit.sh`, retain opcode counts only as diagnostics, and remove aggregate acceptance thresholds.
3. Add sensitivity tests using emitted assembly: remove a fold, change native-word width, remove a width transition, insert a Y-clobber between the fused pair, duplicate or omit accesses, corrupt debug attribution, and add unrelated indexed loads until the aggregate minima pass. Each must fail at the affected probe. Exercise nonzero debug file identifiers and control-flow joins.
4. Run the full gate with the preserved 0066 compiler/linker and the currently installed compiler/linker. Retain exact identities and results separately. Require machine-verifier success, the per-probe checks, and all eight host/MAME/bsnes-jg assertions. Preserve all earlier failing logs.
5. Append the gate result and evidence correction to the existing investigation and canonical record, update current summaries, register this plan's dependencies, regenerate views, and pass the documentation, evidence and comment checks.

## Completion criteria

- Both identified toolchains complete the shell gate successfully, with every checked access reported by probe and mode.
- Mutation tests demonstrate that the new gate rejects incorrect shapes even when whole-object opcode totals still satisfy the old minima.
- Historical compiler baselines and earlier evidence remain unchanged. The record distinguishes a repaired test contract from a compiler optimization or new compiler fix.

## Results

All five implementation steps are complete. The gate checks 27 main accesses and two pressure accesses in each mode, with exact instruction/relocation equivalence between the plain object and checked assembly. Both the preserved 0066 and installed toolchains complete the full shell gate with exit 0 and eight passing emulator assertions each. The 15 checker tests pass on each toolchain, including malformed source attribution and an aggregate-minimum-passing mutation with a missing `rd8` fold.

[Results, exact identities, retained logs and the evidence-label correction](../investigations/2026-09-27-farblit-byte-load.md#completed-gate-update-2026-09-28). Compiler behavior and the historical defect baseline are unchanged. The native-word and A16 copy fallback cases remain explicit test contracts.
