# 0064: exact upstream validation

Preparation and validation: OpenAI Codex CLI 0.157.1 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort; verified session
`01a0dd01-d72e-76f2-bf27-a796e0f7d994`.

- Destination: llvm-mos main `7bd67c0ae4e8bb65a3f980912bf201df22131e34`.
- Local commit: `155e209c4cee8eeac01397aac3542e76841a9856`.
- Branch: `mos-computed-carry-scheduling`, in
  `/home/will/llvm-mos-65816/.scratch/carry-pr/source`.
- [Standalone patch](0064-llvm-mos.patch) SHA256:
  `3ee6c4f1c8b0a64c1415b657fde7f82ef6e2499fd2d435f2241fba59a6134983`.
- Release, assertions enabled; no prerequisite candidate patches. Source and
  build copies are independently writable. Main's installed tools are unchanged.
- [Receipt](validation/runs/carry-0064-upstream/receipt.json) contains exact
  binary hashes, image identity, configuration and artifact hashes.

## Results

| Check | Baseline | Candidate |
|---|---:|---:|
| Ten regression RUNs | Five expected scheduling failures, five passes | Ten passes |
| Existing MOS CodeGen/MC suites | 131 passes, one unsupported | 131 passes, one unsupported |
| Added MIR test | Fails computed-carry ordering checks | Passes; full candidate total 132 |
| NMOS 6502 kernel text | 133 bytes; six carry materializations | 59 bytes; zero materializations |
| 512 frozen Python-oracle vectors | `P`, exit 0 | `P`, exit 0 |
| 13 ordinary fixtures × three optimizations × three CPUs | 117 verified objects | 117 identical disassemblies; zero unmatched outcomes |

Baseline top-down scheduling and all four full-lowering controls already pass.
The five failing checks are default/bottom-up 6502 and default 65C02, 65CE02,
and stock 65816. The test also verifies single chains, required overlap and a
carry with multiple users. The existing unsupported test is
`CodeGen/MOS/getchar-regression.ll`.

The baseline scheduler was explicitly rebuilt from unmodified source before
freezing `baseline/bin/llc`; the candidate was then rebuilt with only this patch.
The final formatting rebuild produces the same candidate llc hash used for
the corpus measurements. The original grouped MIR passes both builds; the
constructed interleaving is the current upstream regression witness.

## Replay and evidence

- [Regression commands and exits](validation/runs/carry-0064-upstream/focused-final/results.json),
  [exact MIR](validation/runs/carry-0064-upstream/carry-pressure-schedule.mir).
- [Baseline suite](validation/runs/carry-0064-upstream/baseline-suite.log),
  [candidate suite](validation/runs/carry-0064-upstream/final-suite.log).
- [Runtime commands](validation/runs/carry-0064-upstream/runtime/results.json),
  [runtime runner](validation/runs/carry-0064-upstream/runtime.py.txt),
  [driver](validation/runs/carry-0064-upstream/runtime.c.txt),
  [frozen vectors](validation/runs/carry-0064-upstream/runtime-vectors.h.txt).
- [Corpus summary](validation/runs/carry-0064-upstream/census-summary.json),
  [per-object commands](validation/runs/carry-0064-upstream/census-results.json),
  [sources, IR, objects, logs and disassemblies](validation/runs/carry-0064-upstream/census-artifacts.tar.gz),
  [measurement runner](validation/runs/carry-0064-upstream/measure.py.txt).

Runner copies preserve their original `.scratch/carry-pr/` working paths. The
container maps that source to `/work/build/register-exhaustion-src` and its
build to `/work/build/0029-cross-target-build`, matching the retained CMake
cache. The root repository mount was read-only; only owned scratch submounts
were writable. Build command: `ninja -C build/0029-cross-target-build -j 6 llc`.
Suite command: `build/0029-cross-target-build/bin/llvm-lit -v -j 4`
followed by `build/register-exhaustion-src/llvm/test/CodeGen/MOS` and
`build/register-exhaustion-src/llvm/test/MC/MOS`. The baseline suite excludes
`carry-pressure-schedule`; its ten commands are measured separately.

The census emits IR once with an identified downstream Clang, using the sim
configuration and ordinary 6502 near pointers. Both exact-current backends
consume those same bytes; `llc` uses `-O=2` with the frontend's Os/Oz/O2
attributes. Only the terminal WAI in the original thirteen fixtures had been
adapted to empty volatile assembly. The runtime holds the driver, linker and
SDK fixed while replacing the kernel object. Python supplies 512 exact expected
results, including zero, all-ones and sign-bit boundaries; target C compares
bytes. The retained images can be rerun directly with the identified mos-sim.

An exploratory `-debug-pass=Structure -filetype=null` command on `arith.Os.ll`
exits on signal 11 with **both** builds. Its logs are retained in the receipt;
the cause is unisolated, no repair is claimed, and normal verified object
emission passes. This diagnostic observation is not counted as a passing gate.

Cycles and compiler overhead are unmeasured. Earlier native-width results and
their growing cases remain downstream evidence, summarized in the
[profitability review](0064-review.md); they are not relabeled as current
upstream results. The validation pass itself did not perform independent review or publication.

## Publication update

The tested compiler commit `155e209c4cee` is now [on the fork branch](https://github.com/wbniv/llvm-mos/tree/mos-computed-carry-scheduling).
Publication did not change the tested patch or its retained evidence. No PR
has been opened. Publication: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0dd01-d72e-76f2-bf27-a796e0f7d994`.
