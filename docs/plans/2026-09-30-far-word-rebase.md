# Rebase and review the far-loop/native-word series (0069/0070)

Status: verified; the review blocks filing. The rebase, replay and review are complete; the independent review found blocking defects in the far prerequisite, recorded below and in the [packet](../pr-preparations/2026-09-30/far-word-rebase/README.md). This covers the two TODO items "Prepare the bounded Farblit range proof for upstream review" (0069) and "Prepare native-word speed policy 0070 for upstream review". Both are carried by one extracted series in the [September 28 packet](../pr-preparations/2026-09-28/far-word-index/upstream-series.md). Nothing is posted; the #320/#321 holds stay in force.

Attribution: Claude Code 2.1.283, model Claude Opus 5.5 (`claude-opus-5-5`), `xhigh` reasoning effort; session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`. Earlier extraction, measurement and review credits stay in their records.

## Contract

- **Destination:** `llvm-mos/llvm-mos` main `06bc967d2668c7c11c4d6eb43a6aed1f99ad258b`, three commits past the packet's `26d7c2c1eebf`. #605 edits the MOS pass configuration, #586 edits `MOSInstrInfo.td`, and #570 edits GlobalISel utilities.
- **Series:** the same 14 patches, rebased with `git am -3`. Added and removed lines must be unchanged, and any conflict resolution must be recorded.
- **Checks:** repeat the packet's own checks on the rebased trees. These are the MOS CodeGen/MC suites plus the two X86 0028 regressions, the 228-case opcode sensitivity runner, and the 58-configuration frozen-IR replay on MAME and the calibrated bsnes probe. Run both pre-0070 (patches 1–11) and the candidate (1–14). Compare rebased results with the September 28 results configuration by configuration.
- **Review:** an independent agent reviews the complete rebased compiler/ABI series. It covers the packet's open contracts: far-pointer ABI register exhaustion, far-memory intrinsic length domain, the A8 far-pointer limitation, far-quad debug representation, the new copy-cost repair, and the hidden `off|speed|all` switch.
- **Out of scope:** compiler-overhead and independent-application profitability measurements, posting, and immutable evidence links.

No visible surface: compiler patch packet, no mockups.

## Verification

1. All 14 patches apply to the destination, the round-trip tree matches, and every commit's added and removed lines equal the September 28 series.

    ```text
    $ python3 -c "import json; d=json.load(open('evidence/series.json')); print(d['patch_count'], d['roundtrip_all_intermediate_trees_match'], d['head_tree'])"
    14 True d2d7b62b06a19b362d2b54a210c62e9137c9b5bb
    $ grep -c -E '^ *[0-9]+: .* ! ' evidence/range-diff.txt   # commits whose diff text changed (context only)
    14
    $ grep -c -E '^ *[0-9]+: .* = ' evidence/range-diff.txt
    0
    ```

    PASS. Every commit differs from September 28 only in context lines. The independent review confirmed that the sorted added and removed lines compare equal for all 14 patches.
2. Pre-0070 and candidate assertion builds succeed, and binary hashes are recorded.

    ```text
    $ tail -1 evidence/pre0070-build.log; tail -1 evidence/candidate-build.log
    2026-09-29T23:29:55Z rc=0
    2026-09-29T23:30:36Z rc=0
    pre0070   3d82e37332ec llc b86894b7802be95f opt fff0dccf0bc7af60
    candidate 77dc044c39bb llc d7fde754bb0222b4 opt 60a25c112cd59539
    ```

    PASS. The full hashes are in `evidence/identity.json`, and the mounted host directories are in `evidence/suite-provenance.json`.
3. The MOS CodeGen/MC suites and the two X86 regressions pass on the candidate, with no failure absent on the September 28 candidate.

    ```text
    candidate-suite.log:  Total Discovered Tests: 164
                            Unsupported:   1 (0.61%)
                            Passed     : 163 (99.39%)
    pre0070-suite.log:    Failed Tests (3):
                            LLVM :: CodeGen/MOS/far-word-index-boundaries.mir
                            LLVM :: CodeGen/MOS/far-word-index-integration.ll
                            LLVM :: CodeGen/MOS/far-word-policy.mir
    ```

    PASS. The unsupported test is `getchar-regression.ll`, by its own directive. The pre-0070 failures are the three 0070 tests, as designed. The independent runner reproduced 163 passed and 1 unsupported.
4. The sensitivity runner reports 6 positive outputs passing and 228 wrong substitutions rejected.

    ```text
    $ python3 -c "import json; print(json.load(open('evidence/sensitivity-results.json'))['summary'])"
    {'positive_passes': 6, 'mutations': 228, 'rejected': 228}
    ```

    PASS. The reviewer's rerun agreed. Its caveat N8: the two new boundary files are not mutated.
5. All 58 runtime configurations pass MAME and both bsnes runs. Main bytes and master clocks either match the September 28 table or have each difference explained.

    ```text
    $ python3 compare.py   # September 28 upstream-series/validation/runtime-results.json vs evidence/runtime-results.json
    configs 58 58 same keys True
    field differences 0 []
    pass mame==bsnes==expected 58 repeat_equal 58
    ```

    PASS. Object hashes, ROM hashes, main bytes, master clocks and checksums are identical to September 28 for every configuration.
6. The independent review is recorded with its own attribution, and every finding is fixed or answered.

    ```text
    independent-review.md: "Do not file this series yet."  B1–B7 blocking, N1–N9 nonblocking
    downstream replay (llc 9031686c, release):
      B1 abi4.ll        exit -6 with -verify-machineinstrs; exit -11 (SIGSEGV) without
      B2 farmemlen.ll   MISCOMPILE: 70000-byte far memset passes length 4464 (0x1170)
                        MISCOMPILE: 65536-byte far memmove deleted
      B3 rt.ll mos6502  MISCOMPILE: mos6502 far byte load emitted 65816 opcode $A7
      B4 dbgbyte.ll     *** Bad machine code: Generic virtual register use cannot be undef ***
      B5 dbg.ll -O0     DW_AT_location (DW_OP_regx RL1)   (candidate: 46-bit composite)
      B6 tonear/asint   exit 0 (candidate asserts in selectTrunc)
    $ python3 dev/check-defect-evidence.py --worktree
    Defect evidence: PASS (30 records, worktree)
    ```

    PASS for "recorded and answered", not "fixed":
    - The review keeps its own attribution.
    - B1–B4 reproduce downstream and now have confirmed canonical records.
    - B5 and B6 are extraction gaps.
    - B7 needs a maintainer and author decision.
    - N6 is fixed with `evidence/suite-provenance.json`.
    - The remaining findings are the repair list in the packet's "What remains before filing". Those repairs belong to the #320/#321 split series ([plan](2026-09-30-split-320-321-series.md)), so filing stays blocked.
