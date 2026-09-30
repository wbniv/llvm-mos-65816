# #320/#321 split into reviewable commit series

Status: split landed on branch `split-320-321` in `build/split-320-321/source` (a worktree of `.scratch/carry-clang-upstream/source`), head `1a616f08ea67`. Nothing is posted. On 2026‑09‑30 the series was regenerated with the [native-width pressure-set change](../../../plans/2026-09-30-native-register-pressure-sets.md#application): `GeneratePressureSet = 0` in #321‑1 and the pressure hooks with the `-O3` gate in #321‑8. Every commit hash changed, and every gate below was rerun on the new commits. On 2026‑10‑01 the far-prerequisite repairs (B1–B4, the B6 trunc pattern) and the N3/N4 cleanups were carried into the four #320 commits ([carry](#far-prerequisite-carry-2026-10-01)); the #321 and MC commits are unchanged. Contract: [the split plan](../../../plans/2026-09-30-split-320-321-series.md) and [the carry plan](../../../plans/2026-10-01-far-prerequisite-split-carry.md). **Current #320 (2026‑10‑01, second round):** branch `split-320-321-r2`, nine commits on #594; see [Second round](#second-round-2026-10-01).

Attribution: Claude Code 2.1.283 (t4-opus-high agent), model Claude Opus 5.5 (`claude-opus-5-5`), high reasoning effort; session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`. Far-prerequisite carry: Claude Code 2.1.285 (t4-opus-high agent `a7633adfeee82a4f5`), model Claude Opus 5.5 (`claude-opus-5-5`), high reasoning effort; session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F). Pressure-set regeneration: Claude Code 2.1.285 (t4-opus-high agent), model Claude Opus 5.5 (`claude-opus-5-5`), high reasoning effort; session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F).

| Directory / file | Contents |
|---|---|
| [REVIEWER-MAP-321.md](REVIEWER-MAP-321.md) | 16 #321 commits: purpose, key hunks, tests, validation, default-mode effect, dependency diagram |
| [REVIEWER-MAP-320.md](REVIEWER-MAP-320.md) | 4 #320 commits, the #594 reconciliation point, and where the independent review's B1–B7/N3/N4 findings land |
| [patches-321/](patches-321/) | `git format-patch` of the #321 series on `06bc967d2668` |
| [patches-mc/](patches-mc/) | the two MC address-width commits, unchanged apart from their parent |
| [patches-320/](patches-320/) | the #320 series, applied after `patches-mc/` |
| [spec/](spec/) | everything needed to rebuild the series and its evidence (see [Reproducing](#reproducing)) |
| [evidence/](evidence/) | per-commit suite summaries, default-mode comparisons, red/green proofs, invariant lists, and sha256 of the large logs |

## Chain

`06bc967d2668` → #321 1–16 (`45bc97d89c6a`..`aa868b952570`) → MC `3721ab9a5c0e` "Honor explicit address widths for constant operands" → MC `25c40909b44a` "Preserve long address widths in printed assembly" → #320 1–4 (`abfb29168fca`..`59d98c37ab77`, branch `split-320-321-carry`; before the carry `42785c3bef21`..`1a616f08ea67`, branch `split-320-321`). Current #320: #594 ×3 (`ad7b2f4239a2`..`fcb88211d861`) → `733b59e025ee`..`d19b7155d3c6` (branch `split-320-321-r2`); the reviewed carry `abfb29168fca`..`59d98c37ab77` stays on `split-320-321-carry`.

The MC commits keep their diffs, messages, authors and dates.

## Invariants

The split must reproduce the monolithic patches plus the pressure-set change (`spec/pressure-321.diff` on `340c8ee25d5c`, `spec/pressure-320.diff` on `11044c53d5fc`; `spec/pressure-targets.sh` builds the reference commits), except that it may add test files under `llvm/test/` so every commit carries its own tests.

| Gate | Result |
|---|---|
| #321 end tree vs `340c8ee25d5c` + pressure change (reference `0a9dad44a2d9`, tree `778746df6e90`) | **Equal plus 12 added `llvm/test/` files, no other path** ([list](evidence/321.invariant.txt)); checked by `build-series.sh` and again by applying `patches-321/` to `06bc967d2668` (tree `d6b87f6d2aa6`) |
| #320 end tree vs `11044c53d5fc` + pressure change (reference `fa1928c8b9ca`, tree `deb630c2d43f`) | **Equal plus 18 added `llvm/test/` files and the carried repairs in 11 library files ([`spec/carry-320.diff`](spec/carry-320.diff)), no other path** ([list](evidence/carry/320.invariant.txt)); applying `patches-321/`, `patches-mc/` and `patches-320/` to `06bc967d2668` reproduces every commit tree and ends at tree `c80a2ee108f3` |
| #320 end tree, second round | The pressure-set reference plus #594, the carried repairs and the second-round fixes in 16 library files and 26 added `llvm/test/` files ([list](evidence/r2/320.invariant.txt)); `patches-321/`, `patches-mc/` and the nine `patches-320/` round-trip from `06bc967d2668` to tree `11f4fcadc11a` |
| Every commit builds with assertions and passes MOS CodeGen + MC | **Yes** for all 20 split commits and the MC top (table below); no new warnings in `lib/Target/MOS` |
| Second round: every commit builds, passes MOS CodeGen + MC, no new MOS warnings | **Yes** for all nine #320 commits and far-word patches 5–9, 11 and 14 ([stages](evidence/r2/stages.tsv)) |
| Every added test fails on its parent and passes on its own and every later commit | **Yes** for the carried tests, which also fail on the unrepaired commit ([carry red/green](evidence/carry/red-green.tsv)), and for 12 of the 13 earlier ones ([red/green](evidence/red-green.tsv)). The exception is `native-width-default-pressure.ll`: it checks that #321‑1 keeps upstream's default code, so it passes on its upstream parent by design; it fails on the unchanged #321‑1 and #321‑16 `llc` ([log](../../../defects/evidence/2026-09-30-native-width-pressure-sets/final/test-red-green.log)) |
| Later packet patches apply unchanged | **Yes**: far-word 5–14, the near-index recovery patch, and 0065's 0063/0065 patches (below) |
| No #320 content in the #321 commits (`AS_Far`, `AS_FarPacked`, `FarCC`, `p2`, `Imag32`, `addrspace(2)`) | **None in code.** One test, `xy16-near-indir-y.ll`, carries a data layout string containing `p2:32:8-p3:24:8` |

## Far-prerequisite carry (2026-10-01)

Each fix is in the commit whose code it corrects, with its test ([plan](../../../plans/2026-10-01-far-prerequisite-split-carry.md), [findings status](REVIEWER-MAP-320.md#where-the-independent-reviews-findings-land)). The downstream repairs (`664b877a`) were ported, not copied: the split lowers a stacked far pointer as a direct `p2` load, so the B1 test checks that form; the downstream test comments naming defect records were rewritten as contract statements.

| Gate | Result |
|---|---|
| Build with assertions, MOS CodeGen+MC, no new MOS warnings | #320‑1..4: 161, 166, 168, 170 pass (1 unsupported each), 0 warnings ([stages](evidence/carry/stages.tsv)) |
| Carried tests red on the parent and on the unrepaired commit, green on the own and every later commit (far-word patches 11 and 14 included) | 41 of 41 probes as expected: 14 red runs fail, 27 green runs pass ([red/green](evidence/carry/red-green.tsv)) |
| Default mode vs parent | #320‑1, ‑3, ‑4 identical; #320‑2 identical for compiling inputs ([compares](evidence/carry/)) |
| N3 / N4 in #320 | 0 clang-format lines per commit; 0 history-tag lines |
| Round trip | `patches-321/` + `patches-mc/` + `patches-320/` on `06bc967d2668`: every intermediate tree matches |
| B1–B4 record commands | unrepaired split commit fails with the record's signature; carried commit passes ([records](../../../defects/)) |

Opt-level gating (lesson 4): the only repair that changes code for inputs that compiled before is B2, and only for a far memory intrinsic whose length is not provably 16 bits. Its decision is identical at O0, O1, O2, O3, Os and Oz in A16 and XY16: the eight unprovable or oversized lengths in `far-memop-length.ll` move to the `…_far32` entries (+49 bytes of `.text` over the eight calls), and the four provable lengths and both `far-memset.ll` functions are unchanged ([callees](evidence/carry/b2-levels-callees.tsv), [sizes](evidence/carry/b2-levels-size.tsv)). It is a correctness repair and is not level-gated. No SNES corpus frontend IR (831 files) contains a far memory intrinsic, and the far-word packet's 58 replay objects are byte-identical with and without the carry.

## Second round (2026-10-01)

After the [second independent review](../far-word-rebase/independent-review-2.md) and the user's #594 decision, #320 was rebuilt ([plan](../../../plans/2026-10-01-far-prerequisite-split-carry.md#second-round-594-option-1-b8-b9-n10n16), [map](REVIEWER-MAP-320.md)):

- **#594 carried unchanged** as three commits with mlund's authorship. The register commit needs one token (`bits<16>` → `bits<32>`, after upstream #571).
- **A defect in #594 as posted:** every function with a call that passes stack arguments aborts in the register coalescer, because RL over a reserved pair is not reserved. The next commit fixes it ([record](../../../defects/mos-imag32-reserved-pair-units.json)). It reproduces with #594 alone on upstream `06bc967d2668`.
- **RL allocation on the 65816 only**, behind `MOSSubtarget::hasAllocatableImag32()`, through an empty alternative allocation order elsewhere. Reserving the quads was tried first and moved call arguments on mos6502; twelve MOS tests caught it.
- **B9:** far-word patch 10 (quad spills) is now #320‑1d.
- **B8:** one helper, `dropDeadFarAddressDebugUses`, is called by every far fold that erases an access: #320‑2, #320‑4 and far-word patch 5.
- **N10, N12–N16** applied; N11 queued in the tracker.

| Gate | Result |
|---|---|
| Per commit: build, MOS CodeGen+MC, warnings | 1a: 160, 161, 166; 1b 167; 1c 168; 1d 168; 2: 174; 3: 176; 4: 178; far-word 9: 179, 5: 180, 6: 181, 7: 182, 8: 183, 11: 183, 14: 187 pass (1 unsupported each); 0 MOS warnings ([stages](evidence/r2/stages.tsv)) |
| Red/green | 27 red runs fail and 143 green runs pass ([table](evidence/r2/red-green.tsv)) |
| Default mode vs parent (O2) | identical except #594's 1a‑iii (4 aborts, removed by 1b) and #320‑2's changed errors on far inputs; the only other row is the `trapguard` harness artifact |
| Default mode by level | MC top against #320‑4 at O0, O1, O2, O3, Os and Oz: identical for every input that compiles; only the five far inputs, which fail before and after, change their error ([levels](evidence/r2/levels.txt)) |
| B8/B9 probes (second review) | no far probe fails the verifier on the new #320‑4 or packet; the spill assertion is gone; the near upstream shapes still fail, as recorded ([sweep](evidence/r2/b8-sweep.tsv)) |
| Replay | the 58 far-word configurations give objects identical to the reviewed packet's ([comparison](../far-word-rebase/evidence/split-r2-replay.json)) |
| N3/N4 | 0 clang-format lines in each of our commits; #594's register commit (unchanged) has 5; no history tags |

## Tests the split adds

| Commit | Test | Fails on the parent because |
|---|---|---|
| #321‑1 | `native-width-registers.mir` | unknown register name `a16` (and unrecognized features) |
| #321‑2 | `a16-accumulator-forms.mir` | unknown machine instruction `LDAImag16` |
| #321‑3 | `MC/MOS/index-width-mapping-65816.s` | no `$xh` mapping symbols |
| #321‑3 | `xy16-index-forms.mir` | unknown machine instruction `LDXImm16` |
| #321‑5 | `scavenger-p-undef-6502.ll` | mos6502 -O0 assertion "expected N to be free when saving scavenger register" |
| #321‑6 | `native-spill-copy.mir` | byte spill path assertion on A16 |
| #321‑7 | `coalesce-call-clobbered-imag.mir` | `$rc2`/`$rc3` coalesced into the pair across the call |
| #321‑8 | `a16-load-store.ll` | byte loads and stores |
| #321‑13 | `near-index-nowrap.ll` | mosw65816 folds the plain and global-base adds |
| #321‑15 | `a16-small-add.ll` | `adc #2` under +mos-a16 |
| #321‑1 | `native-width-default-pressure.ll` | passes on the parent by design (it pins upstream's default code); fails on the unchanged #321‑1, whose native classes had pressure sets |
| #321‑8 | `native-width-pressure-opt-level.ll` (`REQUIRES: asserts`) | no `A16` pressure set: the parent selects no native values |
| #320‑1 | `imag32-copy.mir` | unknown register name `rl2` |
| #320‑2 | `far-ptr-arg-exhaustion.ll` | parent: p2 not legal; unrepaired #320‑2: "Copy Instruction is illegal with mismatching sizes" |
| #320‑2 | `far-access-non-65816.ll` | parent: p2 not legal; unrepaired #320‑2: mos6502 far accesses compile without a diagnostic |
| #320‑2 | `far-ptr-trunc.ll` | parent: p2 not legal; unrepaired #320‑2: `selectTrunc` assertion |
| #320‑3 | `far-memop-length.ll` | lengths above 0xFFFF call the 16-bit entries |
| #320‑3 | `far-access-non-65816.ll` (extended) | a far memset on mos6502 is not diagnosed |
| #320‑4 | `far-index-fold-debug.ll` | the dead pointer's DBG_VALUE is not dropped; `-g` fails the verifier |

`scavenger-p-undef-6502.ll` is reduced from gcc.c-torture `strlen-4.c` and comes from the downstream tree's tests. It shows that #321‑5 also fixes an assertion in default mos6502 code at -O0. The other twelve tests were written for this split. None has been copied into downstream `0002`: applying the pressure-set change downstream is held for a user decision ([plan](../../../plans/2026-09-30-native-register-pressure-sets.md#application)).

## Per-commit evidence

Build and suite: an assertions build per commit in `build/split-320-321/build` (hard-link copy of `build/far-word-rebase/build`), MOS CodeGen + MC lit in the dev container, with the not-yet-added tests probed against each build. The regenerated series ran build, suites, probes and default-mode hashes in one pass per commit (labels `p-*`, so `llc_sha256_same_as_default_run` in [series-evidence.tsv](evidence/series-evidence.tsv) compares a binary with itself). The first split's `t-*` and unprefixed evidence is kept for the superseded commits. After the run, the messages of #321‑12 and #321‑13 were corrected to the new default-size numbers, which changes the hashes of #321‑12 onward; every tree is unchanged ([`evidence/p-message-update.tsv`](evidence/p-message-update.tsv): run commit, final commit, tree).

| Commit | lit (pass) | mos6502 vs parent | mosw65816 vs parent |
|---|---|---|---|
| base `06bc967d2668` | 132 | — | — |
| #321‑1 | 134 | identical | identical |
| #321‑2 | 135 | identical | identical |
| #321‑3 | 137 | identical | 68 object-only (`$xh` symbols) |
| #321‑4 | 139 | identical | identical |
| #321‑5..11 | 140–149 | identical | identical |
| #321‑12 | 151 | 16 asm differ | 18 asm differ |
| #321‑13 | 152 | identical | 28 differ (27 asm, 1 newly compiling) |
| #321‑14, 15 | 153, 154 | identical | identical |
| #321‑16 | 155 | identical | 3 asm differ (interrupt handlers) |
| MC ×2 | 160 | — | — |
| #320‑1..4 (carried) | 161, 166, 168, 170 | #320‑2: 5 far inputs fail with a different error (3 now at the far-access diagnostic); others identical | #320‑2: the same 5 fail with a different error; others identical |
| #320‑1..4 (before the carry) | 161, 163, 164, 165 | #320‑2: 5 far inputs fail with a different error; others identical | same |

Each run also has one unsupported test, `getchar-regression.ll` (its own `REQUIRES`). Default-mode method, explanations and code-size numbers: [REVIEWER-MAP-321.md](REVIEWER-MAP-321.md#default-mode-evidence).

## Downstream packets on the split

Each packet's later patches were applied unchanged with `git am -3` on the split, then built and run through the MOS CodeGen and MC suites. Each packet README now has a "Split series" section, a `patches-split/` directory and an `evidence/split-series.json` round-trip record. Their independent reviews are unchanged.

| Packet | Series | Conflicts | Final tree vs previous candidate | Suites | `llc` vs previous candidate |
|---|---|---|---|---|---|
| [far-word](../far-word-rebase/README.md) | #321 1–16, MC ×2, #320 1–4, far-word 5–14 (32) | patches 5 and 12: context from the carried #320 comments and formatting, resolved by hand | `77dc044c39bb` + pressure-set change + the carry + 18 added tests (final `f3aba3593673`) | 179 pass | differs (pressure sets and the carry) |
| far-word, second round | #321 1–16, MC ×2, #320 (9), far-word 9, 5–8, 11–14 (36) | patch 9 moved before patch 5, whose own XY16 test needs its copy costs | final `3ca03f1da90c` | 187 pass | objects of all 58 replay configurations identical to the reviewed packet |
| [near-index](../../2026-09-29/near-index-proofs/README.md) | #321 1–16, recovery patch (17); unchanged by the carry | none | `980fe1f29381` + pressure-set change + 12 added tests + one `MOSFeatures.td` blank line (final `6bd824516c06`) | 157 pass | differs (pressure sets) |
| [0065](../../2026-09-28/0065/README.md) | #321 1–16, 0063, 0065 (18); unchanged by the carry | none | different destination (`26d7c2c1eebf` before; final `cde019345d24`) | 158 pass | differs (destination) |

The rows are the rerun on the regenerated series (`build/split-320-321/evidence/pkt-p-*`). The packets' own replay and runtime measurements predate the pressure-set change and were not repeated; the far-word packet's two X86 0028 tests were not rerun, because the change touches only MOS files.

The coordinator's brief listed the far-word order as MC ×2 before #321. The series keeps #321 first, as the packet's patch 1 did before patches 2–3, because the split and all of its evidence were built in that order.

## Deviations from the plan

Each was needed for a build or test gate, or to keep one concept per commit.

1. **Plan #321‑2 split into 2 (accumulator forms) and 3 (index forms).** Together they were about 600 lines of TableGen, and the index half changes default mosw65816 objects (`XHigh` → `$xh` mapping symbols), which must sit in a named commit.
2. **Plan #321‑6 split into commits 5, 6 and 7, placed before selection.** Scavenger status-flag preservation, native spills/copies and the coalescing guard are separate concepts; the spill/copy lowering comes before the first selection commit so no selection commit can meet a native value it cannot spill. Scavenging (5) precedes spills (6) because both use `computeLiveBefore`, which would otherwise land in the middle of the removed `assertNZDeadAt`.
3. **Plan #321‑4a..4d reordered and split:** 8 loads/stores, 9 s32/s64 lanes and wide any-extensions (plan 4d), 10 ALU and shifts (plan 4b), 11 compares (plan 4c). Wide lanes precede the ALU: in the first ordering, native arithmetic without them failed `anyext-masked-byte.ll` under `+mos-a16` with "unable to legalize … G_UNMERGE_VALUES s64".
4. **Monolithic tests moved to the commit that makes them pass.** `a16-byte-store.ll` and `a16-indirect-byte-store.ll` need a native `adc` producer and the A16 residency peephole, so they land in commit 10. `a16-immediate-width.ll` needs native compares and lands in commit 11.
5. **Late optimization (`threadAccum16`) merged into the ALU commit (10)** instead of plan #321‑6, because the byte-store tests need it.
6. **Byte-index guard is its own commit (12)**: it changes default codegen in both modes and is independent of native widths.
7. **`+mos-xy16` selection is its own commit (14)** instead of being spread over 4a–4c.
8. **Small 8-bit add relief is its own commit (15)**: a register-allocation measure, not ALU selection.
9. **Plan #320‑2 and #320‑3 merged** (commit 2): legalization alone has no observable test. #320 has 4 commits, not 5.
10. **Default-mode changes beyond the expected one.** The plan expected only the near-index no-wrap guard (#321‑13). The split also found #321‑3 (object mapping symbols), #321‑5 (a mos6502 -O0 assertion becomes a pass), #321‑12 (byte-index guard) and #321‑16 (interrupt handlers on plain mosw65816). Each commit message states its effect. The first split also found #321‑1 (register pressure sets); the pressure-set change (item 13) removes it.
11. **Interim text.** Three places carry intermediate-only lines so earlier commits compile without later concepts; the end tree is unaffected: `tryIndexedAddressing16`'s opcode lambdas and constant-offset condition (commits 8–13), `foldableAbsLoad16`'s condition without the Xc16 guard (10–13), and the `selectGeneric` Imag32 pin condition without the indexed far opcodes (#320‑2, ‑3).
12. **Added tests** (coordinator decision after the first report): the end-tree invariant was relaxed to "monolithic tree plus added `llvm/test/` files", and 11 focused tests were added.
13. **Native-width pressure sets** (user decision, 2026‑09‑30; [plan](../../../plans/2026-09-30-native-register-pressure-sets.md)). `GeneratePressureSet = 0` on Ac16, Xc16 and Yc16 is in #321‑1, so its default output equals upstream's. The `MOSRegisterInfo` pressure hooks, the subtarget-taking constructor and the `-O3` gate are in #321‑8, the first commit that creates `Ac16` virtual registers from IR. #321‑8 is now 736 code lines, above the 600-line guide. The end-tree invariant is against the monolithic trees plus this change, and two more tests were added (13 in all).

## Unresolved

- **Resolved: #321‑1 no longer changes default codegen** (pressure-set change, deviation 13; record [`mos-native-width-pressure-sets`](../../../defects/mos-native-width-pressure-sets.json)).
- **Downstream `0002` does not carry the pressure-set change yet.** Applied downstream, the change grows default-mode code by 13,427 B (+0.58%) and native code by about 3 KB over 262 SNES sources at `-Os`, because the downstream carry scheduling (0064/0067, not in this series) relies on the Ac16/Xc16/Yc16-derived pressure sets. With carry scheduling off, the same change shrinks default code by 25,290 B. That is escalated for a user decision ([plan](../../../plans/2026-09-30-native-register-pressure-sets.md#application)).
- **#594 (B7): decided and implemented** (option 1, second round). **B5: the RL numbering is escalated** again: the chosen formula gives `0x30080 + K`, inside the RS type range of the DWARF specification ([plan](../../../plans/2026-10-01-far-prerequisite-split-carry.md#594-carry-one-mechanical-adaptation-one-escalation)). The #594 coordination draft has suggested additions ([594-comment.md](../../2026-10-01/594-comment.md)).
- **Review findings:** B1–B4, B6 and the #320 parts of N3 and N4 are fixed in the #320 commits ([status](REVIEWER-MAP-320.md#where-the-independent-reviews-findings-land)). N3 and N4 in the #321 commits (including the broken "(Native widths: )" in #321‑8) are not changed, so the near-index and 0065 packets keep their commits.
- **0065 measurements** (replay, runtime, loaded pointer) were taken on its `26d7c2c1eebf` series and were not repeated on the split.
- **Commits 5, 7 and 16 independence** from the rest of the series is by code inspection; they were built only in series order.

## Reproducing

[`spec/`](spec/) is a copy of `build/split-320-321/spec/`:

- `321.diff`, `320.diff`: the monolithic diffs with the pressure-set change (`git diff 06bc967d2668 T321`, `git diff B320 T320`; `pressure-targets.sh` builds `T321`, `B320` and `T320` from `340c8ee25d5c`, `0c77988b2e0b` and `11044c53d5fc` with `pressure-321.diff`/`pressure-320.diff` and records them in `pressure-targets.txt`) with the added tests appended (`321.tests.diff`, `320.tests.diff`); `321.spec`, `320.spec`: which diff lines each commit introduces, plus the interim lines (carried over from the first split's diffs by `remap-spec.py`); `stage.py`: emits the cumulative patch for one stage.
- `build-all.sh` (runs `pressure-targets.sh` first), `build-series.sh`: rebuild the whole chain from the specs and `msgs/` (generated by `msgs/gen321.py`, `msgs/gen320.py`) and check both tree invariants.
- `run-stages.sh`, `build-and-test.sh`: per-commit build, suites, probe of not-yet-added tests, and default-mode hashes. `default-hashes.sh`, `compare-hashes.py`, `size-compare.sh`, `obj-diff.sh`: default-mode evidence. `red-green.py`: the red/green table. The regenerated series ran `LABEL_PREFIX=p- PROBE_DIR=build/split-320-321/probe-new-p run-stages.sh` over stage lists that include the base and the MC top (`p321.list`, `p320.list`); `collect-evidence.sh` takes `LIT_PREFIX=p- DEF_PREFIX=p-`. `format-count.sh`: N3 counts. `packet.sh`, `packet-record.py`: downstream packet rebuilds and round-trip records. `collect-evidence.sh`: fills [`evidence/`](evidence/).

The scripts name `build/split-320-321/source` (a worktree of `.scratch/carry-clang-upstream/source`) and its build directory; run them from a copy placed there. Default-mode inputs are `build/split-320-321/default-inputs/` (38 MOS `.ll` tests at the base plus 52 corpus IRs). Full build and lit logs stay under `build/split-320-321/evidence/`; [large-logs.sha256](evidence/large-logs.sha256) records their hashes. Frozen `llc` binaries kept: `build/split-320-321/llc/p-{321,320}-NN` for every commit of the regenerated series, and `{321-00,321-16,320-04}` of the first split.
