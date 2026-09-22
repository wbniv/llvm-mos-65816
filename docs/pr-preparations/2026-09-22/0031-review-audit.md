# Patch 0031: independent submission review

Reviewed September 22, 2026 against the saved **0030-only** baseline.
Scope: the newly enabled destination-reuse path, clobber and liveness handling,
the regression tests, and the generated-code evidence.

**Verdict:** no correctness defect found. Keep the implementation and the five
regression cases. The [PR description](../../upstream-copy-phys-reg-reuse-dst-pr.md)
and [preview](0031-pr-preview.html) now use the corrected evidence below.
Submission remains dependent on the preceding liveness fix; nothing was
posted upstream by this review.

## Findings and corrections

- **P2 — suite evidence did not support the reported clean run.** The saved
  `lit-mos-0031.json` contains 84 passes, one unsupported test, one CodeGen
  failure against the old `copy-phys-reg.mir` expectation, and 46 MC failures
  from missing tools. The later MC run passes, but it does not resolve the
  CodeGen result. A fresh suite run with the exact submitted expectations now
  passes **85 CodeGen tests, one unsupported, and all 46 MC tests**.
- **P2 — size and instruction claims were overstated.** Of the 374 changed
  pairs that assemble, **352 shrink, 16 retain their size, and six grow**;
  “368 shrink” was incorrect. A count of emitted assembly instructions does
  not establish how many instructions execute or how many cycles they take.
  The description now states the measured static count and the six size
  increases. The original reproducer loses one load at `-O1` and two at
  `-O2/-O3/-Os/-Oz`, not three to six assembly lines.
- **P2 — the PR draft included local platform details outside the requested
  submission scope.** The emulator result belongs in the internal integration
  record. It is not an isolated upstream runtime comparison of these two
  patches. The public-facing description now presents the plain MOS evidence.
- The corpus accounting now includes all **4,170 comparisons**: 3,655
  successful identical pairs, 435 differing pairs, and 80 failures on both
  sides. All 61 pairs rejected during assembly fail on both sides; examples
  involve globals named `a`, `c`, `s`, `x` and `y` (and case variants), not only `s`.

No source or patch changes were needed. The PR attribution includes Claude
Code CLI `2.1.278`, `claude-fable-5-1`, `high`, and the independent Codex review
using CLI `0.155.1`, `gpt-6-astra`, `xhigh`. Codex's version/model/effort were
checked against this session's metadata; Claude's values are the supplied
review attribution.

## Implementation reasoning

During the backward scan, `Clobbered` must describe instructions strictly
after the candidate copy. Recording the candidate's own destination first
makes every destination look unavailable. Moving that recording after the
copy checks makes the destination path reachable while preserving checks for
intervening definitions, aliases, and register masks.

The original source-reuse path still requires an unclobbered register of the
requested class. If the wanted value is redefined without a usable source,
the search stops. The register classes and target-copy opcodes used by this
helper do not make the establishing copy overwrite its selected source.
Scanning remains within one basic block.

Reusing a destination extends its lifetime from that definition. Clearing its
`dead` flag is necessary; 0030's kill-clearing walk repairs any intervening
last-use markers. The destination is an exact physical register operand of
the establishing copy, so `clearRegisterDeads(Reg)` targets that definition.
The review probe with an unrelated dead NZ definition confirms that flag is
preserved. No new register-allocation choices are made in the helper, although
the longer live range can change a later scavenger choice.

## Focused and suite results

Both backends have assertions enabled. All five 0031 inputs pass the verifier
on both. The three positive reuse cases fail FileCheck on 0030 alone and pass
with 0031; both clobber controls pass either way. All six 0030 cases continue
to pass on both backends.

Six additional review probes also pass:

| Probe | Required result with 0031 |
| --- | --- |
| Destination subregister redefined | Reload saved value; do not reuse destination |
| Source subregister redefined | Reload current source; do not use earlier value |
| Call clobbers destination, preserves source | Reload source after call |
| Overlapping subregister kill | Reuse destination and clear the overlapping kill |
| Destination reused twice | Reuse it twice and clear its intervening kill |
| Establishing copy has dead A and unrelated dead NZ | Clear A's dead flag; retain NZ's |

These probes are investigation artifacts, not extra cases claimed in the
submitted lit test. The suite uses a fresh pinned test tree with exactly 0030
and 0031 applied. CodeGen passes 85 tests with the existing unsupported
`getchar-regression.ll`; MC passes all 46. No non-MOS suite was run for this
MOS-only change.

## Corpus and generated code

The recorded corpus attempted 1,656 files. Clang accepts 1,390 at each level:

| Result | `-O0` | `-O2` | `-Os` | Total |
| --- | ---: | ---: | ---: | ---: |
| Both succeed, identical assembly | 1,033 | 1,310 | 1,312 | 3,655 |
| Both succeed, different assembly | 331 | 51 | 53 | 435 |
| Both fail | 26 | 29 | 25 | 80 |
| Backend comparisons | 1,390 | 1,390 | 1,390 | 4,170 |

This audit rehashed the saved outputs of all 4,090 successful pairs. It then
reassembled all 435 differing pairs independently. Both sides assemble for
374 pairs; their summed `.text` is **1,364,382 → 1,361,852 bytes**, a net
**2,530-byte reduction**. The 352/16/6 shrink/equal/grow split and each recorded
size are reproduced. The 61 pairs that fail to assemble are excluded; full
assembler diagnostics are retained by this audit.

The six size increases are `920506-1`, `pr69691`, `20040409-1`, `20040409-1w`,
`20040409-3w`, and `20040409-3`, all at `-O0`. Their diffs show different X/Y
scavenging followed by an immediate load in place of `inx` or `dex`; one
immediate load is one byte longer. The increases range from one to four bytes.
These are small size regressions in an optimization with a net corpus saving,
not correctness failures.

Replaying those six pairs from C and the largest saving at each optimization
level reproduces all nine saved baseline/candidate assembly hashes. The
original reproducer also verifies on both backends at all six levels: its
assembly is identical at `-O0`, with one load removed at `-O1` and two at the
other four levels. The complete C-to-assembly corpus was not rerun.

Across the 435 changed files, counting emitted instruction lines gives
**1,824 fewer static instructions**, with no file-level increase. Neither
dynamic instruction counts nor cycle counts were measured. The completed
local emulator log reports **79/79 pass, zero xfail**; its compiler includes
the local patch stack, so it remains separate integration evidence.

## Exact artifacts

Pinned base: `742d554bf08042b8df93d791c335260fadd16643`.
Patch 0031 SHA-256:
`75e32cb2372214b87535ef9256b21ac57556388d520ea8a47f8272c66dc33374`.
Applying 0030 then 0031 reproduces all four relevant source/test files in the
candidate source tree byte-for-byte.

- Baseline `build/0030-claude-review/llc-0030-only`:
  `72b2ebb80c9dc2ecda60402f7544a26606d711d974bab4b849932d39e8d168e1`.
- Candidate frozen as `build/0031-review-audit/llc-0031`:
  `7c5932ad3b1ffe4c933dcfc09c0a49e13e9e5428f9d23f8cbc5c2f259482a2b2`.

Under `build/0031-review-audit/`: `audit.py` / `audit.json` record exact source
hashes and the eleven bundled cases; `probes.py` / `probes.json` cover the six
extra cases; `suite.py` / `lit-0031.json` / `lit-0031.log` record the clean
suite run; `corpus.py` / `corpus-audit.json` and `objects/` record assembly
hashes, sizes and failures; `replay.py` / `replay.json` plus generated `.ll`
and `.s` files record the fresh C comparisons. The local runtime log remains
`build/0030-claude-review/corpus-a16.log`.
