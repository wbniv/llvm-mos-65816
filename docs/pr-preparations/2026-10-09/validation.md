# SDK #450 follow-up validation (2026-10-09)

**Published October 10:** the SDK revision is now on existing [#450](https://github.com/llvm-mos/llvm-mos-sdk/pull/450), and the regression is posted as [test-suite #20](https://github.com/llvm-mos/llvm-test-suite/pull/20). The historical preparation, commands, validation and no-publication statements below describe October 9. Current status and exact posted bodies are retained in [the publication receipt](../2026-10-10/sdk450-publication/publication.json). Publication update: OpenAI Codex 0.162.1, model `gpt-6.1-sol`, medium reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`.

Raw evidence for steps 1-6 of [the plan](../../plans/2026-10-09-sdk-450-move-longjmp-test-to-test-suite.md) (step 7 is a read-only `gh` check, recorded last). Nothing here has been posted. Step numbers below are the plan's Verification numbers, not renumbered. Prepared by Claude Code 2.1.295, model Claude Sonnet 5.5 (`claude-sonnet-5-5`), reasoning effort high.

## Identity of everything that ran

| Item | Value |
|---|---|
| SDK baseline | `origin/main` of `llvm-mos/llvm-mos-sdk` = [`3f6968bbc156ff9a63102a8e158db868819bd61c`](https://github.com/llvm-mos/llvm-mos-sdk/commit/3f6968bbc156ff9a63102a8e158db868819bd61c) (re-fetched 2026-10-09; unchanged, so the baseline is the recorded commit, not a newer main) |
| Unfixed SDK | detached worktree `~/tmp/sdk450/sdk-unfixed` at `3f6968bbc156`, built in `~/tmp/sdk450/build-unfixed` |
| Fixed SDK | worktree `~/tmp/sdk450/sdk-fixed`, branch `fix-longjmp-zero` = `3cf8d11d71f63fc0b17f6089a3301c9611230cfe` (base + `setjmp.S` only), built in `~/tmp/sdk450/build-fixed` |
| Host build dir of the compiler | `/home/will/llvm-mos-65816/build/llvm-mos-install` (copied, not modified, into `~/tmp/sdk450/prefix-{unfixed,fixed}` so each prefix holds compiler + its SDK) |
| `clang-23` sha256 | `e532fbee9b78871393d3f990b72dc66cec8e7d04b3443621f40a7fd8cf3822b9` (same in both prefixes; matches the 2026-10-01 rebuild recorded in `docs/agent-handoff.md`) |
| `clang-23 --version` | `clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)` |
| `lld` / installed `llc` sha256 | `0d74dddcab805faf5e2848e9667af5af8b58bae2a66284099c1f63738e6094e1` / `6f303945beb17ab3c8a568ca135b926633533b592b01dd6677c22d49fcceca19` (`llc` is not used by the clang driver; recorded for completeness) |
| `mos-sim` sha256 | `b25e71d5b29429d8ad16450be112fe29e3a2511a4de6fd5a4e50eadae4362cd9` (identical bytes built from both SDK trees) |
| `setjmp.S.obj` from `libc.a` | unfixed `05ffd75dda73dd06a88b86bd6bd05997e4712cf71798463ce7de736e87ebcd7a`, fixed `1524d6500b2225135ef12f08d00754f5e0d4fc1126953600015215ae81ba7e1a` (they differ, so the two prefixes really carry different `longjmp`) |
| llvm-test-suite | `llvm-mos/llvm-test-suite` `main` = `9f5e9987ba6dcb99294e26aa62425edf299a97b5` (committed 2026-01-09; the "pushed 2026-10-08" in the plan was `gh-pages` benchmark data, `origin/gh-pages` = `1279eb3dc` at 2026-10-08T15:05:33Z). Test commit on local branch `longjmp-zero` = `4ac8bccdeb434481754b96251aabca055f7de1a5` in `~/tmp/llvm-test-suite` |
| `llvm-lit` | `/home/will/llvm-mos-65816/build/llvm-mos/bin/llvm-lit` (sha256 `5d325d8f13173dc8ee474ed373eaca608f6dd5f2f9c1f6cad8e3ec5c43eb2109`), run with `PYTHONDONTWRITEBYTECODE=1` so nothing was written under `vendor/` |
| Tools | cmake 4.2.3, ninja 1.13.2, Python 3.14.4 |

Deviation from "containers via `dev/container.sh`": the dev image `llvm-mos-65816-dev` is not present in the active Docker context, and none of these steps compile LLVM. They only run the already-installed host binaries `clang-23`/`lld`, `cmake`, `ninja` and `llvm-lit`, which execute natively on the host (`clang-23 --version` above). No bare `docker run` was used. Every probe ran under `ulimit -c 0; ulimit -v 2000000` (SDK library builds under `ulimit -c 0` only). No toolchain rebuild, no `vendor/` access except reading `llvm-lit` from `build/`.

## 1. Fresh SDK worktrees at the PR base, one fixed and one not

Commands (build output files are `~/tmp/sdk450/{cfg,build,install,pinstall}-*.log`):

```
git clone https://github.com/llvm-mos/llvm-mos-sdk.git ~/tmp/sdk450/sdk-base
git worktree add --detach ../sdk-unfixed origin/main
git checkout -b fix-longjmp-zero origin/main && git checkout pr450 -- mos-platform/common/c/setjmp.S && git commit   # 3cf8d11d71f6
git worktree add ../sdk-fixed fix-longjmp-zero
cmake -S sdk-$v -B build-$v -G Ninja -DCMAKE_BUILD_TYPE=MinSizeRel -DLLVM_MOS_BUILD_EXAMPLES=Off \
  -DLLVM_MOS=/home/will/llvm-mos-65816/build/llvm-mos-install -DCMAKE_INSTALL_PREFIX=$PWD/install-$v
cmake --build build-$v ; cmake --install build-$v
cp -a /home/will/llvm-mos-65816/build/llvm-mos-install prefix-$v ; cmake --install build-$v --prefix prefix-$v
cp -a install-$v/bin/mos-*-clang* prefix-$v/bin/      # the install script writes platform symlinks to the configured prefix, not --prefix
```

Raw:

```
$ tail -n 2 build-unfixed.log build-fixed.log
==> build-unfixed.log <==
[20/20] Completed 'mos-platform'
rc=0

==> build-fixed.log <==
[20/20] Completed 'mos-platform'
rc=0
```

`longjmp` epilogue from each prefix's `libc.a` (`llvm-objdump -d setjmp.S.obj | tail`), proving the two SDKs differ:

```
unfixed:   66: a5 00  lda $0 ; 68: a6 00  ldx $0 ; 6a: 60  rts
fixed:     66: a5 00  lda $0 ; 68: a6 00  ldx $0 ; 6a: d0 06 bne $72 ; 6c: c9 00 cmp #$0 ; 6e: d0 02 bne $72 ; 70: a9 01 lda #$1 ; 72: 60 rts
```

PASS (both SDKs built, `rc=0`; identity table above).

## 2. Baseline of the existing `SetjmpLongjmp/C/WhileLoop.c` under `mos-sim`

Not collected by the harness (the directory is disabled), so built by hand with `mos-sim-clang` from each prefix and run under `timeout 10 mos-sim`. Script `~/tmp/sdk450/run-whileloop.sh PREFIX OPT SRC` (compiles, runs with `timeout 10`, prints the stdout line count, the last line, and `sim_rc`; `124` is the `timeout` exit status for a hang):

```
== unfixed -O0
lines=32783 last="Inside foo: "
sim_rc=124
== unfixed -Os
lines=81559 last="Inside fo"
sim_rc=124
== unfixed -O2
lines=81828 last="Inside "
sim_rc=124
== fixed -O0
lines=74 last="Return from longjmp: 1"
sim_rc=0
== fixed -Os
lines=74 last="Return from longjmp: 1"
sim_rc=0
== fixed -O2
lines=74 last="Return from longjmp: 1"
sim_rc=0
```

The unfixed runs never terminate (`sim_rc=124`; the output is the same two lines repeated, the line count only reflects how much the simulator printed in 10 s and is not meaningful). The fixed runs terminate with `sim_rc=0` after 74 lines (37 iterations, two lines each). The inference in the plan holds.

PASS (hang unfixed, terminates fixed, at -O0, -Os and -O2).

## 3. `longjmp-zero.c`, by hand

File: `SingleSource/UnitTests/longjmp-zero.c` in `~/tmp/llvm-test-suite` (commit `4ac8bccdeb43`). Same script, source = the test as committed. Exit status is the test's own: 1 on the first mismatch (zero), 0 otherwise.

```
== unfixed -O0
lines=1 last="longjmp(env, 0): setjmp returned 0, expected 1"
sim_rc=1
== unfixed -Os
lines=1 last="longjmp(env, 0): setjmp returned 0, expected 1"
sim_rc=1
== unfixed -O2
lines=1 last="longjmp(env, 0): setjmp returned 0, expected 1"
sim_rc=1
== fixed -O0
lines=0 last=""
sim_rc=0
== fixed -Os
lines=0 last=""
sim_rc=0
== fixed -O2
lines=0 last=""
sim_rc=0
```

To show that only the zero case fails unfixed, a scratch copy (not committed: `~/tmp/sdk450/probe/longjmp-zero-all.c`) that prints every value instead of returning at the first mismatch:

```
== unfixed -O0
val=0 got=0 expected=1 MISMATCH
longjmp(env, 0): setjmp returned 0, expected 1
val=1 got=1 expected=1 ok
val=7 got=7 expected=7 ok
val=256 got=256 expected=256 ok
val=-1 got=-1 expected=-1 ok
rc=0
== unfixed -Os
val=0 got=0 expected=1 MISMATCH
longjmp(env, 0): setjmp returned 0, expected 1
val=1 got=1 expected=1 ok
val=7 got=7 expected=7 ok
val=256 got=256 expected=256 ok
val=-1 got=-1 expected=-1 ok
rc=0
== unfixed -O2
val=0 got=0 expected=1 MISMATCH
longjmp(env, 0): setjmp returned 0, expected 1
val=1 got=1 expected=1 ok
val=7 got=7 expected=7 ok
val=256 got=256 expected=256 ok
val=-1 got=-1 expected=-1 ok
rc=0
== fixed -O0
val=0 got=1 expected=1 ok
val=1 got=1 expected=1 ok
val=7 got=7 expected=7 ok
val=256 got=256 expected=256 ok
val=-1 got=-1 expected=-1 ok
rc=0
== fixed -Os
val=0 got=1 expected=1 ok
val=1 got=1 expected=1 ok
val=7 got=7 expected=7 ok
val=256 got=256 expected=256 ok
val=-1 got=-1 expected=-1 ok
rc=0
== fixed -O2
val=0 got=1 expected=1 ok
val=1 got=1 expected=1 ok
val=7 got=7 expected=7 ok
val=256 got=256 expected=256 ok
val=-1 got=-1 expected=-1 ok
rc=0
```

(The extra `longjmp(env, 0): ...` line in the unfixed runs is the original early-exit `printf` that the scratch copy kept; the scratch copy only removed the `return 1`.)

Also: `gcc -Wall -Wextra -O2` on the host runs it with rc 0, and `mos-sim-clang -Wall -Wextra -Os -c` is warning-free.

PASS (unfixed: nonzero exit, zero case only; fixed: exit 0 for 0, 1, 7, 256 and -1).

## 4. Through the real harness (`llvm-lit`)

Configure: `cmake -DLLVM_MOS=$HOME/tmp/sdk450/prefix-$v -DTEST_SUITE_SUBDIRS=SingleSource -C cmake/caches/$lvl.cmake -C cmake/caches/target-mos.cmake -G Ninja` (README line 27/33 recipe; `SingleSource`, not `SingleSource/UnitTests`, because `SingleSource/CMakeLists.txt` copies the `lit.local.cfg` that sets `traditional_output = True`; without it every test that has a `.reference_output`, including the untouched `atoi`, fails with "unable to open ... Output/*.out", which I hit first and corrected). Then `ninja longjmp-zero` and `llvm-lit --show-tests` / `llvm-lit -v <build>/SingleSource/UnitTests/longjmp-zero.test`. Driver: `~/tmp/ts-builds/run-level.sh VARIANT LEVEL`.

Collection: `llvm-lit --show-tests` lists `test-suite :: SingleSource/UnitTests/longjmp-zero.test` in every build (non-empty; see the next block). The configure log does not print "No reference output found" for it.

Failure detail, unfixed `-Os` (`~/tmp/ts-builds/unfixed-Os.lit.log`):

```
fpcmp: Comparison failed, textual difference between 'l' and 'e'

Input 1:
longjmp(env, 0): setjmp returned 0, expected 1
exit 1

Input 2:
exit 0
```

## 5. Per optimisation level (each level separate)

Levels run: the four in `.github/workflows/test.yml` (`O0`, `O3`, `Os`, `Oz`) plus `O2` (the README/`O2.cmake` default). Compile flags confirmed from each `build.ninja`: `FLAGS = -O0 / -O2 / -O3 / -Os / -Oz  -w -Werror=date-time -Wno-implicit-function-declaration -Wno-implicit-int`.

| Level | Collected | Unfixed SDK (`3f6968bbc156`) | Fixed SDK (`3cf8d11d71f6`) |
|---|---|---|---|
| `-O0` | yes | FAIL (lit rc=1) | PASS (lit rc=0) |
| `-O2` | yes | FAIL (lit rc=1) | PASS (lit rc=0) |
| `-O3` | yes | FAIL (lit rc=1) | PASS (lit rc=0) |
| `-Os` | yes | FAIL (lit rc=1) | PASS (lit rc=0) |
| `-Oz` | yes | FAIL (lit rc=1) | PASS (lit rc=0) |

Raw (`~/tmp/ts-builds/levels-results.txt`):

```
== unfixed O0: collected tests matching longjmp:
  test-suite :: SingleSource/UnitTests/longjmp-zero.test
-- lit rc=1
FAIL: test-suite :: SingleSource/UnitTests/longjmp-zero.test (1 of 1)
longjmp(env, 0): setjmp returned 0, expected 1
Failed Tests (1):
  Failed: 1 (100.00%)
== fixed O0: collected tests matching longjmp:
  test-suite :: SingleSource/UnitTests/longjmp-zero.test
-- lit rc=0
PASS: test-suite :: SingleSource/UnitTests/longjmp-zero.test (1 of 1)
  Passed: 1 (100.00%)
== unfixed O2: collected tests matching longjmp:
  test-suite :: SingleSource/UnitTests/longjmp-zero.test
-- lit rc=1
FAIL: test-suite :: SingleSource/UnitTests/longjmp-zero.test (1 of 1)
longjmp(env, 0): setjmp returned 0, expected 1
Failed Tests (1):
  Failed: 1 (100.00%)
== fixed O2: collected tests matching longjmp:
  test-suite :: SingleSource/UnitTests/longjmp-zero.test
-- lit rc=0
PASS: test-suite :: SingleSource/UnitTests/longjmp-zero.test (1 of 1)
  Passed: 1 (100.00%)
== unfixed O3: collected tests matching longjmp:
  test-suite :: SingleSource/UnitTests/longjmp-zero.test
-- lit rc=1
FAIL: test-suite :: SingleSource/UnitTests/longjmp-zero.test (1 of 1)
longjmp(env, 0): setjmp returned 0, expected 1
Failed Tests (1):
  Failed: 1 (100.00%)
== fixed O3: collected tests matching longjmp:
  test-suite :: SingleSource/UnitTests/longjmp-zero.test
-- lit rc=0
PASS: test-suite :: SingleSource/UnitTests/longjmp-zero.test (1 of 1)
  Passed: 1 (100.00%)
== unfixed Os: collected tests matching longjmp:
  test-suite :: SingleSource/UnitTests/longjmp-zero.test
-- lit rc=1
FAIL: test-suite :: SingleSource/UnitTests/longjmp-zero.test (1 of 1)
longjmp(env, 0): setjmp returned 0, expected 1
Failed Tests (1):
  Failed: 1 (100.00%)
== fixed Os: collected tests matching longjmp:
  test-suite :: SingleSource/UnitTests/longjmp-zero.test
-- lit rc=0
PASS: test-suite :: SingleSource/UnitTests/longjmp-zero.test (1 of 1)
  Passed: 1 (100.00%)
== unfixed Oz: collected tests matching longjmp:
  test-suite :: SingleSource/UnitTests/longjmp-zero.test
-- lit rc=1
FAIL: test-suite :: SingleSource/UnitTests/longjmp-zero.test (1 of 1)
longjmp(env, 0): setjmp returned 0, expected 1
Failed Tests (1):
  Failed: 1 (100.00%)
== fixed Oz: collected tests matching longjmp:
  test-suite :: SingleSource/UnitTests/longjmp-zero.test
-- lit rc=0
PASS: test-suite :: SingleSource/UnitTests/longjmp-zero.test (1 of 1)
  Passed: 1 (100.00%)
```

PASS (fails unfixed and passes fixed at all five levels; each level was configured, built and run on its own). Not measured: `-O1`, 65C02 (`-mcpu=mos65c02`), and any non-`sim` platform; size/cycle effects of the `setjmp.S` change (a correctness fix; no size or cycle claim is made).

## 6. Narrowed #450 diff

```
$ git diff --stat origin/main...fix-longjmp-zero
 mos-platform/common/c/setjmp.S | 10 ++++++++--
 1 file changed, 8 insertions(+), 2 deletions(-)
$ git rev-list --count origin/main..fix-longjmp-zero
1
$ python3 /home/will/llvm-mos-65816/dev/check-comment-history.py   # with the change staged
Comment history: PASS
```

The `git am` of the exported `sdk-450-narrowed.patch` onto `3f6968bbc156` in a scratch clone applied cleanly and touched exactly `mos-platform/common/c/setjmp.S` (1 file, 8 insertions, 2 deletions). Test-suite side: `git diff --stat origin/main...longjmp-zero` = 2 files, 36 insertions (`longjmp-zero.c`, `longjmp-zero.reference_output`); `check-comment-history.py` on that staged change also printed `Comment history: PASS`.

The kept comment ("Return the supplied value, mapping zero to one as required by longjmp." plus the POSIX citation) describes the current contract, not history.

PASS.

## 7. Live-state check (read-only `gh`, 2026-10-09)

```
$ gh pr view 450 --repo llvm-mos/llvm-mos-sdk --json headRefOid,reviewDecision,state,comments,reviews
(summary of the `--jq` output) head 0f8ad11589f556daa8b4c02707c53a17db1cadb0, reviewDecision CHANGES_REQUESTED, state OPEN, 0 issue comments,
1 review by mysterymath at 2026-10-05T17:41:27Z (CHANGES_REQUESTED), head repository wbniv/llvm-mos-sdk, branch fix-longjmp-zero
```

The live PR body equals `docs/pr-preparations/2026-09-20/sdk-longjmp-zero-body.md` except for one trailing blank line. No open or closed PR in `llvm-mos/llvm-test-suite` matches "longjmp" (`gh pr list --state all --search longjmp` returned `[]`). Re-run this check immediately before posting; the user edits artifacts between turns.

PASS (matches the plan's record).

## Step 8 and unverified items

- Step 8 (tracker docs, `task todo:lint`): not done, out of scope for this task (tracker docs and `TODO.md` untouched).
- Unmeasured: `-O1`; 65C02; any platform other than `sim`; the harness run of the existing `WhileLoop.c` (its directory is disabled, so it was run by hand only); a test-suite CI run of the new test.
- The reference file is REQUIRED, which contradicts the plan's "no `.reference_output` needed". With `traditional_output = True` (set by `SingleSource/lit.local.cfg`) the harness does not fail a test on a nonzero exit status by itself; it appends `exit N` to the captured output and `fpcmp`s that against `<name>.reference_output`. Re-run at `-Os` with the file removed (`~/tmp/ts-builds/noref-results.txt`, `-Os`, configure log says "No reference output found for test longjmp-zero"): the unfixed SDK PASSES (lit rc=0) and so does the fixed one, i.e. the test cannot detect the bug. With the one-line file (`exit 0`) the unfixed SDK fails and the fixed one passes (section 5). The file was restored afterwards; the committed test includes it.

```
== unfixed Os: collected tests matching longjmp:
  test-suite :: SingleSource/UnitTests/longjmp-zero.test
-- lit rc=0
PASS: test-suite :: SingleSource/UnitTests/longjmp-zero.test (1 of 1)
  Passed: 1 (100.00%)
1
== fixed Os: collected tests matching longjmp:
  test-suite :: SingleSource/UnitTests/longjmp-zero.test
-- lit rc=0
PASS: test-suite :: SingleSource/UnitTests/longjmp-zero.test (1 of 1)
  Passed: 1 (100.00%)
1
```

- Disk: the host volume was at 99-100% during this work (4.4 GB free at the end); the scratch trees under `~/tmp/sdk450` (about 1 GB) and `~/tmp/ts-builds` (about 0.2 GB) and the 2.5 GB `~/tmp/llvm-test-suite` clone are left in place until the user posts.

## Posting commands: USER-TRIGGERED, NOT RUN

Nothing below has been executed. Before any of it, re-run the step 7 read-only check. Order matters: the SDK body and the reply link to the test-suite PR, and the test-suite PR cites #450, so the test-suite PR is opened between the SDK push and the SDK body edit. Drafts use the placeholder `TEST_SUITE_PR_URL`, which the `sed` below fills in.

```
D=/home/will/llvm-mos-65816/docs/pr-preparations/2026-10-09

# 1. Replace the SDK PR branch with the single narrowed commit (force-push; lease pinned to the reviewed head)
cd ~/tmp/sdk450/sdk-fixed
git remote add wbniv git@github.com:wbniv/llvm-mos-sdk.git      # skip if it already exists
git push --force-with-lease=fix-longjmp-zero:0f8ad11589f556daa8b4c02707c53a17db1cadb0 wbniv fix-longjmp-zero

# 2. Fork the test suite and open its PR (it cites #450)
gh repo fork llvm-mos/llvm-test-suite --clone=false
cd ~/tmp/llvm-test-suite
git remote add wbniv git@github.com:wbniv/llvm-test-suite.git   # skip if it already exists
git push wbniv longjmp-zero
TS_URL=$(gh pr create --repo llvm-mos/llvm-test-suite --base main --head wbniv:longjmp-zero \
  --title "$(cat $D/test-suite-pr-title.txt)" --body-file $D/test-suite-pr-body.md)

# 3. Rewrite the SDK PR body, then reply to the review
sed "s|TEST_SUITE_PR_URL|$TS_URL|" $D/sdk-450-narrowed-body.md > ~/tmp/sdk450/sdk-450-body.final.md
gh pr edit 450 --repo llvm-mos/llvm-mos-sdk --body-file ~/tmp/sdk450/sdk-450-body.final.md
sed "s|TEST_SUITE_PR_URL|$TS_URL|" $D/review-reply.md > ~/tmp/sdk450/review-reply.final.md
gh pr comment 450 --repo llvm-mos/llvm-mos-sdk --body-file ~/tmp/sdk450/review-reply.final.md
```

The `wbniv` fork of `llvm-mos-sdk` already exists (it is the head repository of #450). `llvm-test-suite` has no `wbniv` fork yet (step 2 creates it). Per `AGENTS.md` the PR body files keep one physical line per prose paragraph; the test-suite body has a table, which is a structural Markdown element and keeps its newlines.
