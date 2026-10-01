# Fourth independent review: the final #320/#321 split and the 0069/0070 packet

October 1, 2026. **No new blocker. Once mlund answers the #594 points, the series can file.** #584 landing first is a sequencing preference, not a dependency: I confirmed that nothing in the series depends on #584's guard. Rounds three to five resolved every finding I raised in reviews 2 and 3 except N18 and B5/B7, which are mlund's to answer, and they closed the older N1–N9.

The rebuilt #321 is behaviour-neutral against the reviewed split. Its only code-token change is one sorted `#include`, and its top produces identical output on 360 input/CPU pairs I checked. All four final trees round-trip from the upstream base. The replay objects are unchanged.

I found five nonblocking items, N23–N27:
- **N23:** #321‑12's message says 57 SPC700 inputs crash in the late optimizer. The real count is 31; the other 26 fail elsewhere.
- **N24:** the HuC6280 frame-index bug also corrupts the *source* of a block move from a stack object to a constant address, a case that #321‑11's message, the record and the new test do not mention. The rule fixes it all the same.
- **N25:** patch 9 puts a fatal error in a copy-*cost* query.
- **N26:** concrete commit splits and reorders that would make review easier.
- **N27:** stale counts in the packet README.

## Exact scope

| Item | Identity |
|---|---|
| Split | branch `split-320-321-r5`: #321 ×16 (`e8441515e009`..`2387a7c83de4`; #321‑11 `7ef7cfc86eb3`), MC ×2 (`71b05b8cef33`, `aa8d6f59bdb7`), #320 ×9 (`6f8854544adc`..`89f253d535b7`); final tree `e55eaca37612` |
| Far-word packet | branch `pkt-r5-far-word`: patches 9, 5, 6, 7, 8, 11, 12, 13, 14 (`536123a57470`..`6db94230bf03`); final tree `cf5525839c2c` |
| Other packets | `pkt-r5-near-index` (`6ddecd0bc6ff`, tree `926d229a9945`), `pkt-r5-0065` (`24b7c4e8a3a8`, tree `09cce8159518`) |
| Compared against | review 3's state (`split-320-321-r2`, `pkt-r2-far-word`), the original split (`split-320-321`, #321 top `aa868b952570`), upstream `06bc967d2668`, #584 head `7f4c37de6219` (open), #593 head `06aad6b5c745` (fetched) |

Frozen `llc` binaries from `build/split-320-321/llc/` (assertion builds):
- `p-321-00` (upstream base) and `p-321-16` (original #321 top);
- `r3-321-10` and `r4-probe-321-11-nohunk`;
- `r5-321-11`/`-12`/`-16`, `r5-mc-2`, `r5-320-1c`/`-2`/`-4`, `r5-fw-11`/`-14`, `r5-pkt-near-index`, `r5-pkt-0065`.

`evidence/r5/stages.tsv` records every r5 `llc` as byte-identical to the previous round's build of the same code. Every `llc` ran under `ulimit -c 0; ulimit -v 2000000` and `timeout`, with at most three in parallel. Nothing under `build/split-320-321/source` was modified: round trips used a scratch index in a `--shared` clone. No LLVM build was performed.

## Coordinator results verified

| Claim | Independent result |
|---|---|
| Final trees: split `e55eaca37612`, far-word `cf5525839c2c`, near-index `926d229a9945`, 0065 `09cce8159518` | **Confirmed.** `git apply --cached` of `patches-321/`+`patches-mc/`+`patches-320/` (27), `far-word-rebase/patches-split/` (36), `near-index-proofs/patches-split/` (17) and `0065/patches-split/` (18) onto `06bc967d2668` gives exactly these trees, with no whitespace warnings. |
| #584 not carried | **Confirmed.** No `MOSLateOptimization.cpp` hunk outside #321‑10's `threadAccum16`, no `GPRRegClass` guard, no `late-opt-spc700.mir`. |
| mosspc700: late-opt crashes are the same at the MC top and the series top, plus `k_mandel_far` | **Confirmed** on the 90-input set at O2. Late-opt crashes: 31 on `p-321-00`, `r3-321-10`, `r5-321-11`/`-12`/`-16`, `r5-mc-2` and `r5-320-1c`, then 32 on `r5-320-2`, `r5-320-4` and `r5-fw-14`. The only addition is `examples_65816_k_mandel_far` (far diagnostics, then the crash). At 1c the 18 "Target hint is outside allocation order" aborts become "ran out of registers", as 1c's message says. |
| #321 reformat is token-equal apart from comments | **Confirmed** independently against the original split's #321 commits (`45bc97d89c6a`..`aa868b952570`). Each commit's subject is unchanged. The only comment-stripped code difference is the sorted `#include "MOSInsertREPSEP.h"` in `MOSTargetMachine.cpp` from #321‑04 on, plus the added test from #321‑11 on. 0 clang-format lines and 0 history-tag lines in every #321 commit. |
| r3/r5 #321 top output equals the old top | **Confirmed** on a sample: `p-321-16` vs `r5-321-16` on the 90 inputs × `mos6502`, `mosw65816`, `moshuc6280`, `mos65ce02` at O2 gives 360 pairs and 0 differences. |
| Suites | `r5-321-11@7ef7cfc86eb3`: 150 + 1. `r5-pkt-near-index`: 158 + 1. `r5-pkt-0065`: 159 + 1. `r5-320-4`: 175 + 1 and `r5-fw-14`: 186 + 1 with my runner, plus 4 MC/MOS `.s` tests (my runner's limitation, explained next). The + 1 is `getchar-regression.ll` (unsupported). |
| Replay identity | **Confirmed.** `r5-fw-14` rebuilds Farblit A16 O2 default (`5283ea31…`) and XY16 O3 default (`3a6d66f8…`). `r5-fw-11` rebuilds XY16 O3 baseline (`41b1482b…`). All three equal the recorded objects. |

The four `.s` failures are my runner's: it uses `llvm-mc` from the shared `build/split-320-321/build`, which is currently checked out at the 0065 packet top `24b7c4e8a3a8` without the two MC commits. The recorded gates (`gate_rc=0`) used per-commit builds.

## Focus items

1. **N17–N22 and the older items.**
   - **N20 (far values off the 65816): resolved.** I tried 12 far-value shapes on `mos6502`, `mos65c02` and `mosspc700` with `r5-320-4`: passed, stored, returned, `ptrtoint`, `inttoptr`, compared, `null`, `select`, global address, call result, a far value loaded through a near pointer, and a near→far cast. Every one stops with `LLVM ERROR: far (address space 2) pointer value requires the 65816; the target CPU has no far pointer registers (in function: …)` (exit 1, no crash dump). The exception is the near→far cast followed by a load, which gets the per-access diagnostic. `mos45gs02`, `moshuc6280`, `mossweet16` and `mos65el02` behave the same, and `mosw65816` still compiles. Review 2's 15 access shapes on `mos6502` still get one diagnostic per access, and far atomics stay a loud generic error (N16, listed in the PR's N7 list).
   - **N21 (DWARF salvage): resolved.** The plan's probe and my `field.ll`, `argoff.ll` and `keep.ll` emit `DW_OP_bregx 0x30081 +1` (RL1+1), with `DW_OP_stack_value` where it applies. In `keep.ll`, the live pointer keeps `DW_OP_regx`. After the legalizer, `field.ll`'s dead `q` is `DBG_VALUE %0(p2), $noreg, …, DW_OP_plus_uconst 1, DW_OP_stack_value` rather than `$noreg`. The 4-byte address size is confirmed by the plan's dump. The register number itself is B5.
   - **N2 (patch 11 minimal form): resolved.** `copyHasUndefLanes` computes exactly the old in-loop `CopyHasUndefLanes`: the same `isCopy`/`LIS`/virtual-source/subrange guards, the same lane mask, and evaluation at the same point before operands are rewritten. It is passed to `handleIdentityCopy`, which tests it in the same place. The 38-line diff replaces the old function extraction. The default-mode change (`examples_snes_bf-vm`, +8 bytes on 12 CPUs) predates the minimal form and is stated in the message.
   - **N19, N22: resolved.** 1b's message and test name both signatures, and `mos-far-fold-dangling-dbg-sites` is `fixed`.
   - **N1: resolved,** with a robustness caveat (N25).
   - **N5: resolved.** `-mos-far-loop-range` is gone, and `-mos-far-word-index=all` now requires `!F.hasOptNone()`.
   - **N3/N4: resolved.** Only #594's own commit has clang-format lines (11, mlund's code).
   - **Not rerun:** N8's 262/262 sensitivity count. N7 is documentation.
   - **N18: open** (mlund).
2. **#584 sequencing.**
   - Verified as above. The messages, the split README, `REVIEWER-MAP-320.md` and `upstream-contribution-status.md` all say #584 files first and is not carried.
   - Every #320 default-mode line I checked is accurate: 1b, 1c, 1d, #320‑2's `k_mandel_far` clause, #320‑3 and #320‑4.
   - One #321 line is wrong (N23).
   - No dependency: the round-four risk check showed the series top passes, the LZSS IR fails identically with and without the guard, and the replay is identical. Per the record, the crash needs an `LDImm` into an imaginary register, which only SPC700's widened destination class allows. Filing order is therefore a presentation choice.
3. **HuC6280 in #321‑11.**
   - The probe evidence holds. With the rule reverted, `examples_65816_a16frameidx` moves every compare operand.
   - I re-ran `frame-index-displacement.ll` half by half. The CMP and HUC halves both fail on `p-321-00`, `r3-321-10` and `r4-probe-321-11-nohunk`. Both pass on `r5-321-11`, `r5-321-16`, `r5-320-4` and `r5-fw-14`.
   - On the upstream base, the HUC input emits `tii …,.Lfill_sstk+16,#16` twice.
   - The message is accurate for what it says, but incomplete. It describes only the *destination*. The same upstream rule also adds the destination operand to a *source* frame index when the destination is a constant address (N24).
   - Keeping the fix inside a 16-bit compare commit is the user's decision. The reviewer map should point reviewers at it explicitly.
4. **#321 reformat.** Behaviour-neutral, as shown in the table.
5. **N9.**
   - *#593:* the probe commit `bae6eebd8fa6` keeps all of #593. Its `SplitCSR` check in `emitIncDecMB`, its MCInstLower assertion and its `Eligible`/`PairRequired` logic all sit around #594's quad branch. The assertion is placed after the relocated-register early exit, so a quad's halves recorded with the quad are handled before it. That is consistent with the 191 passing tests, including every CSR and far test.
   - *#601* merges cleanly and needs the two `a16-*-byte-store.ll` `CHECK-NEXT`s updated after `.cfi_startproc`, by whichever lands second.
   - *#585* merges cleanly.
   - Both #593 and #594 are mlund's, so mention the #593 resolution in the #594 conversation.
6. **Reviewability:** see N26.

## Findings

| # | Severity | Summary | Location |
|---|---|---|---|
| N23 | Nonblocking | #321‑12's default-mode line says 57 mosspc700 inputs "still crash in the late optimizer"; 31 do. 57 is the total of failing inputs (31 late-opt, 18 hint-order aborts, 4 legalization failures, 4 others). | #321‑12 `de6252e3f867` message |
| N24 | Nonblocking | The upstream HuC6280 frame-index bug also hits the source of a block move into a constant address. #321‑11 fixes it, but the message, the record and the test cover only the destination case. | #321‑11 message; `mos-huc-blockmove-frameindex-offset.json`; `frame-index-displacement.ll` |
| N25 | Nonblocking | Patch 9 calls `report_fatal_error` from `copyCost`, a cost query, for any A16 or X16↔Y16 pair. A speculative query would abort a compile that emits no such copy. | `MOSRegisterInfo.cpp` (patch 9 `536123a57470`) |
| N26 | Nonblocking (reviewability) | Separable concerns inside large commits, and test-only follow-up commits | see below |
| N27 | Nonblocking | The packet README's per-commit row cites round-four counts (180 … 189); round five adds one test to each; the split README says "Current (fourth round)" over round-five hashes | `far-word-rebase/README.md`, `split-320-321/README.md` line 19 |

### N24 — HuC6280 source case

```llvm
declare void @llvm.memcpy.p0.p0.i16(ptr, ptr, i16, i1)
declare void @fillbuf(ptr)
define void @out() norecurse {
  %buf = alloca [32 x i8]
  call void @fillbuf(ptr %buf)
  call void @llvm.memcpy.p0.p0.i16(ptr inttoptr (i16 8192 to ptr), ptr %buf, i16 32, i1 false)
  ret void
}
```

`llc -mtriple=mos -mcpu=moshuc6280 -O2` gives:
- on `p-321-00`: `tii .Lout_sstk+8192,8192,#16` / `tii .Lout_sstk+8208,8208,#16` (the source frame index absorbs the destination address);
- on `r5-321-11`: `tii .Lout_sstk,8192,#16` / `tii .Lout_sstk+16,8208,#16`.

Upstream's "next operand is the displacement" heuristic fires for the source operand too, whenever the destination is an immediate address. Add this shape to the record, to #321‑11's default-mode line, and as a third case in `frame-index-displacement.ll`.

### N26 — reviewability

These are concrete steps that would shorten review. None changes code.

- **Split #321‑08** (`6f7d9e07ad75`, +773/−17 lib). About 160 lines are the native pressure-set model: the `MOSRegisterInfo` constructor taking the subtarget and optimization level, the pressure-set hooks, `MOSSubtarget.cpp`, and `native-width-pressure-opt-level.ll`. That is a separate decision from "legalize and select 16-bit loads and stores". As its own commit before #321‑08, with the `-O3` rationale in its message, it would leave #321‑08 at about 610 lines of one concern.
- **Split #321‑10** (`812d7b1c4b24`, +543/−13). `threadAccum16` (+102 in `MOSLateOptimization.cpp`) is a post-RA store/reload peephole, not selection. As its own commit after #321‑10 it can be reviewed and measured alone.
- **Fold the test-only packet commits.**
  - Patch 13 (`53fa78c92597`) adds boundary tests for patch 8 (`far-loop-range-boundaries.mir`) and for patch 12 (`far-word-index-boundaries.mir`, `far-word-rep-sep.mir`, `far-word-policy.mir` pins).
  - Patch 14 (`6db94230bf03`) adds 50 more lines to the patch-12 boundaries test.
  - Reviewers expect a commit's tests in that commit, and both are pure additions. Fold each into the commit whose code it pins, or state in the PR why they stand apart.
- **Subjects.** The two MC commits and all nine packet commits touch only `llvm/lib/Target/MOS` and MOS tests, but lack the `[MOS]` prefix the other 25 use. Patch 11 is the exception: it is a generic `VirtRegMap.cpp` change. Give it a non-MOS subject and say in the PR whether it goes to llvm-project or is an llvm-mos carry; it also changes default code (`bf-vm` +8 bytes), which reviewers will look for.
- **Large hand-written MIR tests.** `far-loop-range.mir` is 1,013 lines, `far-word-policy.mir` 544 and `far-indir-indexed.ll` 512. None is marked as generated. A one-line header saying which functions pin which rule (or a generator note) would save reviewers from reading every function. Splitting `far-loop-range.mir` by rule would also help.
- **Messages are otherwise good.** Every commit states purpose, default-mode effect, tests and a `Validate:` line. `REVIEWER-MAP-321.md` and `REVIEWER-MAP-320.md` exist. Keep the maps' "start here" pointers on the three largest commits (#321‑04 REP/SEP insertion, 811 lines in one new pass; #321‑08; #321‑14).

## What I re-verified

- **Round trips:** four patch sets from `06bc967d2668`: 27, 36, 17 and 18 patches. All final trees match, with 0 warnings.
- **Token equality:** all 16 rebuilt #321 commits against the original split's.
- **Output equality:** `p-321-16` vs `r5-321-16`, 360 pairs.
- **SPC700 census:** 90 inputs × 10 binaries at `mosspc700 -O2`, classifying each failure (late-opt, hint-order, ran-out, far diagnostic, other).
- **Red/green:** `frame-index-displacement.ll` per half on 7 binaries. N20 shapes: 12 × 3 CPUs plus 4 more CPUs. Review 2's B3 shapes on `mos6502`. N21 DWARF on 4 probes at O0 and O2. The N24 probe on 2 binaries.
- **Suites:** 5 commits or packet tops with my runner.
- **Replay:** 3 objects rebuilt.
- **Source and diff reads:** the N2 equivalence, N5 options, N1 code, and the #593 resolution diff (`bae6eebd8fa6`) against #593's own commit.
- **clang-format-diff and history-tag scan** over all 36 packet commits.

## Status of all findings

| # | Status |
|---|---|
| B1–B4, B6, B8, B9 | Fixed (unchanged since review 3; B8 record closed) |
| B5 | Open: RL DWARF numbering `0x30080 + K`, awaiting mlund |
| B7 | Implemented as option 1; awaiting mlund's answer |
| N1 | Fixed (fatal error); see N25 for the cost-query side |
| N2 | Fixed: minimal form, equivalent |
| N3, N4 | Fixed for every commit we wrote (#321 included); #594's commit unchanged (mlund's) |
| N5 | Fixed |
| N6 | Fixed |
| N7 | Fixed in the docs (PR list of loud unsupported far shapes) |
| N8 | Fixed per the record (262/262); not rerun here |
| N9 | Done: #593 resolved, #601 needs two test updates, #585 clean |
| N10, N12–N15 | Fixed (review 3) |
| N11 | Queued (SDK companion); must land with or before #320 |
| N16 | Open, listed in N7 (far atomics stay a loud generic error) |
| N17 | Resolved by sequencing: it is #584, filed first, not carried |
| N18 | Open: #594 as posted aborts calls with stack arguments until 1b; mlund's call |
| N19 | Fixed |
| N20 | Fixed |
| N21 | Fixed (salvage `DW_OP_bregx RL1+1`) |
| N22 | Fixed (record closed) |
| N23–N27 | New, nonblocking |

## Verdict

**Once mlund answers the #594 points (B7, N18 and the B5 numbering), the series can file.** No blocking issue remains in the series itself. #584 can land first as planned, but nothing depends on it.

Before posting:
1. Fix the N23 wording.
2. Extend N24's record, message and test.
3. Have N11's SDK companion ready.

N25 and N26 are worth doing for reviewers but do not gate filing.

## Limits

- All binaries are assertion builds.
- MC `.s` tests were not run with matching `llvm-mc` (see above).
- The sensitivity runner was not rerun.
- I rebuilt 3 of the 58 replay objects; the MAME/bsnes results are the recorded ones.
- My default-mode samples cover the fixed 90-input set, and four CPUs for the reformat comparison.
- Whether the #593 resolution is what mlund wants is his call.

## Attribution

Fourth independent review, probes and this record: **Claude Code 2.1.285**, agent type `t4-opus-high` (agent `a86560004d12c0518`, which also wrote reviews 2 and 3, resumed), model **`claude-opus-5-5` (Claude Opus 5.5)**, **high** reasoning effort, read from this subagent's transcript metadata. It ran as a subagent of session `310aee67-a99e-4b78-ba48-c560322fe80d` ([session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F)). Rounds three to five were implemented by a different agent. mlund keeps authorship of the #594 commits, and earlier contributors keep the credits recorded in their commits and documents.
