# Upstream PR revisions for Will's review

**Upstream revisions await approval. No upstream PR branches or descriptions have been updated.** Will requested review before publication on 2026-09-13. Each row links both the incremental review changes and the complete proposed PR diff, plus the proposed description. **All local checks pass.** See the [validation record](validation.md) for suite counts, the #578 before/after runtime result, commit hashes, and test scope.

| PR | Revision | Code changes | Proposed text |
| --- | --- | --- | --- |
| [#578](https://github.com/llvm-mos/llvm-mos/pull/578) | Replace the coalescing workaround with a fix for loop liveness in MOSCopyOpt. | [Review diff](578-review-changes.patch) · [Complete diff](578-complete.patch) | [Title](578-title.txt) · [Body](578-body.md) |
| [#584](https://github.com/llvm-mos/llvm-mos/pull/584) | Filter non-GPR LDImm destinations in the existing condition; remove sibling-handler defensive code. | [Review diff](584-review-changes.patch) · [Complete diff](584-complete.patch) | [Title](584-title.txt) · [Body](584-body.md) |
| [#586](https://github.com/llvm-mos/llvm-mos/pull/586) | Prove operandless, one-byte BRK disassembly and round trips on MOS6502/W65816. | [Review diff](586-review-changes.patch) · [Complete diff](586-complete.patch) | [Title](586-title.txt) · [Body](586-body.md) |
| [#588](https://github.com/llvm-mos/llvm-mos/pull/588) | Shorten COP comments and remove redundant 65EL02-specific test framing. | [Review diff](588-review-changes.patch) · [Complete diff](588-complete.patch) | [Title](588-title.txt) · [Body](588-body.md) |
| [#589](https://github.com/llvm-mos/llvm-mos/pull/589) | Mark CmpZero as a terminator, scan terminators, and replace the invalid positive reproducer. | [Review diff](589-review-changes.patch) · [Complete diff](589-complete.patch) | [Title](589-title.txt) · [Body](589-body.md) |
| [#590](https://github.com/llvm-mos/llvm-mos/pull/590) | Keep comments focused on deterministic iteration without prescribing an exact order. | [Review diff](590-review-changes.patch) · [Complete diff](590-complete.patch) | [Title](590-title.txt) · [Body](590-body.md) |

The complete diffs are relative to each PR's merge base with upstream `main`. The `*-commits.patch` files preserve the local follow-up commits and can be applied with `git am` on the corresponding submitted head. The compiler checkouts are isolated under `/tmp/llvm-mos-review*`; this directory preserves the changes beyond those temporary checkouts.

The intended publication, after Will approves, is to update the six existing PR branches and their descriptions. No replacement PRs are needed.

**Review:** [review.md](review.md) records the independent review of these revisions and the follow-up edits it produced (the #578 and #584 heads were amended; see the [validation record](validation.md) for the re-run results). `index.html` is a rendered snapshot of the original submission and predates those edits.
