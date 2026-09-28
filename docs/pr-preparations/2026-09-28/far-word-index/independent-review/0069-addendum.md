# Patch 0069 review addendum: FileCheck opcode boundaries

## Post-review adjudication

This addendum follows receipt of another reviewer's finding about FileCheck whitespace trimming and substring matching. It is **post-review adjudication**, not an independently discovered finding. The initial independent review remains preserved verbatim at `/tmp/far-word-review-0069.md`, SHA256 `bfffee5a01216b0232efb8ca307ec5be4f3bed2ab29feac28243ecd59029e7cf`.

**I agree with the finding.** My initial coverage suggestion 2 incorrectly says the trailing delimiters distinguish `_INDIR`, `_IDX`, and `_IDX16`. FileCheck removes those delimiters under the displayed RUN flags. This is a definite defect in the regression assertions, beyond the optional operand-coverage improvement I initially identified.

Attribution: OpenAI Codex CLI **0.158.0**, originator `codex-tui`, exact recorded model ID **`gpt-6-astra`**, reasoning effort **`xhigh`**. Metadata was rechecked in this reviewer's own session file `/home/will/.codex/sessions/2026/09/28/rollout-2026-09-28T15-43-55-01a0e72f-5a2d-7530-b114-4bfe66710323.jsonl`. Reviewer thread: `01a0e72f-5a2d-7530-b114-4bfe66710323`; agent `/root/review_0069`; session/root ID `01a0e67f-298f-7a21-80af-06f867085f84`. This is a separate AI reviewer task, not human or different-model review.

## Source confirmation

All paths below are relative to `/home/will/llvm-mos-65816`.

- `vendor/llvm-mos/llvm/test/CodeGen/MOS/far-loop-range.mir:1–3` supplies only the check prefix to FileCheck; it does not request full-line or strict whitespace matching.
- `vendor/llvm-mos/llvm/include/llvm/FileCheck/FileCheck.h:34–39` defaults both `NoCanonicalizeWhiteSpace` and `MatchFullLines` to false. The CLI defaults and request assignment agree at `llvm/utils/FileCheck/FileCheck.cpp:57–59`, `86–90`, and `796–797`.
- `vendor/llvm-mos/llvm/lib/FileCheck/FileCheck.cpp:810–812` applies `rtrim(" \t")` unless both of those options are true. The literal trailing space after each opcode is therefore discarded.
- Lines 841–845 select `FixedStr` for these patterns, which have no regex or variable pieces and do not use full-line matching.
- Lines 1132–1137 use `Buffer.find(FixedStr)`, admitting a prefix of a longer opcode.

The consequences follow directly from those string operations:

| Assertion | Effective fixed string | Also accepts |
| --- | --- | --- |
| MIR line 16: `# OFF: = G_LOAD_FAR_INDIR ` | `= G_LOAD_FAR_INDIR` | `= G_LOAD_FAR_INDIR_IDX ...` and `= G_LOAD_FAR_INDIR_IDX16 ...` |
| MIR line 12: `# A16: = G_LOAD_FAR_INDIR_IDX ` | `= G_LOAD_FAR_INDIR_IDX` | `= G_LOAD_FAR_INDIR_IDX16 ...` |
| MIR line 172: `# A16: = G_LOAD_FAR_INDIR ` | `= G_LOAD_FAR_INDIR` | Either indexed form, including a wrongly admitted fold for `offset_256` |

The same weakness affects corresponding checks throughout the file. A label limits the region searched but does not restore the lost opcode boundary. The machine verifier also does not establish that an otherwise valid indexed instruction was justified by a sound range proof.

## Revised recommendation

**P2: require exact opcode boundaries before accepting the regression coverage.** This changes the initial recommendation from acceptance with only optional coverage improvements to a request for changes to the assertions. A suitable spelling is `G_LOAD_FAR_INDIR{{[[:space:]]}}`, with the same boundary applied after `_IDX` and `_IDX16`; the regex delimiters survive pattern trimming. Explicit operand checks can then strengthen the assertions further. Adding `--strict-whitespace` alone would not fix the trimming condition, which requires both options, and is less direct than expressing the opcode boundary.

After correcting the assertions, verify that replacing a required fallback with either indexed form is rejected, and that replacing required Y8 with Y16 is rejected. Those are recommended follow-up checks; this addendum did not execute them or modify the tests.

**Source-review verdict remains: no compiler correctness defect found in 0069.** The induction, branch-role, and width-preserving range arguments in the original review are unaffected. My direct inspection of the retained output files also found the expected actual opcode spellings. Those observations establish what the inspected historical outputs contain; the successful FileCheck statuses cannot establish that these assertions reject the wrong variants. No new compiler defect or compiler-status change is claimed.

This adjudication used source reads only. No compiler tests, FileCheck process, or emulator was run, and the initial report and implementation were not edited.

## Inspected source identities

| File | SHA256 |
| --- | --- |
| `vendor/llvm-mos/llvm/lib/FileCheck/FileCheck.cpp` | `836eed0fb24f66df29a9e1513e985807ea680ec834c7b026151939b493d0dcea` |
| `vendor/llvm-mos/llvm/include/llvm/FileCheck/FileCheck.h` | `a09718ebdf8ea94af74d47e1ba8a075ef2ba4a5e34fdfe72b7d083e774fb477b` |
| `vendor/llvm-mos/llvm/utils/FileCheck/FileCheck.cpp` | `a6551484d788b8a0574a6b9a713b5eabd305133496dbe99b96041e7e88fd55ec` |
| `vendor/llvm-mos/llvm/test/CodeGen/MOS/far-loop-range.mir` | `aad0896456e28c3278022b11c6c99b3b5afd5baff058e60dd25277ceb90eb414` |
