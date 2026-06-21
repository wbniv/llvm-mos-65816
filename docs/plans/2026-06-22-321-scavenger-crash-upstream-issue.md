<!-- HISTORY: snapshots in docs/plans/.history/ (regen-md-history hook). -->

# #321 register-scavenger crash — file it upstream (`saveScavengerRegister` asserts N/Z dead)

**Status:** PLANNED (2026-06-22) · **Issue:** #321, ROADMAP M2 · **Type:** upstream issue (no fork patch).
**Posting is user-triggered** — this plan drives everything up to the `gh issue create`, the post itself
(human go), and the same-turn bookkeeping after. **No codegen / `0002` change.**

## Context — what is already done

The `+mos-a16` register-scavenger crash is **fully root-caused and held**, not open work:

- **Symptom.** `+mos-a16 -O1/-Os` → `-verify-machineinstrs` rejects `PH $p` / `$rc17 = STImag8 $p`
  (*"`$p` is not a GPR register"*). Clean at `-O0` and on DEFAULT 8-bit.
- **Root cause (asserts-confirmed).** `MOSRegisterInfo::saveScavengerRegister`
  (`vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp:186-187`) opens with
  `assertNZDeadAt(MBB, I); assertNZDeadAt(MBB, UseMI);` — it **assumes N/Z are dead at every scavenging
  point** (comment: *"NZ cannot be live … virtual registers are never inserted into CmpBr instructions"*).
  A 16-bit compare/ALU keeps **N (or Z) live** across a frame-vreg spill → the `Reg == MOS::P`, unbalanced-
  `pushPullBalanced` path falls through to the illegal `STImag8 $p`. An asserts build aborts *earlier*, at
  `MOSRegisterInfo.cpp:172` (`"expected N to be free when saving scavenger register"`).
- **It is pristine UPSTREAM, not `0002`.** `grep -c 'saveScavengerRegister\|assertNZDeadAt'
  patches/llvm-mos/0002-321-accum16.patch` = **0**. `+mos-a16` only *creates* the flag-liveness/pressure
  that violates the upstream precondition.
- **Held.** 8/500 fuzz seeds (169/173/196/268/271/272/306/420), **XFAIL'd** via `tools/a16_fuzz.py`
  `KNOWN_ISSUES['scavenger-p-not-gpr']`; deterministic repro `examples/65816/a16scavnz.c`; XPASS-guarded
  (`dev/run.sh known-issues` — goes red the instant a fix lands).
- **Drafted.** Issue body `docs/321-upstream-scavenger-nz-issue.md`; full internal analysis
  `docs/investigations/65816-a16-scavenger-nz-liveness.md`; exact `gh issue create` queued at
  `docs/upstream-contribution-status.md` **item 4**. Fork-side fix verdict (2026-06-19 re-probe): **no
  narrow, low-risk fix** — `P` has no GPR spill home and `PHP`/`PLP` can't bracket it across an unbalanced
  push/pull range; the unblock is the upstream issue.

What's **missing** is the actionable file-it path: a pre-flight that the bug is still live (here *and*
upstream), the best repro we can give a maintainer, the post, and the same-turn tracking close-out. That is
this plan.

## The one real risk — upstream can't reproduce with `+mos-a16`

`+mos-a16` is **fork-only**; it does not exist on `llvm-mos/llvm-mos` main. The repro in the issue body
needs it, so a maintainer **cannot trigger the crash on a pristine build**. The investigation notes the bug
is in the *generic* scavenger path — *"in principle a sufficiently flag-heavy DEFAULT 8-bit program could
hit it too."* The single highest-value thing this plan can add to the report is a **default-8-bit repro that
reproduces on stock upstream**. So the spine is:

- **Primary:** time-boxed attempt to construct/reduce a DEFAULT 8-bit (no `+mos-a16`) repro that hits the
  same `assertNZDeadAt` abort on an upstream-equivalent build. If found → strongest possible issue.
- **Fallback (guaranteed fileable):** if none within the box, file with the **analysis** (the assert's
  premise is independently checkable from the source — the *"never inserted into CmpBr"* comment is the
  crux and is provably not general) + the **`+mos-a16` repro clearly labeled as fork-context** + the asserts
  backtrace + an offer of the pre-PEI MIR. The maintainer can reason about the precondition from the code
  alone.

## Goal / non-goals

**Goal.** File a high-quality, still-live upstream issue for the scavenger N/Z-liveness assertion, with the
most reproducible test we can produce, and wire the tracking so a future upstream fix closes the loop
automatically (the XPASS guard already fires; we add the issue URL to its ACTION message and the
`KNOWN_ISSUES` comment).

**Non-goals (explicitly out of scope — established position, do not expand).**
- **No fork-side fix and no fix PR.** The fix touches the generic scavenger contract across all MOS
  subtargets (stack-relative P restore *or* a flag-safe spill-point choice), is regression-sensitive, and is
  **maintainer territory** per the 2026-06-19 feasibility re-probe. Re-evaluate alongside the `globals.c` RA
  failure at M2 wrap-up — not here.
- **No change to `0002` / codegen.** Docs + tracking only (plus, if found, one new tracked 8-bit repro `.c`
  and its harness).

## Worktree discipline

The repro hunt + asserts builds are **investigation** → run on a throwaway worktree off `main` HEAD
(`throwaway/scavenger-upstream-repro`), never on `main`'s hot shared working copy. No `build/` there:
env-override `CLANG`/`OBJDUMP` to this checkout's `build/llvm-mos-install/bin/...` (for the asserts toolchain,
to `build/llvm-mos-asserts-install/bin/...`); host-side scripts only, no rebuild. **Keep** → merge back only
the durable artifacts (a confirmed 8-bit repro `.c` + its `dev/*.sh` harness, the finalized issue body, the
recorded asserts backtrace). **Dead-end** (no 8-bit repro) → `git worktree remove` + `git branch -D`; the
analysis-only filing needs nothing from the worktree. (Generic rule: `~/SRC/CLAUDE.md` "Worktree-based
feature workflow"; project specifics: `docs/howto-feature-worktree.md`.) Writing *this plan* and the final
doc/TODO edits happen on `main` as normal plan-first work.

## Steps

1. **Spin up the throwaway worktree.** `throwaway/scavenger-upstream-repro` off `main` HEAD; export
   `CLANG`/`OBJDUMP` to the main checkout's `build/llvm-mos-install/bin/...`.

2. **Pre-flight: bug still live HERE.** On the current vendor pin, re-confirm both faces of the crash so we
   don't file something already drifted:
   - Release build: `examples/65816/a16scavnz.c` `+mos-a16 -Os -verify-machineinstrs` still emits
     `$p is not a GPR register` (`PH $p` / `STImag8 $p`).
   - Asserts build (`dev/asserts-build.sh` → `build/llvm-mos-asserts-install`): same TU aborts at
     `MOSRegisterInfo.cpp:172` `"expected N to be free when saving scavenger register"`, in the
     `saveScavengerRegister → RegScavenger::spill → scavengeFrameVirtualRegs` stack.
   - Source: `grep -c 'saveScavengerRegister\|assertNZDeadAt' patches/llvm-mos/0002-321-accum16.patch` == 0
     (still pristine-upstream), and the assert + comment still present at
     `vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp`.
   - XPASS guard green: `dev/run.sh known-issues` → `a16scavnz.c` *"still reproduces [scavenger-p-not-gpr]"*.

3. **Pre-flight: bug still live UPSTREAM (don't file a stale issue).** The issue targets
   `llvm-mos/llvm-mos` main, which may have moved past our pin. Fetch the upstream file and confirm the bug
   site still exists there:
   ```
   gh api repos/llvm-mos/llvm-mos/contents/llvm/lib/Target/MOS/MOSRegisterInfo.cpp \
     --jq '.content' | base64 -d | grep -nA2 'saveScavengerRegister\|never inserted into CmpBr\|expected N to be free'
   ```
   - Assert + premise comment still present upstream → file. Gone/changed → **STOP**: upstream may have
     fixed it; record the upstream SHA/line, drop to the close-out path (a vendor-pin bump will trip the
     XPASS guard), and do **not** post. Note any upstream issue/PR that already covers it.

4. **Primary: attempt a DEFAULT 8-bit upstream-reproducible repro (time-boxed).** Box: a focused session
   (≈ the existing `globals.c`/cvise effort scale — cap at the project's 3-hypothesis/attempt rule before
   declaring the box spent). Strategy: heavy 8-bit flag chains (a result N/Z consumed after intervening
   work) + self-recursion + many values live across the self-call to force `scavengeFrameVirtualRegs` to
   spill where a flag is live — built **without** `+mos-a16`, `-Os`/`-O1`, on the **asserts** build so the
   precondition aborts directly (don't depend on the release verifier).
   - **Found** → cvise-reduce to a minimal `.c`; add it as `examples/65816/scavnz8.c` (+ a tiny
     `dev/scavnz8.sh` host-verify harness) — these are the durable artifacts to merge back. This becomes the
     issue's primary `## Reproduce`.
   - **Not found in the box** → record the negative result (what shapes were tried, why each missed) in the
     investigation doc and proceed with the analysis-only fallback. Do **not** over-invest: the analysis +
     a16 repro is already a fileable issue.

5. **Finalize the issue body** `docs/321-upstream-scavenger-nz-issue.md` (on `main`):
   - If Step 4 found an 8-bit repro: make it the primary `## Reproduce`; keep the `+mos-a16` variant as a
     secondary "also reproduced, more readily, with fork 16-bit-accumulator codegen" note.
   - If not: ensure the embedded C is **exactly** the confirmed-reproducing `a16scavnz.c` (reconcile the
     current `f0` in the body against `examples/65816/a16scavnz.c` — they diverge; the body must match a TU
     we have actually run), and label it clearly as needing the fork's `+mos-a16`, with the generic-path
     argument leading.
   - Verify the asserts backtrace + release-verifier excerpts match Step 2's fresh output.
   - The `## Likely fix directions` (stack-relative restore / flag-safe spill point / graceful path) already
     reflect the re-probe — leave as the maintainer-facing framing.
   - Confirm the `## Summary`/title premise sentence is the crux: the *"never inserted into CmpBr"* comment
     does not hold in general.

6. **Post (USER-TRIGGERED — do not auto-run).** On the user's go, strip the leading `<!-- STATUS … -->`
   block, then:
   ```
   gh issue create --repo llvm-mos/llvm-mos \
     --title "[MOS] Register scavenger asserts N/Z dead (saveScavengerRegister) — violated when a compare/ALU flag is live across a frame-vreg spill" \
     --body-file docs/321-upstream-scavenger-nz-issue.md
   ```
   Capture the returned **issue number + URL**.

7. **Same-turn bookkeeping after posting** (the "keep docs current in the same turn" rule):
   - `docs/upstream-contribution-status.md`: move item 4 out of *Ready to post now* to a posted state
     (record `#NNN` + URL + date); bump the TL;DR ("Open on GitHub: 0" → 1 issue) and the *Verified state*
     block.
   - `TODO.md`: the **"File the register-scavenger N/Z-liveness issue"** item → `[x]`, one-line, moved to the
     done section with the issue link (and add the `[plan]` link to *this* file).
   - `docs/investigations/65816-a16-scavenger-nz-liveness.md` + `docs/implementation-status.md` (the
     "Register-scavenger crash (`$p is not a GPR`)" row): add the upstream issue URL.
   - `tools/a16_fuzz.py`: add the issue URL to the `KNOWN_ISSUES['scavenger-p-not-gpr']` comment **and** to
     the `cmd_known_issues` ACTION message, so when the guard fires on an upstream fix the dev has the
     tracking link in front of them.

8. **Close-out trigger (already wired — just verify the linkage).** No new mechanism needed: when upstream
   fixes the assert and our vendor pin picks it up, `a16scavnz.c` verifies clean → `dev/run.sh known-issues`
   goes **XPASS** → CI red with the drop+promote ACTION (drop `KNOWN_ISSUES['scavenger-p-not-gpr']` + its
   `KNOWN_ISSUE_REPROS` row, promote `a16scavnz.c`/`scavnz8.c` to a positive gate). Confirm the ACTION
   message now carries the issue URL from Step 7.

9. **Teardown.** Merge back the durable artifacts (any `scavnz8.c` + harness, the finalized body, the
   recorded backtrace); then `git worktree remove` + `git branch -D` the throwaway. Keep `a16scavnz.c` and
   `dev/asserts-build.sh` (already tracked on `main`).

## Verification

> Plan-verification format: run each numbered step, paste raw output in a code block below it, add
> PASS/FAIL, write it back here. Steps are the spec; output is the evidence.

### Step V1 — repro still verify-crashes (release, `+mos-a16 -Os`)

```
(paste: build a16scavnz.c +mos-a16 -Os -verify-machineinstrs → expect "$p is not a GPR register" + PH $p / STImag8 $p)
```
PASS/FAIL: …

### Step V2 — asserts build aborts at the precondition

```
(paste: dev/asserts-build.sh build of a16scavnz.c +mos-a16 -Os → expect MOSRegisterInfo.cpp:172
 "expected N to be free when saving scavenger register" in saveScavengerRegister→spill→scavengeFrameVirtualRegs)
```
PASS/FAIL: …

### Step V3 — still pristine-upstream, not `0002`

```
(paste: grep -c 'saveScavengerRegister\|assertNZDeadAt' patches/llvm-mos/0002-321-accum16.patch   → expect 0)
(paste: grep -n assert vendor/.../MOSRegisterInfo.cpp                                              → assert+comment present)
```
PASS/FAIL: …

### Step V4 — bug still live on upstream HEAD

```
(paste: gh api .../MOSRegisterInfo.cpp | base64 -d | grep -nA2 'never inserted into CmpBr|expected N to be free')
```
PASS/FAIL (assert present upstream → file; absent → STOP, close-out path): …

### Step V5 — 8-bit repro outcome

```
(paste: either dev/scavnz8.sh → asserts abort at assertNZDeadAt with NO +mos-a16   [PRIMARY achieved]
        or the recorded negative result — shapes tried, why each missed           [fallback in effect])
```
PASS/FAIL (PASS = either a confirmed 8-bit repro OR a recorded negative + analysis-only body finalized): …

### Step V6 — XPASS guard green pre-file

```
(paste: dev/run.sh known-issues → "examples/65816/a16scavnz.c … still reproduces [scavenger-p-not-gpr]")
```
PASS/FAIL: …

### Step V7 — issue body posting-ready

```
(paste: head of docs/321-upstream-scavenger-nz-issue.md after the STATUS block is stripped + embedded
 repro reconciled to a confirmed-reproducing TU; title matches the gh command)
```
PASS/FAIL: …

## Risks & fallbacks

- **No 8-bit repro within the box.** Expected-plausible; the fallback (analysis + labeled a16 repro +
  backtrace + MIR offer) is a complete, fileable issue. Don't let the hunt block the filing.
- **Upstream already fixed it (Step 3/V4 STOP).** Then there's nothing to file — record the upstream
  SHA/PR, let the next vendor-pin bump trip the XPASS guard, mark the TODO item closed-by-upstream.
- **Maintainer can't repro (fork-only `+mos-a16`, no 8-bit repro).** Mitigated by the source-level argument
  (the assert premise is checkable from the code) + offer to provide pre-PEI MIR / the asserts backtrace on
  request. The issue is still valuable as a correctness report on a provably-too-strong assertion.
- **Don't auto-post.** All upstream posting is user-triggered; Step 6 is gated on the user's go.

## Pointers

- Issue body: `docs/321-upstream-scavenger-nz-issue.md`
- Investigation: `docs/investigations/65816-a16-scavenger-nz-liveness.md`
- Queue row (exact `gh`): `docs/upstream-contribution-status.md` item 4
- Repro: `examples/65816/a16scavnz.c` · Diagnostic: `dev/asserts-build.sh` · Guard: `dev/run.sh known-issues`
- Bug site: `vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp` (`saveScavengerRegister`,
  `assertNZDeadAt` @ ~159-187)
