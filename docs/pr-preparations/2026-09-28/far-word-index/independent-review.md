# Independent correctness review of 0069 and 0070

**September 28, 2026: source review complete; P2 regression-check finding resolved.** Three separate AI reviewers found no valid-input compiler correctness defect in the inspected implementation. The combined-contract review identified missing opcode boundaries in 0069's FileCheck patterns. All 78 assertions now have explicit boundaries; all 156 wrong-opcode substitutions are rejected, the three correct outputs pass, and four focused regression files pass. The executed follow-up is recorded below.

Initial review repository commit: `0eae3e7a0c42b1d20c482c154ec3716a3674ad1c`. Patch hashes, source/archive comparisons, reviewer identities, report hashes, and audit inputs are retained in [basis.json](independent-review/basis.json). At the initial review, the live legalizer and both MIR files matched the [retained final source archive](../../../defects/evidence/2026-09-28-far-word-policy/source.tar.gz) byte for byte. The raw reports preserve their original workspace paths; that archive contains the legalizer and both MIR sources named in those paths. This review covers the downstream implementation at that identity; the [upstream prerequisite stack](upstream-series.md) now has a separate build and execution record, and remains unreviewed as a complete extracted series.

## Finding and resolution

### REVIEW-INTERACTION-01 — P2: enforce exact opcodes in the 0069 regression

At the reviewed commit, the 0069 assertions used ordinary trailing spaces after `G_LOAD_FAR_INDIR`, `G_LOAD_FAR_INDIR_IDX`, and `G_LOAD_FAR_INDIR_IDX16`. Under the recorded RUN options, FileCheck strips those spaces and performs fixed-substring matching. The relevant implementation is `llvm/lib/FileCheck/FileCheck.cpp:810–812`, `841–845`, and `1132–1137` at vendor revision `8be0546128a55e78c63ca571d466aa72a782cd36`; its file hash is retained in the basis record.

| Intended assertion | Wrong opcode it can also accept | Consequence |
| --- | --- | --- |
| `G_LOAD_FAR_INDIR` followed by a literal space | `G_LOAD_FAR_INDIR_IDX` or `G_LOAD_FAR_INDIR_IDX16` | Rejection and disabled-policy checks can pass when the pointer was folded. |
| `G_LOAD_FAR_INDIR_IDX` followed by a literal space | `G_LOAD_FAR_INDIR_IDX16` | A Y8 expectation can pass on Y16 output. |

The existing `offset_256` input is a concrete example: its A16 access must retain the explicit pointer because its last offset is 256. Its check at `far-loop-range.mir:172` would also accept an erroneous indexed opcode. Similar prefix acceptance weakens the wrapping, flag, branch-polarity, and OFF cases. Labels and the machine verifier do not establish the missing opcode distinction.

**Original review request, now completed:** spell the boundary explicitly after every expected opcode variant; verify that substituting an indexed opcode for a required fallback, or Y16 for required Y8, makes the check fail; then rerun the focused regression. The initial review made no implementation or test changes and executed no compiler, FileCheck, or emulator process. Its original reports and basis record remain unchanged.

This is a definite regression-assertion defect. It does not establish that the compiler emits the wrong addressing form. No compiler defect record or compiler-status change follows from this finding.

### What the retained outputs actually contain

A separate [static token inventory](independent-review/retained-opcodes.json), produced by [this inspection script](independent-review/audit-retained-opcodes.py), examined the archived A16, XY16, and OFF MIR outputs. **All 78 function/configuration entries contain exactly the intended opcode token.** The inventory compares complete tokens, so `_INDIR`, `_IDX`, and `_IDX16` are distinct. It reads retained files without invoking a compiler or test tool.

The historical output observations and runtime results remain evidence for their identified builds. The historical passing FileCheck exit statuses alone did not prove that those assertions rejected the wrong variants. This qualification applies to the original 26-case regression and its reuse in the 0070 focused suite.

### Correction and executed sensitivity checks

**Follow-up on September 28, 2026:** [0069](../../../../patches/llvm-mos/0069-mos-far-loop-range.patch) now uses `G_LOAD_FAR_INDIR{{ }}`, `G_LOAD_FAR_INDIR_IDX{{ }}`, or `G_LOAD_FAR_INDIR_IDX16{{ }}` at each of its 78 expectations. The whitespace is inside a regex block, so FileCheck retains the opcode delimiter when trimming the pattern. The compiler implementation and 0070 patch are unchanged.

The [sensitivity runner](opcode-check-fix/check-sensitivity.py) checks the same three fresh legalizer outputs against the preserved and corrected assertions. It first verifies that each function contains its one intended complete opcode. It then replaces only that token with each of the two other variants, keeping every other byte and all FileCheck label scopes intact. The mutations exercise the text assertions; they are not claimed to be valid compiler input. Each unmodified output passes the machine verifier during generation.

| Check set | Correct outputs accepted | Wrong substitutions rejected | Wrong substitutions accepted |
| --- | ---: | ---: | ---: |
| Preserved assertions | 3/3 | 52/156 | 104/156 |
| Explicit opcode boundaries | 3/3 | 156/156 | 0/156 |

The 104 false acceptances consist of 43 fallback-to-Y8 substitutions, 43 fallback-to-Y16 substitutions, and 18 Y8-to-Y16 substitutions. This includes the A16 `offset_256` case cited in the finding. For example, changing its fallback to `G_LOAD_FAR_INDIR_IDX` passes the preserved check and fails the corrected check. All 156 corrected negative runs terminate with FileCheck exit 1; there are no crashes or unexpected exit codes. The sensitivity runner exits 1 with the preserved assertions and 0 with the corrected assertions.

Fresh lit execution passes `far-loop-range.mir`, `far-word-policy.mir`, `far-native-word.ll`, and `far-indir-indexed.ll`: **4/4 files**. The final log-capturing run required execution outside the sandbox because Python could not create a worker socket there; both the failed setup log and the successful rerun are retained. This is focused downstream validation; the full MOS suite and emulator measurements were not repeated.

[Results and exact identities](opcode-check-fix/results.json) pin the checks, patches, runner, binaries, and every retained archive member. The `llc` hash is `cf5355d392bd37cdce2606c6bb19465db68a63e8ffa911613fabc474ffa2d5f7`, matching the final 0070 measurement build. Applying the standalone test payload to an empty temporary tree reproduces the live MIR exactly; the C++ diff in 0069 is byte-identical to its preserved version. [The archive](opcode-check-fix/artifacts.tar.xz) contains both check files and patch versions, three compiler outputs, commands, individual mutation diagnostics and hashes, and lit results. Earlier review reports, their hashes, the static token inventory, and all benchmark evidence remain preserved.

To replay the sensitivity checks with the identified FileCheck binary, run from the repository root:

```sh
mkdir -p /tmp/far-loop-opcode-evidence
tar -xJf docs/pr-preparations/2026-09-28/far-word-index/opcode-check-fix/artifacts.tar.xz -C /tmp/far-loop-opcode-evidence
python3 docs/pr-preparations/2026-09-28/far-word-index/opcode-check-fix/check-sensitivity.py \
  --filecheck build/llvm-mos/bin/FileCheck \
  --checks /tmp/far-loop-opcode-evidence/corrected-checks.mir \
  --inputs /tmp/far-loop-opcode-evidence/outputs \
  --output /tmp/far-loop-opcode-evidence/replay.json
```

Using `baseline-checks.mir` instead must return exit 1 and report 104 accepted wrong opcodes. **REVIEW-INTERACTION-01 is resolved for the downstream regression.** The later [extracted candidate](upstream-series.md) adds focused coverage and a separate validation record; independent review of the complete series remains pending.

Assertion correction, sensitivity checks, focused lit execution, and closure record: OpenAI Codex CLI **0.157.1** (recorded session source `vscode`), model **`gpt-6-astra`**, **`xhigh`** reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`.

## Source contracts reviewed

| Area | Result |
| --- | --- |
| 0069 induction and control flow | The two-input PHI, entry/self-edge guards, unit increment, byte type, SBC zero-result operand, carry-in one, and complementary terminators support the unsigned bound. `Start < End` reaches End before wrapping, giving a maximum header value of End−1. |
| 0069 arithmetic refinement | Zero extension preserves the bound; constant shifts refine it only when the maximum fits the operation's own width. Unknown forms and depth limits retain known bits. The generated address uses the original offset expression. |
| 0070 admission and policy | Plain s16 loads with exactly two memory bytes require native accumulator support. The speed default honors optimization level, size attributes, and `optnone`; explicit `all` retains validity guards. |
| Mixed users and legalization order | The user walk checks all remaining consumers and final accessed bytes. A word forces the entire group to Y8, including byte-first visitation. Later removal of a folded use does not invalidate the bound already established for it. |
| Calls and memory effects | Existing call/escape restrictions remain in force. Atomic users are rejected. The replacement inherits the original memory operand and preserves the position and width of the native access, including volatile loads. |
| Selection and bank carry | The existing word pseudo selects M16/Y8 indirect-indexed-long addressing. The retained bank-straddling fixtures consume the loaded values and include the intended instruction shapes. |

These assessments assume valid SSA MIR and the declared instruction operand contracts. Invalid predecessor lists or mismatched target-pseudo types do not provide valid-input counterexamples. Full reasoning, source line references, inspected prerequisites, and artifact hashes are in the individual reports.

## Additional coverage recommendations

These were P3 coverage gaps, with no demonstrated implementation failure in the reviewed source. The extracted candidate now adds checks across the five categories below; its [execution record](upstream-series.md) identifies their exact scope, including the limited feature-disabled case. The original requests remain recorded here:

1. **Word endpoint:** directly compare maximum starting offsets 254 and 255 for a two-byte load. The 255 case isolates the final-byte guard; the existing 256 case can be rejected by the earlier starting-offset check.
2. **Operands and mixed siblings:** capture the original base, computed index, memory operand, byte sibling form, and removal of the wide pointer addition. Opcode-only checks cannot catch a type-correct substitution of the wrong operand.
3. **Word-specific rejection paths:** exercise atomics, an escaping pointer, a call between pointer formation and the word load, and disabled accumulator-width support.
4. **Range-proof boundaries:** cover reversed PHI input order, multiple external predecessors, a narrow nonwrapping shift, and the expression-recursion boundary.
5. **A compact IR integration case:** use a runtime base, independently bounded offset, and live native-word consumer to exercise 0070 without depending on 0069's loop matcher.

Broader profitability, compilation overhead, permanent option design, and independent review of the proposed upstream series remain separate development questions in the [author evidence guide](review.md#remaining-development-and-review-questions).

## Review independence and adjudication

Each initial reviewer started in a separate fresh context, inspected code before author conclusions, and did not see the other new reports. All three used OpenAI Codex CLI **0.158.0** (`codex-tui`), exact model ID **`gpt-6-astra`**, **`xhigh`** reasoning effort, verified from their own session metadata. No finer model build identifier is exposed. This is independent AI review by separate contexts; it supplies neither human review nor model diversity.

| Reviewer | Retained report | Session |
| --- | --- | --- |
| 0069 range proof | [Initial review](independent-review/0069-initial.md) | `01a0e72f-5a2d-7530-b114-4bfe66710323` |
| 0070 policy and memory path | [Review](independent-review/0070.md) | `01a0e72f-9fc7-7ec2-845d-f4ffbd66c513` |
| Combined contracts and regression coverage | [Review](independent-review/interaction.md) | `01a0e72f-db92-7062-bd14-764d6c090a2f` |

The initial 0069 review mistakenly treated its trailing spaces as effective delimiters. After receiving the interaction finding, that reviewer checked FileCheck's implementation and issued an [addendum](independent-review/0069-addendum.md) agreeing with the P2 finding and requesting correction of the assertions. Its source-correctness verdict remained unchanged. The initial report and the subsequent correction are both preserved verbatim; the initial acceptance recommendation is superseded by the addendum.

The coordinator also inspected FileCheck's trimming/matching implementation and inventoried the archived MIR tokens. Coordination, adjudication, artifact inspection, and documentation: OpenAI Codex CLI **0.157.1** (recorded session source `vscode`), model **`gpt-6-astra`**, **`xhigh`** reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`. The original implementation and measurement credits remain in their dated records. That initial review did not include fresh test execution, human approval, or completed upstream extraction. The separate assertion correction and executed checks above have the same coordinator attribution.
