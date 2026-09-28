# Farblit word indexing and loop-range payoff

**Later September 28 speed-policy follow-up:** [0070 is integrated and installed locally](2026-09-28-far-word-policy.md). Native word indexing is enabled for speed at `-O2`/`-O3`; `-Os`/`-Oz` retain their existing output. The A16 size tradeoff is settled by the build policy. Independent upstream review remains separate work.

Follow-up attribution: OpenAI Codex CLI 0.157.1 (session source: `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.

## Earlier September 28 evidence

**Later September 28 follow-up:** the [bounded range proof is integrated and installed](2026-09-28-farblit-range-integration.md) as patch 0069. The current gate requires Y8 for both `cp8` accesses in A16 and XY16; native-word `rdw` retains its fallback. All 36 LTO configurations pass both emulators, and 16 checker sensitivity tests pass.

Follow-up attribution: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e61c-c24c-7053-aa56-a4a4e43f12ab`.

## Dated snapshot before range-proof integration

**September 28, 2026: both experiments are implemented and measured.** A bounded-loop proof makes the A16 `cp8` loop 80.40% faster in the measured ROM and reduces its loop body from 92 to 16 bytes. Native-word Y8 indexing makes `rdw` about 25.4% faster and reduces its loop from 103 to 76 bytes. Adding the word fold to the range-only candidate nevertheless grows the complete A16 `main` by 62 bytes. Keep the word fold experimental until its size policy is settled. The range-only result supports preparing a reviewed integration.

The candidates are disabled by default in a preserved experimental compiler. The installed compiler, active patch stack and existing Farblit gate retain their fallbacks. These are controlled `-Os`, **non-LTO** backend measurements; production LTO integration and independent review remain follow-up work.

Attribution: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e61c-c24c-7053-aa56-a4a4e43f12ab`. Earlier work retains its attribution in the [shape reconciliation](2026-09-27-farblit-byte-load.md).

## What was reconciled

[Prior-work audit](../defects/evidence/2026-09-28-farblit-payoff/prior-work.json) covers the structured Farblit record, original reports and follow-up plans, TODO, Git history, standalone patches and live lowering. `0002` provides the runtime byte-index fold; `0061` handles global long,X; `0062` already provides a native M16/Y8 indirect-indexed word pseudo; `0066` repairs the legalizer worklist interaction. The [existing correctness defect](../defects/mos-farblit-byte-load-legalization.json) stays fixed with its original evidence. This investigation does not create a new compiler defect or change that record's status.

The earlier session trial did not establish that a native-word candidate failed: it rebuilt `llc` but compiled through unchanged Clang. It also left the all-users check restricted to byte accesses and attempted a 16-bit index for an existing Y8 word pseudo. This experiment builds separate identified `llc` executables and runs them directly on identical captured pre-legalizer MIR.

## Candidate and proof

The [experimental patch](../defects/evidence/2026-09-28-farblit-payoff/candidate.patch) adds two switches, both off by default:

- `-mos-far-range-experiment`: refine the offset bound for a single-block loop with one constant entry, a unit increment, and a backedge taken exactly while the incremented value differs from a larger constant. It accepts either branch orientation. At memory legalization, the comparison may already be a byte `G_SBC`; the proof checks the exact zero-flag result, carry-in of one, operands and branch polarity.
- `-mos-far-word-experiment`: admit plain native s16 loads in both the entry guard and the all-users walk, then select the existing M16/Y8 word pseudo. It retains the call, escape, atomic and whole-use-group restrictions. The offset plus the final accessed byte must fit 255. Wider word indexes retain explicit pointer computation.

For a start value smaller than the exit value, unit increments reach the exit before integer wrap. Thus the header PHI is at most exit minus one. The proof follows zero extension and constant left shift only when the maximum fits the operation's own width. It keeps the original offset expression, so narrow arithmetic is not reassociated or widened. Unrecognized recurrences use the existing known-bits bound.

In original `rdw`, `j` is 0..63, so `2*j` is at most 126 and the final loaded byte is at offset 127. In `cp8`, `j` is 0..47, so `j+8` is at most 55. The source load uses Y8 and the store retains Y8. Native word loads use M16 with X/Y8, while the accumulator returns to the widths required by surrounding code.

[Disabled-switch control](../defects/evidence/2026-09-28-farblit-payoff/disabled-control.json) produces byte-identical objects to the separately rebuilt baseline in both modes. [Word-only control](../defects/evidence/2026-09-28-farblit-payoff/word-only-control.json), without the range proof, is also byte-identical: the conservative scaled bound remains 510.

## Measurements

The original C input and its optimized MIR are unchanged across alternatives. `baseline` is the rebuilt current lowering; `range` enables only the proof; `both` adds native word indexing. A common installed linker and SDK link all objects with `-fno-lto`. [Exact identities](../defects/evidence/2026-09-28-farblit-payoff/identity.json), [commands](../defects/evidence/2026-09-28-farblit-payoff/commands.json), and [results](../defects/evidence/2026-09-28-farblit-payoff/results.json) retain the comparison.

| Mode and alternative | Complete `main` bytes | `rdw` loop bytes | `rdw` master clocks | `cp8` loop bytes | `cp8` master clocks | Complete `main` master clocks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A16 baseline | 2,050 | 103 | 88,046 | 92 | 58,918 | 356,600 |
| A16 range | 1,949 | 103 | 88,046 | 16 | 11,546 | 308,814 |
| A16 both | 2,011 | 76 | 65,646 | 16 | 11,546 | 289,658 |
| XY16 baseline | 1,939 | 103 | 88,086 | 31 | 20,850 | 294,174 |
| XY16 range | 1,921 | 103 | 88,086 | 16 | 11,546 | 284,774 |
| XY16 both | 1,893 | 76 | 65,686 | 16 | 11,586 | 262,336 |

The range proof saves 101 bytes in A16 `main` and 18 in XY16. Its `cp8` interval is 80.40%/44.62% faster respectively. Adding the word fold reduces `rdw` time by 25.44%/25.43%. Relative to the range-only candidate, that fold grows A16 `main` by 62 bytes and shrinks XY16 `main` by 28. Loop savings alone are insufficient to predict the full function: register allocation and spills elsewhere also change. Both combined candidates remain smaller than the original baseline, by 39/46 bytes.

Every ROM is padded to 524,288 bytes, so physical ROM file size is unchanged. The size evidence is the linked function and loop extent. No final cartridge-size reduction is claimed.

### Timing method and correction

The [calibrated bsnes probe](2026-09-27-mos-carry-timing.md) records executed master clocks, including memory wait states and DRAM refresh. It starts each loop at its first instruction and stops at the instruction immediately after the loop's exit branch, covering all iterations. `main` starts at entry and ends after the expected result is stored. Each of the eighteen intervals runs twice, with identical samples and instruction profiles. The 40-clock XY16 `cp8` difference between `range` and `both` is consistent with one refresh interval; these measurements do not establish an instruction-cost change there.

The runner retains assembly labels to locate intervals and checks that this changes neither object instruction bytes nor code relocations. The existing shape checker verifies all 27 marked main accesses for each configuration, with explicit experimental expectations only for `rdw` and `cp8`. Its M/X analysis follows control flow.

An initial timing attempt stopped at the next named basic block. Some `cp8` exits fell through into result hashing without such a label, so those samples covered different work. [The rejected intervals](../defects/evidence/2026-09-28-farblit-payoff/initial-mixed-interval.tar.gz) are preserved. The table above uses the corrected exit labels; it supersedes the preliminary `cp8` figures reported during the session.

## Correctness and bounds

All **14 ROM/configuration pairs pass MAME and bsnes**: six original Farblit alternatives, four supplementary bounds configurations, and four original pressure configurations. Oracles are `0x1E56EE65`, `0xC9276F1E` and `0xD695`. The [receipt](../defects/evidence/2026-09-28-farblit-payoff/receipt.json) and [validation log index](../defects/evidence/2026-09-28-farblit-payoff/validation.json) identify them. All compiled objects pass the machine verifier.

The [supplementary C fixture](../defects/evidence/2026-09-28-farblit-payoff/bounds.c) uses a host byte-level oracle and checks the following actual instruction shapes, recorded in [the bounds report](../defects/evidence/2026-09-28-farblit-payoff/bounds-shapes.json):

| Case | Required candidate behavior |
| --- | --- |
| 128 words, last byte offset 255 | M16/Y8 indexed load |
| 129 words, final word starts at byte 256 | Native unindexed fallback |
| Induction starts at 250 and exits after wrapping to 6 | Native unindexed fallback |
| Full 256-element byte induction cycle | Native unindexed fallback |
| Byte-wrapped expression before word scaling | Preserve wrapping and native unindexed fallback |
| Non-unit induction step | Retain conservative fallback |
| Copy 248 bytes with source displacement 8 | Y8, maximum offset 255 |
| Copy 249 bytes, or copy with wrapping induction | A16 explicit pointer; XY16 existing Y16 fold |
| Byte-wrapped source index | Preserve the original Y8 expression |
| Native word loop with a call and eight live accumulators | M16/Y8 load under pressure, correct result |

The fixture repeats at byte bases `$C1FFFF`, `$C2FFFF` and `$C1FF80`. The first two make an individual word's low and high bytes straddle a bank. Copy stores cross `$7EFFFF` into `$7F0000`, and independent absolute-address readbacks consume all 256 destination bytes. The original pressure fixture additionally checks the fused Y16 access across call/spill pressure in XY16. This gives bank and mode-transition evidence for the selected candidate, beyond an opcode-count check.

## Disposition and remaining integration

**The requested investigations have runtime and size evidence.** Prepare the range proof for independent review and production integration, including its generic-versus-lowered branch matching and bounded analysis cost. Preserve all unsupported-loop fallbacks. Native word indexing has a measured speed/size tradeoff in A16; settle that policy or add a measured profitability guard before enabling it there. XY16 is favorable on this fixture, with broader workloads still unmeasured.

The experiments cover these `-Os` inputs on the captured downstream stack. They do not establish behavior for all loops, optimization levels, the production LTO pipeline, or unseen programs. No upstream submission or installed default is selected. The [completed investigation plan](../plans/2026-09-28-farblit-payoff.md) and current TODO separate that integration work from the completed measurements.

## Reproduce

The preserved workspace is `.scratch/farblit-payoff`: `bin/llc-baseline`, `bin/llc-candidate`, the compiler overlay, frontend MIR and runtime inputs. [The retained runners](../defects/evidence/2026-09-28-farblit-payoff/measure.py), [supplementary runner](../defects/evidence/2026-09-28-farblit-payoff/validate.py), [shape checks](../defects/evidence/2026-09-28-farblit-payoff/check_bounds_shapes.py), and [MAME commands](../defects/evidence/2026-09-28-farblit-payoff/mame.sh) use that workspace. Reconstruct it from the captured baseline vendor revision/diff, [untracked source overlay](../defects/evidence/2026-09-28-farblit-payoff/baseline-untracked-source.tar.gz), and experimental patch if the local binaries are unavailable. The source archive and tool hashes identify the inputs; binaries remain local rather than being added to Git.

```sh
python3 .scratch/farblit-payoff/measure.py
python3 .scratch/farblit-payoff/validate.py
python3 .scratch/farblit-payoff/check_bounds_shapes.py
dev/container.sh -- bash .scratch/farblit-payoff/mame.sh
```

[The run archive](../defects/evidence/2026-09-28-farblit-payoff/runs.tar.gz) retains ROMs, maps, ELF/object files, assembly, post-legalizer MIR, shape reports, timings, instruction profiles and both emulators' logs. No historical defect baseline was edited.
