# MOS posting packets: exact-current validation

The original eleven packages below have an isolated assertion-enabled build on llvm-mos
main `7bd67c0ae4e8bb65a3f980912bf201df22131e34`. No SNES or native-width
feature patch is imported. 0044's only candidate prerequisite is 0039; each
other candidate is compared against pristine main. The original fork evidence
and attribution remain separate and unchanged. Nothing was posted.

| Package / exact patch SHA256 | Passing focused RUN commands | MOS suite passes / unsupported | Immutable run receipt |
|---|---:|---:|---|
| [0038](0038-llvm-mos.patch) · `0220a0f083728dca77bae8985a330e5a33a135b13d60fc580d5c604f253336a8` | 5 | 134 / 1 | [commands, logs, inputs, and binary hashes](validation/runs/post-ready-validation-mos-older/0038/receipt.json) |
| [0039](0039-llvm-mos.patch) · `36a5787a07b72287ebbb98a49d1f2358407805483151d57fc50b91f2c8c2d909` | 3 | 134 / 1 | [commands, logs, inputs, and binary hashes](validation/runs/post-ready-validation-mos/0039/receipt.json) |
| [0040](0040-llvm-mos.patch) · `08438234c2a52cc93ce9a14f513b65b3f41eb6ad5c212ba2ca83ba4e30075341` | 2 | 132 / 1 | [commands, logs, inputs, and binary hashes](validation/runs/post-ready-validation-mos-older/0040/receipt.json) |
| [0043](0043-llvm-mos.patch) · `6567f94b72a8677d00eb9a542914be0da446d036d77dddac588c6bfeb5ea8bb5` | 14 | 132 / 1 | [commands, logs, inputs, and binary hashes](validation/runs/post-ready-validation-mos-r2/0043/receipt.json) |
| [0044](0044-llvm-mos.patch) · `6b48a04ae47c924af4cc777454985a6e2489596047edc2e6253fd188a36f4de1` | 3 | 136 / 1 | [commands, logs, inputs, and binary hashes](validation/runs/post-ready-validation-mos/0044/receipt.json) |
| [0045](0045-llvm-mos.patch) · `ce595a69e81c2ec6732bd4d9cf8a5bf01aaa3c7ff4d254228188a678a9f9559c` | 7 | 132 / 1 | [commands, logs, inputs, and binary hashes](validation/runs/post-ready-validation-mos/0045/receipt.json) |
| [0046](0046-llvm-mos.patch) · `d42701fa045a3f4c4a3cf73807cfb50e0dc838e51b3bc1b06e95be61d935e442` | 0 | 131 / 1 | [commands, logs, inputs, and binary hashes](validation/runs/post-ready-validation-mos/0046/receipt.json) |
| [0047](0047-llvm-mos.patch) · `b641d19787bcf09329b8535190f09c0d924d51177a4273cb258bacd211dd9d61` | 9 | 133 / 1 | [commands, logs, inputs, and binary hashes](validation/runs/post-ready-validation-mos-r2/0047/receipt.json) |
| [0050](0050-llvm-mos.patch) · `ee387217ce29cd2d66598bf34edf142e643969e53394f513fcfb9b8b30ce72cf` | 1 | 132 / 1 | [commands, logs, inputs, and binary hashes](validation/runs/post-ready-validation-mos-r2/0050/receipt.json) |
| [0054](0054-llvm-mos.patch) · `a80b2ed392acfef33ff33b18934c9801721bbd62c4c2314bf1f4d30a3f30178f` | 1 | 132 / 1 | [commands, logs, inputs, and binary hashes](validation/runs/post-ready-validation-mos-r3/0054/receipt.json) |

The first ten rows cover MOS CodeGen/MC suites. The separate reducer backport is:

| Package / exact patch SHA256 | Passing focused RUNs | llvm-reduce suite passes / unsupported | Immutable receipt |
|---|---:|---:|---|
| [0060](0060-llvm-mos.patch) · `a62ebcdbdd7059d85c638e20c9bff8efaed808e9df5c35c4d2d6c93b3be04601` | 9 | 180 / 27 | [commands, logs, inputs, binary hashes](validation/runs/post-ready-validation-mos-reducer/0060/receipt.json) |

0060 backports existing upstream `b1ba3d515a02`, rather than proposing a new
LLVM repair or parallel-MIR support. Its valid X86 MIR verifies and reduces
serially on the baseline, then SIGSEGVs with `-j 2`; the candidate cleanly rejects
parallel MIR while serial MIR and parallel IR controls pass. The original tiny
upstream test is not the causal crash witness. Baseline reducer suites have
178 passes / the same 27 unsupported; candidate has zero failures. The pinned
image is the same digest recorded below for 0038/0040. See the
[independent review](0060-backport-review.md) and
[upstream reconciliation](0060-reconciliation.json). The failed LLVM preparation
is preserved separately in the LLVM summary.

All ten behavioral repairs have a regression failing on their matching baseline for the
reviewed mechanism and pass with their identified source change. 0046 is a
latent metadata-table invariant repair: its compile-time guard and existing
positive tests pass; there is no claimed runtime-red baseline. The single
unsupported suite test is the existing `getchar-regression.ll`.

0038's original IR inputs diagnose unsupported intrinsics on the baseline;
its additional MIR depth test is candidate-only coverage because the baseline
does not have the new pseudo/pass. The separate SPC700 0003 limitation remains
qualified in its review and draft. 0040 uses pre-greedy MIR emitted by the
preserved earlier compiler: it is a pinned pass input, not a claim that current
IR lowering naturally reproduces the same pressure. That valid MIR reproduces
the exact SplitKit assertion on current main. Spill hoisting is disabled on
both sides to isolate coalescing from the separate 0033 repair.

0039 additionally has a [same-source stock-6502 runtime differential](validation/runs/post-ready-review-mos/runtime0039/standalone/manifest.json):
wrong zero-page wrap produces W/exit 7, whereas the corrected absolute load
produces P/exit 0. 0045's regression compares direct and reassembled .text bytes;
0047 compares complete direct and reassembled objects, including relocations.
0054 uses the existing scavenger-test harness and valid block-local scratch
registers; independent baseline/candidate input verification and three-CPU
checks are retained in the reviewer evidence.

The first 0043 attempt retained an obsolete fatal-diagnostic expectation; its
compiler source already produced the correct clean diagnostics. The final
packet has twelve exact clean-error checks, independently verified at O0/O2.
The first 0047 attempt exposed the current MCAsmInfo pointer-to-reference API
change; the posting variant adapts that one call without changing semantics.
The early 0054 PEI-entry assertion is not a causal defect baseline. A subsequent
valid nested-spill probe also reaches the independently pre-existing live-N/Z
assertion covered by 0011: a balanced-save control reproduces it on both
pristine current upstream and the 0054-only candidate. The final scavenger-test
fixture isolates the actual save-range contract; it does not close the separate
0011 issue or invalidate the wider input. These attempts and the prior-work
reconciliation remain separately retained in the reducer review evidence.

Reproduction uses [validate.py](validate.py), the exact patches above, and the
CMakeCache retained with each receipt. The first eight runs used the
network-disabled local `llvm-mos-65816-dev` container tag. Those containers were
automatically removed and their individual image digests were not captured;
the reviewers' separate image identities must not be substituted for them.
The later 0038/0040 runs explicitly pin and record image
`sha256:eeecfab76840167d9f16982b1efddae90d4969c5d7891ec16e87e46150ac94c1`.
Exact executable hashes and configurations are retained for every run.
The source directory is `build/post-ready-2026-09-26-isolated-src`; its warm build
uses container aliases `/work/build/register-exhaustion-src` and
`/work/build/0029-cross-target-build`, respectively bound to that source and
`build/post-ready-2026-09-26-build`. It was explicitly reconfigured and rebuilt
from the clean pinned source before any candidate run. Old directory names do
not identify the source version; Git identity, CMake configuration, patch and
binary hashes do.

Preparation and isolated validation: OpenAI Codex CLI 0.157.0 (`codex-tui`),
model `gpt-6-astra`, `xhigh` reasoning effort; verified session
`01a0db16-f6a0-7e32-ada6-0c8098813933`. The linked MOS, diagnostic, and reducer
reviews record the independent agents' own exact credits. No broader all-target,
new frontend driver, native runtime, GitHub CI, or publication check is implied.

## 0064 addition: computed-carry scheduling

The [standalone extraction](0064-llvm-mos.patch) on the same exact base is
validated separately: **ten focused commands; 132 MOS CodeGen/MC passes, one
unsupported; 512 stock-6502 Python-oracle vectors on each build**. Kernel text
shrinks **133 → 59 bytes**. The fixed-frontend ordinary-MOS census has 117
identical object disassemblies. See the [receipt](validation/runs/carry-0064-upstream/receipt.json)
and [validation scope](0064-validation.md); earlier downstream size losses are
retained in the [author review](0064-review.md). No independent review is claimed.

Preparation: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh`
reasoning effort; verified session `01a0dd01-d72e-76f2-bf27-a796e0f7d994`.
