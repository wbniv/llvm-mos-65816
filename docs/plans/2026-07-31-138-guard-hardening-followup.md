# #138 follow-up — harden the `combineLdImm` non-GPR guard + close the review loose ends

**Context.** The #138 fix (null `ImmLoad*` store in `MOSLateOptimization::combineLdImm` on a
non-A/X/Y `LDImm` destination) is live upstream as
[PR #584](https://github.com/llvm-mos/llvm-mos/pull/584) (`wbniv:mos-late-opt-nongpr-ldimm`,
CI green ×3, no review yet). A post-hoc review (this session) confirmed the root cause and fix
are correct but surfaced four follow-ups. This plan is the contract for closing them.

**Visible surface:** none — compiler pass, patch files, docs, TODO. No mockup bundle.

## Findings being addressed (from the review)

1. **Guard robustness (main).** `if (!MOS::GPRRegClass.contains(Dst)) continue;` silently
   assumes a non-GPR `LDImm` destination never aliases A/X/Y. True today (Anyi8 ∖ GPR =
   imaginary regs only), but if a future class widening lets `LDImm` write a GPR-aliasing
   register, the `continue` skips invalidation → stale-value rewrite → **silent miscompile**.
   Belt-and-braces at zero cost: mirror the pass's own non-`LDImm` invalidation path before the
   `continue`. Behaviour-identical today; the pinning test (`TAX` fires across
   `$rc2 = LDImm 7`) still passes because `rc2` aliases nothing tracked.
2. **Sibling pattern.** The `TA` handler (~`MOSLateOptimization.cpp:278`) has the identical
   switch-then-unconditional-store shape. Not live (nothing widens `TA`'s def class) — do NOT
   change the code; preempt the reviewer question with a note in the PR.
3. **Unexplained producer.** The gallery's original trigger — `$rl1 = LDImm -1` (Imag32 dest,
   malformed on 65816) from the 2026-07-26 toolchain — vanished with the 2026-07-31 vendor
   rebuild without an identified fixing delta. Post-fix, a returning producer is *silent* in
   release builds (the crash was the only release-mode detector). File a TODO item: root-cause
   or bound the vanished producer, and promote the existing "0 non-AXY `LDImm`s" disasm scan to
   a standing gate.
4. **Truthfulness of the "smallest count" claim.** The PR body says *"Eight simultaneously-live
   bytes is the smallest count that reliably pushes one of the constants out of `A`/`X`/`Y`;
   with four it stays in the GPRs and does not crash."* The reduction log records tests at 4 and
   8 only — 5, 6, 7 were never tried, so "smallest" is an overclaim as written. Verify
   empirically before touching the PR: the trigger condition (a non-GPR `LDImm` destination in
   the MIR entering `mos-late-opt`) is observable on the **fixed** toolchain via
   `-mllvm -print-before=mos-late-opt`, no crashing build needed. Sweep live-byte counts 4–8 on
   the same repro shape; then either (a) the claim holds — record the evidence in the plan
   bundle, no PR change; or (b) a smaller count triggers — correct the PR body sentence and
   `repro-spc700.c`'s comment (fold into the same PR comment/commit as the hardening). Either
   way the posted text must end up saying only what was measured.

   **Measured 2026-07-31 (this plan, pre-implementation).** Oracle = fork-clang
   `-mllvm -stop-before=mos-late-opt` MIR fed to the pristine unfixed
   `build/upstream-llc/bin/llc -run-pass=mos-late-opt` (oracle sanity: the committed regression
   test segfaults it, rc=139). Same repro shape, N simultaneously-live bytes:

   | N | -O1 | -O2 | -Os | -Oz |
   |---|-----|-----|-----|-----|
   | 2 | ok | ok | ok | **CRASH** |
   | 3 | **CRASH** | **CRASH** | **CRASH** | **CRASH** |
   | 4–8 | **CRASH** | **CRASH** | **CRASH** | **CRASH** |

   So outcome (b), and worse than suspected: *both* halves of the sentence are false — eight is
   not the smallest reliable count (three is, for O1–Oz), and four does **not** stay in the
   GPRs (`renamable $rc2 = LDImm 7` appears at every N ≥ 2 tested). Correct the PR body, the
   PR-doc mirror, and `repro-spc700.c`'s comment to the measured matrix; keep the posted 8-var
   repro itself (its transcript stays valid — the bug is *easier* to hit than claimed, not
   harder).
5. **Bookkeeping drift.** Main's `TODO.md` #138 entry says "upstream PR drafted"; the branch
   records PR #584 POSTED (`f1f5cd1`). Update the entry wording (posting already happened;
   merge of `throwaway/138-late-opt-crash` → main remains blocked on the other session's dirty
   `dev/toolchain.sh` hunks — that merge is out of scope here).

## Changes

### A. Vendor code (the hardened guard)

`vendor/llvm-mos/llvm/lib/Target/MOS/MOSLateOptimization.cpp`, replacing the bare `continue`:

```cpp
    // LDImm's destination is not always a GPR. MOSInstrInfo::getRegClass
    // widens it to Anyi8 on SPC700, where `$rcN = LDImm imm` is how
    // `mov dp, #imm` is modelled. Only A, X and Y take part in the rewrites
    // below; an imaginary destination writes none of them, so there is
    // nothing to rewrite. Invalidate any tracked GPR the instruction does
    // modify so a future widening of LDImm's destination class cannot turn
    // this skip into a stale-value rewrite (no such destination exists
    // today; the loop below is expected to do nothing).
    if (!MOS::GPRRegClass.contains(Dst)) {
      if (MI.modifiesRegister(MOS::A, TRI))
        LoadA.MI = nullptr;
      if (MI.modifiesRegister(MOS::X, TRI))
        LoadX.MI = nullptr;
      if (MI.modifiesRegister(MOS::Y, TRI))
        LoadY.MI = nullptr;
      continue;
    }
```

No test change: both existing cases must pass unchanged (that is itself the
behaviour-identical proof). A new test cannot observe the invalidation because no current
register makes it fire.

### B. Patch + branch artifacts

- Regenerate `patches/llvm-mos/0003-late-opt-nongpr-ldimm-dest.patch` (hand-edit — the hunk is
  small; do **not** run `dev/regen-patch.sh`, stale-baseline hazard with in-flight 0018/0019
  stands). Commit on `throwaway/138-late-opt-crash` (worktree
  `/home/will/llvm-mos-65816-138-late-opt`).
- Update `docs/upstream-late-opt-nongpr-ldimm-pr.md` (same branch) so the doc mirrors the
  as-posted PR content after the update.

### C. Upstream PR update

- Commit the hardening on vendor branch `mos-late-opt-nongpr-ldimm` as a **follow-up commit**
  (no force-push; llvm-mos squash-merges anyway), push to `wbniv/llvm-mos`.
- One PR comment: what the follow-up commit does and why (aliasing robustness), plus the
  `TA`-handler sibling note (finding 2) — same shape, not live, deliberately untouched.

### D. Repo bookkeeping (main)

- New TODO item (T3): vanished `$rl1 = LDImm` Imag32 producer — identify the vendor delta that
  removed it or bound it, and promote the non-GPR-`LDImm` disasm count to a standing gate in
  the gallery gate script.
- Amend the #138 `[wip T4]` TODO entry: drafted → POSTED (PR #584). `TODO.md` is dirty with
  other workers' edits — edit only these lines; leave the file uncommitted if foreign hunks
  cannot be separated cleanly, and say so in the handoff.

## Verification

1. Guard present in vendor source: `grep -n "modifiesRegister(MOS::A" vendor/llvm-mos/llvm/lib/Target/MOS/MOSLateOptimization.cpp` shows it inside `combineLdImm`.

    ```
    $ grep -n "modifiesRegister(MOS::A, TRI)" vendor/llvm-mos/llvm/lib/Target/MOS/MOSLateOptimization.cpp
    206:        if (J.modifiesRegister(MOS::A, TRI))
    295:      if (MI.modifiesRegister(MOS::A, TRI))
    316:      if (MI.modifiesRegister(MOS::A, TRI))   <- the new guard (295 is the pre-existing non-LDImm path)
    ```

    **PASS** — line 316 is the hardened guard inside `combineLdImm`, with the X/Y checks and `continue` following it.

2. Incremental rebuild of `llc` succeeds (host ninja in `build/llvm-mos`, or the Docker path if host tools mismatch).

    ```
    $ dev/run.sh toolchain          # background, exit 0
    $ stat -c '%y' build/llvm-mos-install/bin/clang-23
    2026-07-31 20:17:35   (was 17:58:58 — rebuild took; stale-clang-23 gotcha checked)
    ```

    **PASS** — used the canonical Docker path, not host ninja.

3. `llvm-lit llvm/test/CodeGen/MOS/late-opt-spc700.mir` (and the neighbouring late-opt tests) PASS on the rebuilt `llc` — both cases unchanged.

    ```
    PASS: LLVM :: CodeGen/MOS/late-opt-65816.mir (1 of 4)
    PASS: LLVM :: CodeGen/MOS/late-opt-spc700.mir (2 of 4)
    PASS: LLVM :: CodeGen/MOS/late-opt-65c02.mir (3 of 4)
    PASS: LLVM :: CodeGen/MOS/late-opt.mir (4 of 4)
    Passed: 4 (100.00%)
    ```

    **PASS** — spc700 test unchanged and green, i.e. the hardening is behaviour-identical (the transparency case still fires the `TAX` rewrite).

4. Updated 0003 patch applies clean: `git apply --check` against pristine `8be054612` (+0001+0002 layering as in `dev/toolchain.sh`).

    ```
    A: vendor state == new 0003 content (reverse-check clean)      # git apply --reverse --check vs live vendor
    B: applies clean on plain pristine 8be054612                   # git apply --check vs pristine blob
    0003 APPLIES CLEAN on pristine+0001+0002                       # sparse-worktree layering check
    ```

    **PASS** (with a caveat worth recording: main's `0002` did not fully apply in the sparse scratch worktree — the first error was a file outside the sparse set (`llvm/lib/TargetParser/TargetDataLayout.cpp`), which aborts git-apply atomically, but six `llvm/lib/Target/MOS/*` files also reported genuine context mismatches on pristine+0001. Not this plan's scope — possibly stale `0002` vs in-flight edits; the reverse-check against the live vendor tree (A) is the authoritative consistency proof for the built stack.)

5. Live-byte sweep: for each count, MIR captured via `-mllvm -stop-before=mos-late-opt` fed to the **unfixed** pristine `build/upstream-llc/bin/llc -run-pass=mos-late-opt` (oracle sanity: the committed regression test segfaults it, rc=139). Record the smallest triggering count; PR text matches the measurement.

    ```
    oracle-sanity rc=139 (expect 139)
    N=2: O1=ok    O2=ok    Os=ok    Oz=CRASH
    N=3: O1=CRASH O2=CRASH Os=CRASH Oz=CRASH
    N=4: O1=CRASH O2=CRASH Os=CRASH Oz=CRASH
    N=5: O1=CRASH O2=CRASH Os=CRASH Oz=CRASH
    N=6: O1=CRASH O2=CRASH Os=CRASH Oz=CRASH
    N=7: O1=CRASH O2=CRASH Os=CRASH Oz=CRASH
    N=8: O1=CRASH O2=CRASH Os=CRASH Oz=CRASH
    ```

    **PASS** — outcome (b): both halves of the posted sentence were false. PR doc, `repro-spc700.c`, and bundle patch copy corrected on the branch to the measured matrix (three live bytes crash at every level above `-O0`; two at `-Oz`).

6. `gh pr view 584` shows the follow-up commit on the head branch; CI re-run green (async — record the check state at time of writing).

    ```
    To https://github.com/wbniv/llvm-mos.git
       ae5c399eb277..7eedb14a2597  HEAD -> mos-late-opt-nongpr-ldimm
    head: 7eedb14a25970e9a91dce0005ed186d3dd57f911
    checks: Lit Tests (ubuntu-24.04 / windows-2022 / macOS-15) — all IN_PROGRESS at 2026-08-01T02:29Z
    body: updated via REST (gh pr edit hit the projectCards GraphQL deprecation error and did NOT
          apply — silent-failure gotcha; verified post-PATCH: 5 matches of the new text)
    comment: posted (hardening rationale + TA-handler sibling note + corrected count claim)
    ```

    **PASS (CI pending)** — the follow-up commit is the PR head; body + comment live. CI conclusion to be recorded when it lands (all three legs were green on `ae5c399eb277`; the delta is behaviour-identical and lit-clean locally).

7. TODO: new producer item present; #138 entry says POSTED; no foreign hunks staged in any commit (`git diff --cached --name-only` = exactly our files).

    **PASS** — `[T3]` producer/standing-scan item added next to the `lowerCmpZeros` item; the `[wip T4]` #138 entry now records PR #584 POSTED + hardened (`7eedb14a2597` upstream, `0999cfa`/`299b9be` fork branch). `TODO.md` carries pre-existing foreign unstaged edits, so it is deliberately left **uncommitted** on the hot tree (the edit rides with the next TODO commit); the plan file commits alone.
