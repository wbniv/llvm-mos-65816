# #584 follow-up comment (prepared, not posted)

Status: prepared 2026‑10‑01, **not posted**. Posting is user-triggered. Re-read [#584](https://github.com/llvm-mos/llvm-mos/pull/584) live before posting; the body below is the comment text, everything above the rule is not.

Why: the third independent review of the #320 series (N17) found the same `combineLdImm` crash on current upstream `main`, where it takes down 13 of the 38 in-tree `CodeGen/MOS` `.ll` tests at `-mcpu=mosspc700 -O2`. #584 fixes exactly those and changes nothing else on any MOS CPU. The canonical record is [mos-late-opt-nongpr-ldimm](../../defects/mos-late-opt-nongpr-ldimm.json). The #320/#321 split series carries #584's net diff unchanged as its own commit, ahead of the far work.

Post with:

```bash
gh pr comment 584 --repo llvm-mos/llvm-mos --body-file <(sed '1,/^---$/d' docs/pr-preparations/2026-10-01/584-comment.md)
```

---

A data point on how often this crash is reached, measured on current `main` (`06bc967d2668`, assertions build). At `-mcpu=mosspc700 -O2`, 13 of the 38 `.ll` tests in `llvm/test/CodeGen/MOS` crash in "MOS Late Optimizations", including `fcmp.ll`, `zp-alloc.ll`, `light-spill.ll`, `shift-rotate.ll` and `vector-scalarize.ll`. So do 18 of 52 larger C-derived IR files from our corpus.

With this PR applied to the same base, all 31 of those inputs compile. Every other result is unchanged: the same 90 inputs give identical assembly and object bytes on all 14 MOS CPUs at `-O2`, and the MOS CodeGen and MC suites pass (133 tests, 1 unsupported).
