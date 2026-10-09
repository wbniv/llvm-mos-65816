# #584 follow-up comment (prepared, not posted)

**Current status, October 9:** #584 merged October 5. This follow-up is superseded and should remain unposted; its measurement describes the retained pre-merge build.

OpenAI Codex 0.162.0, model `gpt-6.1-sol`, `medium` reasoning effort; verified session `01a1208b-91e0-7e33-b5bf-8787d2a9c919`.

Historical preparation status (October 1): prepared and not posted. The instructions and comment below preserve that preparation; the October 9 status above supersedes posting.

Why: the third independent review of the #320 series (N17) found the same `combineLdImm` crash on current upstream `main`, where it takes down 13 of the 38 in-tree `CodeGen/MOS` `.ll` tests at `-mcpu=mosspc700 -O2`. #584 fixes exactly those and changes nothing else on any MOS CPU. The canonical record is [mos-late-opt-nongpr-ldimm](../../defects/mos-late-opt-nongpr-ldimm.json). Filing order: #584 first. The #320/#321 split series does not carry #584 (user decision 2026‑10‑01, "sequence, don't carry"); until #584 lands, mosspc700 crashes in MOS Late Optimizations identically before and after the series. The comment below mentions neither series; it reports only the measurement on `main`.

Post with:

```bash
gh pr comment 584 --repo llvm-mos/llvm-mos --body-file <(sed '1,/^---$/d' docs/pr-preparations/2026-10-01/584-comment.md)
```

---

A data point on how often this crash is reached, measured on current `main` (`06bc967d2668`, assertions build). At `-mcpu=mosspc700 -O2`, 13 of the 38 `.ll` tests in `llvm/test/CodeGen/MOS` crash in "MOS Late Optimizations", including `fcmp.ll`, `zp-alloc.ll`, `light-spill.ll`, `shift-rotate.ll` and `vector-scalarize.ll`. So do 18 of 52 larger C-derived IR files from our corpus.

With this PR applied to the same base, all 31 of those inputs compile. Every other result is unchanged: the same 90 inputs give identical assembly and object bytes on all 14 MOS CPUs at `-O2`, and the MOS CodeGen and MC suites pass (133 tests, 1 unsupported).
