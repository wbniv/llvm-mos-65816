# Validation of the proposed revisions

Validated locally on Linux with a Release LLVM build, assertions enabled, and the MOS target. Each branch was built on its existing PR base. No GitHub CI run was triggered, because nothing was pushed. All six proposed branches merge cleanly with upstream `main` at `1d4ea13ca0ac` (checked with `git merge-tree`); the merge results were not separately built.

| PR | Result |
| --- | --- |
| #578 | CodeGen/MOS at `b4749221bf37`: **80 pass**, 1 upstream-disabled test. New regression fails without the fix and passes with it. Reconstructed SNES demo changes from CRC mismatch to host/bsnes agreement. |
| #584 | CodeGen/MOS: **79 pass**, 1 upstream-disabled test, including SPC700 non-GPR LDImm and GPR-folding coverage. |
| #586 | MC/MOS: **40 pass**, including the new BRK disassembly and round-trip checks. |
| #588 | MC/MOS: **40 pass**, including revised COP and assembler-error checks. |
| #589 | CodeGen/MOS: **80 passing tests in the final revision**, 1 upstream-disabled test. The full run passed 79 and exposed one incorrect expected register transfer in the new test; after correcting that expectation, both new tests passed on focused rerun. |
| #590 | CodeGen/MOS: **79 pass**, 1 upstream-disabled test. **20/20 separate compiler runs** produce identical, nonempty assembly. [Hash evidence](590-determinism.txt). |

The disabled test is `getchar-regression.ll`, disabled by its upstream `UNSUPPORTED` directive. Missing-tool discovery notices from lit did not prevent any selected test from executing; every required tool for the selected suites was built.

## #578: diagnosis and independent runtime check

The reconstructed input is the historical loop-fold C reproducer at `docs/plans/spikes/2026-06-25-loopfold-min.c`, with `zoom.h` and the pyramid generator recovered from commit `730e809^`. The matrix CRC fold was restored to its loop form. The current local clang produced LLVM IR; the branch-built llc compiled that same IR before and after the fix, and the local SNES SDK linked each resulting object.

[Pass evidence](578-pass-evidence.txt) shows that virtual-register rewriting emits `A = COPY Y` at the loop header. MOSCopyOpt forwards it away, but its single post-order liveness update leaves A absent from the latch live-ins. Later lowering consequently uses A as scratch for the sign test. The replacement uses LLVM's existing fixed-point liveness helper before dead-copy cleanup. The original coalescing guard is completely removed.

The 51-line MIR test in [the complete diff](578-complete.patch) checks the latch's live-in A and the absence of the bad A reload through copy optimization, pseudo expansion, and late optimization. Both assertions fail on the compiler without the fix and pass on the revised branch.

The emulator runs used the same scripted input: `R:30,A:10,SELECT:4,R:50,NONE:120`, 200 emulated frames, and host replay of the 64 captured input samples (all 64 nonzero; 3 level swaps).

- [Before](578-runtime-red.txt): host `0x7F81`, ROM `0xC57C` — mismatch.
- [After](578-runtime-green.txt): host and ROM both `0x7F81` — pass.

These are this reconstruction's measured values; they are not the older June report's CRC values. The reduced MIR regression needs no emulator or SNES SDK.

## Local commits

| PR | Submitted head | Proposed head |
| --- | --- | --- |
| #578 | `edc9bbd23b71` | `b4749221bf37` (was `c4fd3dfa74e7` before the review follow-up; `019af10c7378` briefly, reverted) |
| #584 | `3ce98fed82de` | `7f4c37de6219` (was `2d60650cfce2` before the review follow-up) |
| #586 | `064d33fc43ca` | `a2f81a87b01c` |
| #588 | `3ac109760642` | `fb1b4ba325a8` |
| #589 | `8c8d28b0c35a` | `9aead7afaa4a` |
| #590 | `cc9f0d027813` | `532900273ba9` |

## Review follow-up (2026‑09‑13, after [review.md](review.md))

The #578 and #584 follow-up commits were amended in place; the other four branches are unchanged.

- **#578** compiler code is **unchanged from Codex's `c4fd3dfa74e7`**. A first follow-up (`019af10c7378`)
  collapsed the per-block live-in recompute into one `fullyRecomputeLiveIns` after the erase loop; Codex
  questioned it with a cross-block case and the counterexample holds: with a dead `$y = COPY $x` in a
  successor and `$x = COPY $a` in the predecessor (forwarding blocked by a clobber of `$a`), the collapsed
  form left `dead $x = COPY killed $a` behind, because the predecessor's dead flags were computed against
  the successor's stale live-ins. The per-block recompute is same-pass propagation, not tightening. It was
  reverted (2026‑09‑14) and the case added as `copy-opt-chain.mir`, which passes on Codex's form. Test-only
  delta vs Codex: that new test plus an explicit `BRA %bb.3` in `copy-opt-loop.mir`. Re-validated on a
  rebuilt llc: chain test and both `copy-opt-loop.mir` prefixes pass; CodeGen/MOS **80 pass**, 1
  unsupported; all **176** `-O2` corpus outputs from `examples/65816/*.c` (IR from the fork's clang, two
  feature variants each) are **byte-identical** to the `c4fd3dfa74e7` build, as expected for a test-only
  change. Codex's bsnes runtime result therefore stands unchanged.
- **#584** whitespace-only in `MOSLateOptimization.cpp` (a stray blank line removed) and the test
  header shortened; the autogenerated-checks NOTE is dropped. CodeGen/MOS **79 pass**, 1 unsupported on
  a rebuilt llc.
- Bodies: #578 states the defect is confined to the target pass, #586 cites ca65 prior art, #589's
  validation line no longer narrates test-writing history.

`index.html` is generated from the current bundle by `render.py`, including current proposed heads, descriptions, diffs, and this validation record.

The submitted remote branches were read but never updated. `heads.json` records their full hashes for checking before any later approved push. Local compiler worktrees are under `/tmp/llvm-mos-review*`; the mail-formatted `*-commits.patch` files preserve the follow-up commits in this review directory.

## Three-block regression follow-up (2026-09-14)

Extended `copy-opt-chain.mir` with a three-block chain whose intervening register clobbers prevent copy forwarding from bypassing it. MIR checks require all three copies to disappear. An additional assembly check requires only `lda #5`, `ldx #6`, and `rts`, with no intervening or trailing instructions.

Local compiler commit `b4749221bf3735ad1c83d80c103054f745f8c8cd` adds only this test extension to `3c04e895e167`. Focused lit validation: `copy-opt-chain.mir`, `copy-opt-loop.mir`, and `copy-opt.mir` all pass (3/3), including machine verification and the final-assembly check. The runtime results above predate this test-only extension; the full suite was subsequently rerun at this head as recorded below. The saved #578 patches and proposed head include it; publication remains pending Will’s review.

## Publication-head verification (2026-09-14)

- [x] Fast-forwarded `review-578` in `/tmp/llvm-mos-review-578` to `b4749221bf3735ad1c83d80c103054f745f8c8cd`, matching `heads.json` and the saved commit patches.
- [x] Ran the full CodeGen/MOS lit suite from the checkout at that head using `/tmp/llvm-mos-review-build/bin/llvm-lit`: **80 pass, 1 unsupported**, including the three-block MIR and assembly checks. [Current lit results](578-tests.json). The compiler source is unchanged from the rebuilt `3c04e895e167` head; the extension changes only a test.
- [x] Regenerated `index.html` from the current bundle and refreshed `SHA256SUMS` with the included `render.py`.

No additional corpus or emulator run was performed for this test-only extension. No upstream branches or descriptions were posted. The proposed commits descend from the recorded submitted heads, so publication can use a normal fast-forward push if those remote heads are still unchanged.

### Pre-publish review of `b4749221bf37` (2026‑09‑14, Claude)

Independent re-verification on a fresh rebuild of `llc` at the publication head, in the shared review tree:

- **Green:** `copy-opt-chain.mir` (two-block MIR, three-block MIR, three-block ASM) and `copy-opt-loop.mir` (both prefixes) pass; full CodeGen/MOS suite **80 pass, 1 unsupported**.
- **Red, done properly this time:** `MOSCopyOpt.cpp` reverted to the submitted head `edc9bbd23b71` and `llc` rebuilt.
  `copy-opt-loop.mir` **fails on both prefixes** without the fix (the `bb.3` live-in `$a` is absent; the bad `dead $a = LDImag8 $rc2` reload is emitted). That is the regression test for the #578 defect.
  `copy-opt-chain.mir` **passes on the pre-fix compiler too**, on all three checks. This is correct and expected, not a gap: the chain tests guard the per-block `computeAndAddLiveIns` inside the cleanup loop against being removed (the refactor that was tried and reverted on 2026‑09‑14), and the pre-fix code already contained that recompute. They are a structural guard, not a red/green proof of the fix. The PR body's wording ("pins ... so the per-block recompute cannot be dropped by accident") already describes them that way; the body's "both checks fail without the fix" sentence refers only to the loop test, which is accurate.
- Live PR thread re-read: no comments since mysterymath's 2026‑08‑22 "papering over a bug elsewhere" objection, which the rediagnosis in the revised body answers directly. Remote branch head unchanged at `edc9bbd23b71`.
- **Compile-time cost of the fixed-point recompute: not measurable in practice.** Two `llc` binaries differing only in the `MOSCopyOpt.cpp` hunk, 176 corpus files at `-O2`, retired user-space instructions via `perf stat` (read inside a `--privileged` container; chosen over wall/CPU time because the host was at load average ~18 from a concurrent investigation). Corpus-wide **+0.79 %** instructions, per-file median **+0.17 %**, worst **+2.4 %** (`k_trig16`, a loop-dense kernel; +2 ms on-CPU at N=10); on-CPU time ratio 0.9989. Method and raw numbers: [plan](../../plans/2026-09-14-578-liveness-compile-time-cost.md).

## PR #590 publication (2026-09-14)

Published only #590 with Will’s approval: fast-forwarded `mos-zp-alloc-deterministic` from `cc9f0d027813` to `5e83a0784918` and applied the saved title and description. Verified the GitHub head and opened the PR in Chrome. Initial CI status: Windows and Ubuntu running, macOS queued. The other five revisions remain unpublished and each requires separate approval.

### #590 comment follow-up

Published `8f2db7c737d7fb4224015d4cf8ea2e7bf2fe5047` with Will’s approval: one comment above `SCCCallees` names all three containers requiring deterministic iteration; duplicate notes above `GlobalBenefit` and `CalleeFreqs` are removed. The diff changes comments only and passes whitespace checks. The recorded suite and determinism runs predate this comment-only follow-up; they were not rerun.

Refined the same comment in published head `532900273ba95cda6b832de005d2034e031c4eaf` to explain that allocation tie-breaking and floating-point accumulation can change zero-page placement for identical inputs. This follow-up also changes only comments.

## PR #584 publication (2026-09-14)

Published only #584 with Will’s approval: fast-forwarded `mos-late-opt-nongpr-ldimm` from `3ce98fed82de` to `7f4c37de6219` and applied the saved title and description. Verified the GitHub head and opened the PR in Chrome. Initial CI status: Ubuntu, Windows, and macOS running. PRs #588, #586, #589, and #578 remain unpublished and each requires separate approval.

## PR #588 publication (2026-09-14)

Published #588 with Will’s approval: fast-forwarded `mos-65816-cop-mnemonic` from `3ac109760642` to `fb1b4ba325a8` and applied the saved title and description. Verified the GitHub head and opened the PR in Chrome. Initial CI status: Ubuntu and Windows running, macOS queued. PRs #586, #589, and #578 remain unpublished and each requires separate approval.

## PR #578 publication (2026-09-14)

Published with Will's approval after the pre-publish review above: remote head verified unchanged at `edc9bbd23b71` immediately before the push; fast-forwarded `mos-coalesce-rotate-ac` to `b4749221bf37`; title and body set via REST PATCH (`gh pr edit` is unreliable against this repo, see #586) and verified byte-identical to `578-title.txt` / `578-body.md`. This was the last of the six; all bundle branches are now live.
