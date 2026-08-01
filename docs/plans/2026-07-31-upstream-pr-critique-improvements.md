# Upstream PR critique improvements — #577 / #578 / #579 / #584

**Date:** 2026-07-31 · **Status:** ✅ complete (all improvements landed, PRs updated) · **Owner:** this session (T5, inline)

## Context

A critique pass over the four open upstream PRs
([#577](https://github.com/llvm-mos/llvm-mos/pull/577),
[#578](https://github.com/llvm-mos/llvm-mos/pull/578),
[#579](https://github.com/llvm-mos/llvm-mos/pull/579),
[#584](https://github.com/llvm-mos/llvm-mos/pull/584)) surfaced concrete improvements. This plan
implements **all of them** and pushes the updated branches + bodies. None of the four PRs had any
review activity, so amending/adding commits and editing bodies was safe (no reviewer state to
preserve); each code-updated PR got a short comment noting the update.

Survey facts that shaped the plan:

- PR **#584**'s branch already carried a second commit `7eedb14` ("invalidate aliased GPR tracking
  in the non-GPR LDImm guard") — the defensive form matching `vendor/` — so the fork/PR divergence
  from the critique was already resolved *in code*; the PR **body** still argued the opposite
  ("nothing to invalidate") and needed re-syncing.
- The 578 CRC miscompile is **not reducible to a small standalone test**: the reduction
  ([investigation](../investigations/2026-06-25-default8-65816-loopfold-miscompile.md), spike
  `docs/plans/spikes/2026-06-25-loopfold-min.c`) showed four simultaneous pressure sources are all
  required — ablating any one makes it vanish. So the critique's "end-to-end CRC lit test" idea is
  **infeasible in-tree**; the body instead states why, and a no-pessimization test is added.
- Csmith "54/60": the 6 non-passes were **benign harness skips** (`corpus_result GC'd`), 0
  mismatch/crash/error; a later extended run reached **142/160 total, 0 mismatch**
  ([validation doc](../investigations/2026-06-26-coalesce-rotate-ac-fix-validation.md)).
- PR branches: `wbniv:mos-scmp-ucmp-legalize` (was `e54ef47`, base `8be0546`),
  `wbniv:mos-coalesce-rotate-ac` (was `1824492`, base `8be0546`),
  `wbniv:mos-late-opt-nongpr-ldimm` (was `7eedb14`, base `8b616af`),
  `wbniv:mos-dwarf-65816-test-docs` (`be45bd4`). Local clone `~/llvm-mos` (origin =
  `wbniv/llvm-mos`) is the mint/edit checkout.
- Validation build: one-off **MOS-only host build** (`~/llvm-mos/build-pr`, Release + asserts,
  g++, `-j6` — the /tmp tmpfs pins ~15 GB of RAM) building
  `llc FileCheck not count split-file` (+ `llvm-config llvm-readobj` for lit); lit run per touched
  test on each branch before its push. Branch switches rebuilt incrementally (11 ninja edges).

**Mockups:** no visible surface — compiler codegen tests and PR prose only.

## Improvements (the contract)

### PR #577 — G_SCMP/G_UCMP legalization
- ~~**I1** Strengthen `llvm/test/CodeGen/MOS/scmp-ucmp.ll`: the current checks pin only `rts` per
  function, which would stay green if lowering degraded to a libcall. Add `CHECK-NOT: jsr`
  between each label and its `rts` (validated against real `llc` output first) and an s32-result
  case.~~ **Done** — validated zero `jsr` at every width (s64 operands included) on both the
  green-side preview llc and the branch build; new `scmp_i32_i16` function; amended into the
  branch's single commit `67020e2`. Evidence: V1.

### PR #578 — rotate/Ac coalescing guard
- ~~**I2** Add a no-pessimization codegen test: a common straight-line shift chain still emits the
  tight `asl`/`rol` sequence with **no extra transfers**, pinning that the guard's kept COPY folds
  away in the common case. CHECKs generated from real `llc` output.~~ **Done** —
  `coalesce-rotate-ac-no-pessimize.ll` (`shl2_u8` = `asl;asl`, `shl2_u16` = interleaved
  `asl`/`rol zp` pair, both byte-identical to unguarded output); amended into `edc9bbd`.
  Evidence: V2.
- ~~**I3** Body rewrite: (a) root-cause honesty section; (b) Csmith accounting; (c) drop the
  drifted embedded patch; (d) why no end-to-end miscompile test.~~ **Done** — body v2 posted (new
  "What this fixes — and what it deliberately doesn't" section; Csmith 54-of-54-verdicts +
  142/160 extended; embedded listing dropped; four-way-pressure explanation under Tests).
  Evidence: V4.
- ~~**I4** Draft the companion issue (RA-level: `Ac`-pinned loop-carried value mis-allocation),
  queue ready-to-post, do NOT post.~~ **Done** —
  [upstream-coalesce-rotate-ac-ra-issue.md](../upstream-coalesce-rotate-ac-ra-issue.md) (analysis,
  reachability argument, three candidate directions, exact `gh issue create` command); status-doc
  row 16, gated on a maintainer response to #578.

### PR #584 — mos-late-opt non-GPR LDImm crash
- ~~**I5** Harden the sibling `TA` handler (same switch-then-unconditional-store shape; unreachable
  today, so guard + fall-through to generic invalidation, defensive comment, no test possible).~~
  **Done** — new commit `3ce98fe` on the branch; all four late-opt tests green. Evidence: V3.
- ~~**I6** Body re-sync: show the shipped defensive-invalidation Fix, soften the "always a hard
  crash" overclaim, compress alternatives to one line each, mention the TA hardening.~~ **Done** —
  body v2 posted. Evidence: V4.

### PR #579 — .elf companion doc
- ~~**I7** Body edit only: drop the removed-test paragraph; add a venue-flexibility line.~~
  **Done** — body edited (first of the four, before the build finished). Evidence: V4.

### Bookkeeping
- ~~**I8** Same-commit doc currency: mirror new bodies into local drafts; add the #584 row +
  refresh heads in the status doc; commit plan + TODO + status doc + drafts together.~~ **Done** —
  [upstream-scmp-ucmp-pr.md](../upstream-scmp-ucmp-pr.md) (test paragraph),
  [upstream-coalesce-rotate-ac-pr.md](../upstream-coalesce-rotate-ac-pr.md) (full v2),
  new [upstream-late-opt-nongpr-ldimm-pr.md](../upstream-late-opt-nongpr-ldimm-pr.md) (first
  mirror for #584); status doc: new dated header entry, rows 15 (#584) + 16 (RA companion),
  refreshed heads on rows 5/9 and the TL;DR. Committed together (V5).

## Non-goals

- **No vendor/0002 mirroring of the TA hardening** — defensive-only and unreachable in the fork
  today; self-resolves when upstream merges and the vendor pin bumps. (Deliberate small
  upstream-ahead-of-fork divergence, noted so the rebase plan isn't surprised.)
- **No rebase** of the PR branches onto upstream tip (`1f334fe`) — bases are clean, no conflicts,
  and a rebase would churn review diffs for no benefit.
- **Not posting** the companion issue (I4) — queued ready-to-post per standing policy.
- **PR #579 stays a code comment** — relocating to the wiki is the maintainer's call; the body
  offers it.

## Verification

1. **577 lit green with strengthened checks** — on the updated `mos-scmp-ucmp-legalize`:
   `build-pr/bin/llvm-lit -v llvm/test/CodeGen/MOS/scmp-ucmp.ll` → PASS, and the raw `llc` output
   for every function contains no `jsr`.

    ```
    $ build-pr/bin/llc -verify-machineinstrs < llvm/test/CodeGen/MOS/scmp-ucmp.ll | grep -c jsr
    0
    $ build-pr/bin/llvm-lit -v llvm/test/CodeGen/MOS/scmp-ucmp.ll
    Total Discovered Tests: 1
      Passed: 1 (100.00%)
    ```
    **PASS** — pushed as amended single commit `e54ef47…` → `67020e21c32c`.

2. **578 lit green incl. the new no-pessimization test** — lit over both tests → PASS; raw `llc`
   evidence that the common shapes carry no extra transfers.

    ```
    $ build-pr/bin/llvm-lit -v coalesce-rotate-ac.mir coalesce-rotate-ac-no-pessimize.ll
    Total Discovered Tests: 2
      Passed: 2 (100.00%)
    $ build-pr/bin/llc -mtriple=mos -mcpu=mosw65816 -verify-machineinstrs < …no-pessimize.ll
    shl2_u8:  asl / asl / rts
    shl2_u16: stx __rc2 / asl / rol __rc2 / asl / rol __rc2 / ldx __rc2 / rts
    ```
    Byte-identical to the unguarded baseline (previewed on `build/upstream-llc` before the branch
    build confirmed it). **PASS** — pushed as amended commit `1824492…` → `edc9bbd23b71`.

3. **584 lit green with TA hardening** — lit over all four `late-opt*.mir` tests → PASS.

    ```
    $ build-pr/bin/llvm-lit -v late-opt.mir late-opt-65c02.mir late-opt-65816.mir late-opt-spc700.mir
    Total Discovered Tests: 4
      Passed: 4 (100.00%)
    ```
    **PASS** — pushed as new commit `7eedb14…` → `3ce98fed82de` (fast-forward, no history rewrite).

4. **PRs updated** — heads match local tips; bodies contain key new content; comments posted.

    ```
    577 head=67020e21c32c  578 head=edc9bbd23b71  584 head=3ce98fed82de  579 head=be45bd41c300
    local: 577=67020e21c32c 578=edc9bbd23b71 584=3ce98fed82de            (exact match)
    body greps: 577 "CHECK-NOT"=1 · 578 "deliberately doesn|142/160"=2 ·
                584 "Invalidate any tracked GPR"=1 · 579 "was removed"=0 (paragraph gone)
    ```
    Update comments:
    [577](https://github.com/llvm-mos/llvm-mos/pull/577#issuecomment-5149512546) ·
    [578](https://github.com/llvm-mos/llvm-mos/pull/578#issuecomment-5149512605) ·
    [584](https://github.com/llvm-mos/llvm-mos/pull/584#issuecomment-5149512652). **PASS**

5. **Bookkeeping committed** — status doc has the #584 + RA-companion rows and refreshed heads;
   local drafts match the posted bodies; todo-lint clean; the commit contains exactly this
   session's files (staged set verified via `git diff --cached --name-only` before committing —
   see the commit itself for the final evidence).
