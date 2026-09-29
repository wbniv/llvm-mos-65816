# Near-index proof recovery: upstream review packet

Status: complete (2026‑09‑29); the PR is unposted. Prepares the [completed local proof recovery](../investigations/2026-09-27-near-index-overflow-proofs.md) for upstream review. It does not post anything. The [native-width posting hold](../321-upstream-native-width-pr.md) and the [feature-held package gates](../pr-preparations/2026-09-26/feature-held-packages.md) stay in force.

Attribution: Claude Code 2.1.283, model Claude Opus 5.5 (`claude-opus-5-5`), `xhigh` reasoning effort; session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`. Earlier implementation, measurement and review credits stay in their original records.

## Contract

- **Destination:** current `llvm-mos/llvm-mos` main, `06bc967d2668c7c11c4d6eb43a6aed1f99ad258b` (checked on 2026‑09‑29). It is three commits past the 0065 packet's `26d7c2c1eebf`. #605 edits `MOSTargetMachine.cpp`, `MOS.h` and the MOS `CMakeLists.txt`, the three files this pass also edits, so the 0065 destination is not reused.
- **Series:** patch 1 is the reviewed 0065 #321 compiler prerequisite, rebased onto the destination without edits. It already contains the bank-wrap guard `canFoldNearIndex` and its three callers. Patch 2 is the proof-recovery pass. The pass does not depend on 0063 or 0065, so neither is included.
- **Pass source:** logic stays byte-identical to `0002`'s `MOSRecoverNearNoWrap.cpp`. The upstream-convention changes are limited to a pass header for the `create` declaration and a file description comment.
- **Test:** the retained regression loads through `ptr addrspace(2)`. Far address spaces are #320 and are excluded from the prerequisite, so the upstream test uses near-only loops. The retained far input is still replayed downstream as dated evidence.
- **Profitability:** report the fresh extracted-backend replay together with the dated September 27 census. Keep its nine growing configurations and its runtime evidence, and do not describe the savings without the growth.

No visible surface: this is a compiler patch packet, so there are no mockups.

## Steps

1. Reconcile the destination: check upstream main, the history of the touched files, existing near-index/LSR handling (`MOSIndexIV`, `canFoldNearIndex`) and #605's pipeline default.
2. Rebase the prerequisite onto the destination, record the range-diff, and build a baseline (prerequisite-only) toolset.
3. Add the pass and near-only regression, then build the candidate. Freeze both toolsets by hash.
4. Run the MOS CodeGen and MC lit suites on both toolsets. Show that the new regression fails on the baseline and passes on the candidate.
5. Replay the frozen IR corpus (412 inputs × default/A16/XY16) through both backends, and through the candidate with recovery disabled. Record every failure and every size increase.
6. Run the runtime fixtures on the extracted candidate backend: the near-only `near-y-decode.c`, and a derived bank-wrap witness that uses no far pointers.
7. Write the packet README, PR body and evidence. Get an independent review from a separate agent that has not seen this session, then fix its findings.
8. Update the feature-held table, upstream tracker, TODO and document dependencies.

## Results

The [packet](../pr-preparations/2026-09-29/near-index-proofs/README.md) holds the two-patch series, validation, profitability and independent review. Deviations from the contract above:

- **Pass source.** The recovery logic matches `0002`, but the extraction does more than the header split. It renames the pass argument to `mos-near-nowrap-recovery` and inserts the pass by ID. The data layout supplies the index width, and a debug line names the proof path. The rename fixes an `opt` startup abort that [`mos-near-nowrap-option-clash`](../defects/mos-near-nowrap-option-clash.json) records for `0002`. The other changes answer the independent review.
- **New defect.** The replay found [`mos-xy16-preserve-x-p-save`](../defects/mos-xy16-preserve-x-p-save.json) in the #321 prerequisite. Recovery-enabled `boids.c` in XY16 reaches it; IR carrying the recovered flags also fails on the prerequisite alone and downstream.
- **Driver parity.** The destination driver passes `-disable-spill-hoist`, so the final replay and runtime use it. The plain-`llc` replay is kept separately because it hits the known spill-hoist scratch-register defect.
- **Operations.** Aborting configurations filled the disk with systemd core dumps. Every later run used `ulimit -c 0`.

Follow-ups for `TODO.md` await ranking: port the pass rename and ID insertion to `0002`, and repair `preserveX`.

## Verification

1. `git range-diff` between the 0065 prerequisite and the rebased prerequisite shows context-only differences.

    ```text
    git range-diff 26d7c2c1eebf..55ef9c1bdc67 06bc967d2668..fbf0a82fd70a   # evidence/prerequisite-range-diff.txt
    1:  55ef9c1bdc67 ! 1:  fbf0a82fd70a [MOS] Extract opt-in native widths and near-memory prerequisites
        (only hunk-context lines in MOS.h and MOSTargetMachine.cpp differ)
    added/removed lines vs the 0065 patch 1: IDENTICAL (5,508 lines)
    ```

    **PASS**

2. Both toolsets build, and the candidate's `llc` hash is recorded in `evidence/`.

    ```text
    baseline-build.log: [72/72] ... rc=0      candidate-v3-build.log: rc=0 after one ENOSPC relink
    baseline  llc b80064893ccf9fde…   candidate llc c8fb18cbdc4f6e40…   (evidence/identity.json)
    ```

    **PASS**

3. On the candidate, `llvm-lit llvm/test/CodeGen/MOS llvm/test/MC/MOS` has no failures that are absent on the baseline.

    ```text
    baseline  (patch 1): Total 146, Passed 143, Unsupported 1, Failed 2: near-index-proofs.ll, near-index-proofs-debug.ll
    candidate (1 + 2):   Total 146, Passed 145, Unsupported 1
    ```

    **PASS (the only baseline failures are the two new tests)**

4. `near-index-proofs.ll` fails on the baseline and passes on the candidate.

    ```text
    toolset baseline:  default indexed forms EXIT 1; xy16 indexed forms EXIT 1 (CHECK: lda (__rc..),y / sta buf,x not found)
    toolset candidate: all six checks EXIT 0            (evidence/regression.log)
    ```

    **PASS**

5. On the replay, candidate with recovery disabled produces the same code hashes as the baseline for every successful input.

    ```text
    replay-summary.json: disabled_matches_baseline 1046 / 1046, disabled_exit_mismatches 0
    plain-llc replay (replay-summary-llc-only.json): 942 / 942, exit mismatches 0
    ```

    **PASS**

6. The runtime fixtures return `0x5CF0` in all three modes on the candidate backend.

    ```text
    near-y-decode.c and near-index-wrap-near.c: default/a16/xy16 x mame/bsnes-jg -> 0x5CF0 (12/12)
    all runtime checks: 394 pass, 0 mismatch; 4 builds fail to compile on patch 1 too (evidence/runtime-summary.json)
    ```

    **PASS**

7. The independent review is recorded with its own attribution, and every finding is either fixed or answered with a reason.

    ```text
    independent-review.md: approve with changes; findings 1, 2, 5 fixed and re-verified; 3 (attribution) resolved;
    4 (redundant opt RUN) kept as the explicit collision guard; 6 is a patch-1 note; re-review nit fixed in 980fe1f2
    ```

    **PASS**
