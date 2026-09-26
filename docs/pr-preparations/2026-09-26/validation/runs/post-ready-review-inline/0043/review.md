# 0043 current-main diagnostic adaptation review

Date: 2026-09-26. Reviewer: OpenAI Codex CLI 0.157.1, model
`gpt-6-astra`, `xhigh` reasoning effort. Attribution verified from this child
session's metadata, session `01a0db96-a6cd-7800-82a5-6b871eb7e177`.

## Verdict

Approve the test-only diagnostic adaptation in
`diagnostic-test-adaptation.patch`. No compiler implementation change is needed
for these checks. All twelve rejected constraints now produce a clean exit 1,
not a compiler crash; the test must use plain `not`. Constraint-specific output
checks remain exact literal diagnostics, including the distinction between
`output register` and `input reg`.

The adapted test SHA-256 is
`6e3b7549c293ba5229c1926fb9b5fb1e7c840b2b99cf07d3f0df6d2ee917a5b5`;
the test-only diff SHA-256 is
`149ea61480aa3e2528ee28e8117725101eaa19f0382ca1745182475e9d4cab7b`.
This review does not independently certify the entire compiler patch or clear
unrelated publication gates.

## Identified snapshots

Parent receipt: `build/post-ready-validation-mos/0043/receipt.json`, base
`7bd67c0ae4e8bb65a3f980912bf201df22131e34`, no prerequisites, source-patch
SHA-256 `8ffad5b5b6ac9d94dfcf2953d79327b88cba130150350419e30f6f6d9ac0aef6`.
The two independently rehashed binaries match that receipt:

- Baseline `baseline-bin/llc`:
  `f215e4d24f07a5e6720de665f5fdbda4b6b537aac021c55bbe14678f53af8331`.
- Candidate `candidate-bin/llc`:
  `0366306de01dc188a4781da9a378360cbf48769fbb7d7ac169f1784169315a69`.

The review used these immutable snapshots read-only; it did not rebuild them or
modify any shared source/build tree. Absolute source paths in baseline crash
diagnostics are build paths, not independently verified Git identity evidence.

## Results

Every split was compiled with `-mtriple=mos -mcpu=mos6502
-verify-machineinstrs` at both `-O0` and `-O2` (52 invocations total).
`results.json` retains commands, binary/input hashes, exits, and initial
diagnostics; individual stdout/stderr files retain complete output.

| Input group | Baseline | Candidate |
| --- | --- | --- |
| `wide_a`, `wide_x`, `wide_y`, `wide_R`, `wide_d` | Exit 0, no diagnostic; accepts an oversized output in an 8-bit constraint | Exit 1, exact `error: could not allocate output register for constraint '<constraint>'` |
| `named_a`, `named_x`, `named_y`, `named_rc` | Exit 0, no diagnostic; accepts an oversized named-register output | Exit 1, same output diagnostic naming `{a}`, `{x}`, `{y}`, or `{rc0}` |
| `named_rs` | SIGABRT, `LLVM ERROR: unable to translate instruction: call (in function: named_rs)` | Exit 1, output diagnostic naming `{rs0}` |
| `named_cc` | SIGABRT, `Unexpected physical register copy.` | Exit 1, output diagnostic naming `{cc}` |
| `wide_in` | SIGABRT, GlobalISel unable-to-translate diagnostic | Exit 1, exact `error: could not allocate input reg for constraint 'a'` |
| `ok` (six valid functions) | Exit 0, no diagnostics | Exit 0, no diagnostics |

The same outcomes hold at both optimization levels. Each candidate negative
stderr is exactly one diagnostic line. The nine baseline acceptance cases are
not baseline crashes: for example `wide_a` and `named_rc` emit `ldx #0` for the
high return byte, despite their 16-bit output type and 8-bit output constraint.
This establishes invalid-constraint acceptance and its lowering, not a new
runtime execution experiment or a claim that every negative input was wrong-code
instead of a crash.

All fourteen adapted RUN lines pass with candidate tools. On the baseline the
split step and positive check pass, while all twelve negative RUN lines fail.
Thus the test remains discriminating for every rejected constraint; changing
`not --crash` to `not` has not hidden the baseline behavior. The six positive
function FileCheck patterns also pass on all four baseline/candidate O0/O2
assembly outputs. `adapted-results.json` and `*-adapted-*.log` retain the exact
RUN commands and outcomes.

Reproduction scripts: `../review0043.py` for the optimization-level matrix and
`../check0043.py` for adapted RUN lines and the generated diff. The adaptation
does not edit test IR, positive checks, compiler source, or retained historical
evidence.
