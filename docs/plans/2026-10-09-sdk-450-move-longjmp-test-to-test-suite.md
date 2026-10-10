# SDK #450 — answer the review: fix stays in the SDK, test moves to llvm-test-suite

**Published October 10:** the SDK revision is now on existing [#450](https://github.com/llvm-mos/llvm-mos-sdk/pull/450), and the regression is posted as [test-suite #20](https://github.com/llvm-mos/llvm-test-suite/pull/20). The historical preparation, commands, validation and no-publication statements below describe October 9. Current status and exact posted bodies are retained in [the publication receipt](../pr-preparations/2026-10-10/sdk450-publication/publication.json). Publication update: OpenAI Codex 0.162.1, model `gpt-6.1-sol`, medium reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`.

[llvm-mos-sdk#450](https://github.com/llvm-mos/llvm-mos-sdk/pull/450) ("[common] Make `longjmp(env, 0)` return one from `setjmp`") is
**CHANGES_REQUESTED** by `mysterymath` (review of 2026‑10‑05, on head `0f8ad11589f5`). This plan covers the response. It is
tracked by the `[wip T2] Follow SDK PR #450` item in `TODO.md` → *Upstream / Contribution*.

## Context

The review text, verbatim in substance:

- The `setjmp.S` change "seems fine".
- The test must **not** live in the SDK: generic C functionality exercised on the simulator is routed to
  [`llvm-test-suite`](https://github.com/llvm-mos/llvm-test-suite), which runs in many more scenarios than the SDK tests.
- It is "really surprising" there is no test for this there; maybe one exists and is switched off. If none can be enabled easily,
  add the test there.

Facts established 2026‑10‑09 (read from `llvm-mos/llvm-test-suite` `main` = `9f5e9987ba6d`, committed 2026‑01‑09, via `gh api`; the "pushed 2026‑10‑08" first noted here was `gh-pages` benchmark data, not `main`). Items 2, 3 and 5 were measured the same day by the implementing agent (see **Results** below):

1. **The reviewer's guess is right.** `SingleSource/UnitTests/SetjmpLongjmp/` (`C/` with `SimpleCTest.c`, `Looping.c`, `FarJump.c`,
   `WhileLoop.c`, `MultipleSetjmp.c`; `C++/C++Catch.cpp`) exists but is disabled for **every** target by
   `SingleSource/UnitTests/CMakeLists.txt:19‑20`:
   `# FIXME: Disable SJLJ tests for now, until EH edges are represented.` / `# add_subdirectory(SetjmpLongjmp)`.
   The legacy `Makefile` there carries `REQUIRES_EH_SUPPORT = 1`.
2. **Existing tests already hit the bug.** `WhileLoop.c` runs `while (i--)` and calls `longjmp(buf, i)`, so its last iteration is
   `longjmp(buf, 0)`. With the current SDK `setjmp` returns 0 again, `foo(buf, 0)` runs again, and the test should loop forever.
   *This is an inference from reading the source; step 2 below measures it.* The other four `C/` tests use nonzero values only.
3. **No test pins the value.** None of the five checks `setjmp`'s result for the `val == 0` → 1 rule, and the directory has no
   `.reference_output` files. `SingleSource/lit.local.cfg` sets `traditional_output = True`, so the harness *only* compares captured
   output (plus an appended `exit N` line) against a reference file: **without one a test cannot detect this bug.**
4. `UnitTests/CMakeLists.txt` already has an `ARCH STREQUAL "MOS"` block, and the `file(GLOB Source …)` picks up any new top‑level
   `*.c` automatically, so a new standalone test needs **no CMake edit**.
5. `llvm-mos/llvm-test-suite` has no fork under `wbniv`, and no local clone exists.

## Approach

No visible surface (a one‑line source fix plus a test file), so no mockups.

**Split into two PRs, sequenced SDK first** (per the upstream "sequence, don't carry" rule in `~/CLAUDE.md`).

1. **Narrow #450 to the fix only.** Reduce the branch `fix-longjmp-zero` to a single commit touching only
   `mos-platform/common/c/setjmp.S`. Drop `test/CMakeLists.txt`, `test/README.md`, `test/sim/CMakeLists.txt` and `test/sim/setjmp.c`.
   Squash `0f8ad11589` (`docs: cite published longjmp return-value requirement`, +2 lines in `setjmp.S`) into the code commit
   so the source comment is part of the one change. Rewrite the PR body: drop the "simulator test target" paragraph and the
   `test-sim` numbers, keep the POSIX citation, and link the test‑suite PR as the regression test.
2. **Add the regression test to `llvm-test-suite`** as two new standalone files
   `SingleSource/UnitTests/longjmp-zero.c` and `longjmp-zero.reference_output` (picked up by the glob; no CMake edit). It checks `setjmp`'s return for
   `longjmp(env, v)` with `v` = 0, 1, 7, 256, −1 and returns a nonzero exit status on the first mismatch. It **does** ship a `longjmp-zero.reference_output` (`exit 0`): the harness
   compares output only, and without that file the unfixed SDK passes at `-Os` (measured). Reuse the five values from the withdrawn `test/sim/setjmp.c` (`docs/pr-preparations/2026-09-20/sdk-longjmp-zero.patch`).
   Rejected alternative: re‑enabling `SetjmpLongjmp/C` for MOS. The FIXME says the suite is unready for SJLJ *generally*
   (EH edges), so enabling it drags in an unrelated compiler question; the new file is self‑contained. Record the finding in the
   PR text as an offer, not a change: the disabled directory already contains a case (`WhileLoop.c`) that this bug hangs.
3. **Ask, don't assume, about the dependency.** The test fails against any SDK without the fix, so its PR can only be green
   once #450 lands. Say so in the PR body and ask the maintainer whether to hold the test PR until then, or merge it as an
   expected failure. This is the one open question; the reply to the review should raise it.

Optimization levels (project lesson 4): this is a correctness fix with no size/cycle effect worth gating, but the test must run
at the suite's own configured levels. Step 5 confirms it fails and passes at `-O0` and at `-Os`, matching the four levels #450 tested.

## Out of scope

- Native‑65816 `setjmp` for the SNES platform ([report](../upstream-sdk-setjmp-issue.md)); needs a platform home, unrelated to #450.
- Re‑enabling `SingleSource/UnitTests/SetjmpLongjmp` (FIXME on EH edges) and the C++ `C++Catch` test, which needs exceptions MOS lacks.
- Any change to buffer layout or stack restoration in `setjmp.S`.
- **All posting.** Per the standing hold (memory *parked‑items‑do‑not‑resurface*, 2026‑10‑01) every push, force‑push, PR creation
  and comment here is user‑triggered. This plan prepares the artifacts and exact commands only. Before any post, re‑read the live
  PR body and review (the user edits artifacts between turns).

## Results (2026‑10‑09, implementing agent; full record in [validation.md](../pr-preparations/2026-10-09/validation.md))

Nothing was posted. Local artifacts only: SDK branch `fix-longjmp-zero` at `3cf8d11d71f6` (one commit, only `setjmp.S`, on base
`3f6968bbc156`); test‑suite branch `longjmp-zero` at `4ac8bccdeb43` (2 files). Compiler `build/llvm-mos-install`, `clang-23`
sha256 `e532fbee9b78…`. The unfixed and fixed SDK `setjmp.S.obj` differ, so the two builds really carry different code.

| Level | `longjmp-zero` unfixed SDK | fixed SDK | `WhileLoop.c` by hand, unfixed | fixed |
|---|---|---|---|---|
| `-O0` | FAIL | PASS | hangs (`timeout` rc 124) | exit 0 |
| `-O2` | FAIL | PASS | hangs | exit 0 |
| `-O3` | FAIL | PASS | not run | not run |
| `-Os` | FAIL | PASS | hangs | exit 0 |
| `-Oz` | FAIL | PASS | not run | not run |

Unfixed fails only the zero case (got 0, expected 1). Not run: `-O1`, 65C02, platforms other than `sim`, the test in upstream CI.
Corrections this run made to the plan: the `.reference_output` requirement above; `TEST_SUITE_SUBDIRS` must be `SingleSource` (not
`SingleSource/UnitTests`), because `SingleSource/CMakeLists.txt` copies `lit.local.cfg`; the dev container image was not available, so
the host binaries ran natively under `ulimit -c 0; ulimit -v 2000000` (no bare `docker run`).

## Work breakdown

| # | Step | Where | Posting? |
|---|---|---|---|
| 1 | ~~Measure the `WhileLoop.c` hang and the new test against pre‑ and post‑fix SDK (steps 1–5 below)~~ — done 2026‑10‑09 | fresh worktrees under `~/tmp` | no |
| 2 | ~~Prepare the narrowed #450 commit and new PR body~~ — done, drafts in `docs/pr-preparations/2026-10-09/` | fresh SDK worktree off `origin/main`; **not** `vendor/llvm-mos-sdk` (it has another worker's edit to `mos-platform/CMakeLists.txt`) | no |
| 3 | ~~Prepare the test commit and PR body~~ — done locally (fork not created; that is a posting step) | `~/tmp/llvm-test-suite` | no |
| 4 | ~~Draft the reply to the review (fix kept, test moved, dependency question)~~ — done | `docs/pr-preparations/2026-10-09/` | no |
| 5 | Update [`upstream-contribution-status.md`](../upstream-contribution-status.md) (row at line 287 still says "no comments or reviews yet" and "Await initial review"; lines 87 and 532 also stale) and [`upstream-pending-work.md`](../upstream-pending-work.md) (rows near 348–368, 425) in the same commit | repo | no |
| 6 | ~~Force‑push the narrowed branch, post the reply, open the test‑suite PR~~ — done 2026‑10‑10 ([#450](https://github.com/llvm-mos/llvm-mos-sdk/pull/450) head `3cf8d11d71f6`, reply comment, [test-suite #20](https://github.com/llvm-mos/llvm-test-suite/pull/20) head `4ac8bccdeb43`; awaiting re-review, no checks reported) | upstream | **user‑triggered** |

Dispatch rank suggestion for 1–3: **T2** (bounded, settled spec). Steps 4–5 are docs. Step 6 is T5.

## Verification

1. **Fresh SDK worktrees at the PR base**, one with the fix and one without, built against the project toolchain
   (`build/llvm-mos-install`; follow `docs/agent-handoff.md` and `dev/container.sh`, never bare `docker run`; run probes with
   `ulimit -c 0; ulimit -v 2000000`).
   Record the SDK commit SHAs and the `clang` SHA‑256 in the results file (memory *name‑the‑mounted‑build‑in‑records*).
2. **Baseline the existing `WhileLoop.c`** from `SingleSource/UnitTests/SetjmpLongjmp/C/` under `mos-sim` against the *unfixed*
   SDK with a timeout, and record whether it hangs (inference 2 above). Repeat against the fixed SDK; expect it to terminate.
3. **Write `longjmp-zero.c`.** Against the unfixed SDK it must fail (nonzero exit, zero case only); against the fixed SDK it must
   exit 0, on all five values.
4. **Build and run it through the real harness**, not by hand: configure `llvm-test-suite` for MOS (`ARCH=MOS`) in a fresh clone
   and run only that test via `llvm-lit`, fixed and unfixed. Confirm the test is actually collected (the glob picks it up)
   with a non‑empty `lit` listing.
5. **Optimization levels:** repeat steps 3–4 at `-O0` and `-Os` (the suite's configured levels plus the ends of #450's four).
   Report each level separately; a pass at one level answers nothing for the others.
6. **Narrowed #450 diff:** `git diff --stat origin/main...fix-longjmp-zero` lists exactly `mos-platform/common/c/setjmp.S`
   (one file, one commit). Re‑run `dev/check-comment-history.py` on it.
7. **Live‑state check before any post:** `gh pr view 450 --repo llvm-mos/llvm-mos-sdk --json headRefOid,reviewDecision,comments,body`
   compared with this plan's record (head `0f8ad11589f5`, `CHANGES_REQUESTED`).
8. **Tracker docs agree with the live PR** after step 5, and `task todo:lint` is clean.

<!--
When the work lands, this section becomes the permanent record: paste raw output under each numbered step, then PASS/FAIL.
-->
