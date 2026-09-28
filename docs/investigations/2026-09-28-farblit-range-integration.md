# Bounded Farblit range proof: production validation

**Later September 28 speed-policy follow-up:** [0070 is integrated and installed locally](2026-09-28-far-word-policy.md). Native word indexing is enabled for speed at `-O2`/`-O3`; `-Os`/`-Oz` retain their existing output. The A16 size tradeoff is settled by the build policy. [Independent downstream AI source review](../pr-preparations/2026-09-28/far-word-index/independent-review.md) is complete: no valid-input compiler correctness defect was found. The P2 FileCheck finding is resolved: all 78 assertions have explicit opcode boundaries, all 156 wrong substitutions are rejected, the three real outputs pass, and four focused regression files pass. The preserved assertions accepted 104 of those substitutions; all 78 archived outputs already contained the intended exact opcode. The earlier evidence below is preserved. Review and validation of the extracted upstream stack remain separate work.

Follow-up attribution: OpenAI Codex CLI 0.157.1 (session source: `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.

## Earlier September 28 evidence

**Status: integrated and installed locally, September 28, 2026.** [Patch 0069](../../patches/llvm-mos/0069-mos-far-loop-range.patch) enables the range proof for far byte indexing. The Farblit gate now requires the `cp8` source load to use Y8 in both A16 and XY16. Native-word `rdw` keeps its existing explicit-pointer fallback; its separate experiment still has an unresolved A16 size cost.

Attribution: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e61c-c24c-7053-aa56-a4a4e43f12ab`. This is author review and downstream validation. No independent review, exact-upstream validation or publication is claimed.

## Proof and implementation review

This continues the [measured experiment](2026-09-28-farblit-payoff.md). The [prior-work audit](../defects/evidence/2026-09-28-farblit-range-integration/prior-work.json) reconciles the original Farblit defect, patch stack, live byte-only guards and known test-suite limitation. The legalization defect remains fixed by 0066; this optimization does not change its causal record or historical baseline.

The production proof recognizes only a single-block byte loop with two predecessors, two successors, and a two-input PHI. One input is a constant entry value; the self-edge input is a same-block unit increment. The comparison must be the legalized byte `G_SBC` of that increment and a constant bound, with carry-in one. Its zero result may pass through at most four virtual copies. The conditional branch must mean unequal-to-bound on the self-edge, or equal-to-bound on the exit; the following unconditional branch must take the complementary edge. Generic comparison inputs are covered by tests that run branch legalization first.

The entry value must be unsigned-less-than the bound. Unit increments therefore reach the bound before byte wrapping, so every PHI value is at most bound minus one. The proof follows zero extension and constant left shift only if the maximum fits the shift's original width. It retains the actual offset expression. It does not reassociate narrow addition or replace the existing bank-carry semantics. The expression walk is limited to six inspected levels; unrecognized forms retain the known-bits bound.

The existing checks still require every pointer user to fold, include the last accessed byte in the limit, reject escapes/atomic accesses, and enforce call/lifetime restrictions. The native-word entry and all-users guards remain byte-only. A hidden `-mos-far-loop-range=false` option retains the baseline policy for comparison; LTO needs the option forwarded to the linker as well.

The MIR regression has **26 cases**, exercised in A16, XY16 and disabled A16. They cover both branch orientations, unsigned bounds above 127, the 255/256 displacement boundary, a nonzero start, full-cycle/wrapping induction, non-unit steps, wrong comparison operands or flags, unset carry, bounded copy chains, scaling, narrow expression wrapping and a multiple-block loop. All 78 case/configuration checks pass, and the tracked regression passes with the normal rebuilt compiler.

## LTO profitability

Separate baseline and candidate **Clang, llc and lld** were rebuilt. Both use the same source inputs, SDK and optimization flags. The installed production build then reproduces all 96 candidate objects and all 18 candidate LTO ROMs **byte for byte**. Disabling the proof in the installed compiler and linker reproduces all 96 baseline objects and 18 baseline LTO ROMs byte for byte. [Identities](../defects/evidence/2026-09-28-farblit-range-integration/identity.json), [results](../defects/evidence/2026-09-28-farblit-range-integration/results.json), [installed control](../defects/evidence/2026-09-28-farblit-range-integration/installed-control.json), and [disabled control](../defects/evidence/2026-09-28-farblit-range-integration/disabled-control.json) retain the evidence.

### Original Farblit, full LTO

| Mode | Optimization | `main` bytes, baseline → range | `main` master clocks, baseline → range |
| --- | --- | ---: | ---: |
| A16 | `-Os` | 2,050 → 1,949 | 356,600 → 308,814 |
| XY16 | `-Os` | 1,939 → 1,921 | 294,174 → 284,774 |
| A16 | `-Oz` | 2,085 → 2,085 | 355,972 → 355,972 |
| XY16 | `-Oz` | 1,942 → 1,942 | 311,650 → 311,650 |
| A16 | `-O2` | 3,367 → 3,279 | 344,426 → 311,266 |
| XY16 | `-O2` | 3,211 → 3,235 | 300,276 → 292,108 |

The `-Os` LTO result reproduces the earlier non-LTO measurements. Whole-function time falls by 13.40% in A16 and 3.20% in XY16. The earlier isolated `cp8` measurement remains 58,918 → 11,546 clocks in A16. At `-O2`, XY16 grows 24 bytes while time falls 2.72%; that tradeoff is retained explicitly. `-Oz` output is unchanged.

The calibrated bsnes probe runs each interval in two independent processes; all repeated clocks and instruction profiles agree. Farblit is inlined into `main`. The pressure/bounds profile captures exclude called functions and are retained as deterministic controls, not complete-work speed measurements. The HiROM images remain padded to 524,288 bytes and the pressure LoROM images to 32,768 bytes; savings describe linked code, not physical ROM-file length.

### Broader object sizes

Sixteen fixtures cover Farblit, its pressure and boundary inputs, farindex, farbank, far loops/indirection/stores/memops/memset/casts/arithmetic, near-index wrapping and three far kernels. Both modes at three optimization levels give **192 verified object builds**. These are sums of function-symbol sizes in non-LTO objects, not linked ROM sizes.

| Mode | Optimization | Baseline bytes | Range bytes | Change |
| --- | --- | ---: | ---: | ---: |
| A16 | `-Os` | 11,262 | 11,118 | −144 |
| XY16 | `-Os` | 10,832 | 10,797 | −35 |
| A16 | `-Oz` | 10,932 | 10,932 | 0 |
| XY16 | `-Oz` | 10,438 | 10,438 | 0 |
| A16 | `-O2` | 14,262 | 14,131 | −131 |
| XY16 | `-O2` | 13,835 | 13,842 | +7 |

Only Farblit and the boundary fixture change; **88 of 96 object pairs are byte-identical**. There is no growing `-Os` object in this sample. This supports the downstream default, while limiting the claim about benefits on unseen code. Compile commands retain elapsed times, but concurrent validation and build activity makes them unsuitable for a compile-time profitability claim.

## Correctness and gate results

All **36 LTO ROM configurations pass MAME and bsnes**: three fixtures × two modes × three optimization levels × baseline/candidate. The oracles are `0x1E56EE65` (Farblit), `0xD695` (pressure) and `0xC9276F1E` (bounds). The boundary input preserves bank-straddling word reads, copies across `$7EFFFF`, 255/256 index limits, wrapping induction and narrow arithmetic, unsupported steps and call pressure. Its native-word accesses retain their fallbacks in this range-only build.

The original shell gate passes on both the isolated candidate and installed compiler: eight emulator assertions each, all 27 marked main accesses and two pressure accesses per mode, and plain/debug instruction and relocation equivalence. The checker has **16 passing sensitivity tests**, including rejection of a widened `cp8` index. [Installed gate log](../defects/evidence/2026-09-28-farblit-range-integration/installed-gate.log) and [receipt](../defects/evidence/2026-09-28-farblit-range-integration/receipt.json).

The wider MOS code-generation suite reports **127 passed, two unsupported, five failed**. All five failures are the previously documented `opt` startup collision for `mos-recover-near-nowrap`; they never execute the range proof. The reused `opt` identity and prior-work reconciliation are retained. The new MIR file separately passes. This is not a fully green MOS-suite result.

## Integration and reproduction

Patch 0069 is registered in `dev/toolchain.sh` and excluded from `0002` by `dev/regen-patch.sh`; its MIR test is included in reconstruction checks. Full MOS source and focused-test reconstruction passes. Regeneration only reordered `0002` sections and changed hash abbreviation; all file hunks match, and the original `0002` bytes were retained. Clang and lld are installed under `build/llvm-mos-install`; the rebuilt llc is under `build/llvm-mos/bin`.

The isolated workspace is `.scratch/farblit-range-integration`. Evidence includes source snapshots, baseline vendor revision/diff and untracked overlay, tool hashes, commands, objects, LTO bitcode, ROMs, maps, profiles and raw emulator logs. The candidate source reconstruction is explicitly labelled; production formatting differs only in whitespace, and the installed byte-identity controls establish matching outputs. The initial timing request and first reconstruction attempt that exhausted shared `/tmp` are preserved separately; fixture setup corrections are recorded in the prior-work audit.

```sh
python3 .scratch/farblit-range-integration/sweep.py baseline
python3 .scratch/farblit-range-integration/sweep.py candidate
dev/container.sh -- bash .scratch/farblit-range-integration/mame.sh
python3 .scratch/farblit-range-integration/installed-control.py
python3 .scratch/farblit-range-integration/disabled-control.py
dev/container.sh -- bash dev/farblit.sh
python3 dev/test-farblit-shapes.py
```

[Completed integration plan](../plans/2026-09-28-farblit-range-integration.md). Independent review and destination-revision validation remain prerequisites for upstream preparation. Native-word profitability remains a separate TODO.

Independent-review coordination and summary update: OpenAI Codex CLI 0.157.1 (session source `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.
