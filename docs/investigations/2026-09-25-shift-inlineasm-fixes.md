# Native-width extension and inline-asm register bounds

OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh`
reasoning effort: diagnosis, implementation, regression tests, validation, and
documentation. [Session identity](../defects/evidence/2026-09-25-shift-inlineasm-fixes/session-identity.json)
records the verified metadata. Earlier discovery and patch credits remain in
the historical investigations.

Both requested correctness items are repaired locally and the installed compiler
is refreshed. Patch [0055](../../patches/llvm-mos/0055-mos-native-wide-anyext.patch)
repairs the recovered native-width shift trigger; patch
[0056](../../patches/llvm-mos/0056-llvm-gisel-inline-asm-register-bounds.patch)
diagnoses an insufficient physical-register range in generic GlobalISel inline
assembly. Structured records: [shift](../defects/shift64-narrow-count.json) and
[inline-asm bounds](../defects/gisel-inline-asm-register-bounds.json).
No upstream submission was made.

## Narrow-count shifts: identified backend repair

The [source recovery](2026-09-25-historical-baseline-recovery.md) captured the
full bitboard caller failing on the fork at `-Os +mos-a16`, without LTO. That
immutable baseline, preprocessed input, and diagnostic remain unchanged.
The same input now passes with 0055, as does the retained LLVM IR. The repair is
in the backend legalizer; no frontend transformation is needed to avoid the
trigger.

The legalization rules accept some native-width `G_ANYEXT` operations, but omit
`s8/s16/s32 -> s64`. Patch 0055 sends those native-width cases through the
existing zero-extension lowering. Zero is a valid choice for the unspecified
high bits. Other legality rules and default-mode behavior are retained.

The failure reduces to seven lines of valid LLVM IR: multiply a byte by seven,
mask it with 63, zero-extend it to i64, and store it. Legalization introduces the
unsupported `G_ANYEXT`. The
[reduced input](../defects/evidence/2026-09-25-shift-inlineasm-fixes/extend-masked.ll)
fails on the preserved baseline for that reason and passes on the candidate.
Its MIR before legalization is retained. The bundled
`anyext-masked-byte.ll` is the discriminating regression;
`anyext-wide.mir` additionally checks byte preservation and shift-count passing
for extensions from 8-, 16-, and 32-bit sources.

The simple MIR controls pass on the baseline because its artifact combiner can
eliminate those extensions before the unsupported rule is consulted. They do
not independently establish the repair. An early synthetic MIR with an s64
operand attached directly to RTS instead exposes an unsupported wide merge;
it is retained as an unsuccessful reduction, not used as a fixed regression.
The saved MIR reducer crashed while reducing the full input; IR reduction
succeeded, followed by manual removal of unrelated operations and replacement
of the reducer's null store address with an output parameter. The final input
still fails for the recorded reason.

Validation on the final compiler:

- The original preprocessed input, retained LLVM IR, and reduced LLVM IR pass.
  The preserved baseline still fails the same original input and reduced input.
- Both recovered source stages pass at `O0/O1/O2/O3/Os/Oz`, in default/a16/xy16:
  **36 non-LTO compilations with MachineVerifier enabled**.
- The all-count shift fixture exercises left, logical-right, and arithmetic-right
  shifts over counts 0–63. Host and default/a16/xy16 SNES execution on bsnes-jg
  agree at **`0x6A2B`**, after 480 frames.
- The recovered variable-shift bitboard probe, without either historical helper
  workaround, agrees with the host at **`0x479E`** in all three modes on bsnes-jg.
- The same retained LTO bitcode fails with the preserved pre-0055 LLD at
  `G_ANYEXT`, links with rebuilt LLD, and executes at **`0x479E`** in
  default/a16/xy16. These three additional runs bring the runtime total to nine.
  The initial saved-linker invocation used a basename LLD did not recognize;
  only `lto-a16-baseline-valid.log`, using the `ld.lld` alias, is a defect
  reproduction. Both attempts remain recorded.
- The MOS CodeGen/MC suite succeeds with **175 tests discovered**. Quiet lit
  output does not retain separate pass/unsupported counts.

An initially broader rule changed the unspecified high bits in an existing
default-mode test. The final rule is limited to native-width s64 extensions.
A separate test-output permission error was resolved by using a fresh lit
execution directory. The initial failing suite log is retained separately from
the final successful result.

The [published Limb-Seam Barrel](https://biohack.net/snes/shift64seam/) and
[Bitboard Knight Tour](https://biohack.net/snes/bitboard64/) remain supporting
historical demo evidence. This validation builds new local ROMs and does not
claim to update the published binaries.

## Inline assembly: independent generic trigger

The MOS `=a` example is intercepted by patch 0043, so it cannot test the generic
register walk. A constructed AArch64 LLVM IR input independently reaches it:
an i128 inline-asm output constrained to `{cc}` requires two registers, while
the class contains only NZCV. The preserved assertion-enabled compiler aborts
with `Ran out of registers to allocate!`.

The baseline is `build/0041-inlineasm-build/llc-0041`, an upstream-based
multi-target build with existing patches through 0041. It is **not a clean
unpatched upstream build**. Its entire register-assignment helper is, however,
byte-for-byte identical to unpatched upstream revision
`742d554bf08042b8df93d791c335260fadd16643`; the
[identity record](../defects/evidence/2026-09-25-shift-inlineasm-fixes/inlineasm-baseline-identity.json)
captures that comparison, binary hash, source revision, dirty diff, and build
configuration. This new reproducer is original LLVM IR, so there is no C
preprocessing stage. The exact input and complete failure log are retained.

The candidate checks that the named register and the entire requested range fit
inside the class before assigning any operands. Virtual-register allocation is
separate and is not bounded by the physical class-member count. On failure,
GlobalISel emits an inline-asm error and defines the call's result registers as
undefined values for diagnostic handlers that return. It omits the invalid
assembly and avoids falling back into another register-allocation path.
Compilation fails normally with an error; it does not assert or emit a usable
output artifact.

The isolated assertion-enabled candidate replaces only `InlineAsmLowering.cpp`
in the baseline's GlobalISel library and relinks against the same other
libraries. The original source and build directories were mounted read-only.
The vendor adaptation and upstream-based variant carry the same bounds and
diagnostic logic; the newer source retains its existing `RegClass` assignment.

Validation:

- The [diagnostic regression runner](../../dev/check-inlineasm-register-diagnostic.py)
  fails on the saved baseline and passes on the candidate with the **same IR**.
  A passing runner means compiler exit 1 with exactly the expected diagnostic;
  accepting this invalid constraint would fail the test.
- Direct output, input, tied output/input, and indirect output are checked at
  `-O0` and `-O2`, with GlobalISel fallback enabled and disabled: all **16 error
  cases** produce the intended diagnostic. Their results pass FileCheck.
- Three valid AArch64 physical-register controls still compile.
- The AArch64, ARM, and X86 GlobalISel suites succeed with **1,067 tests
  discovered**, using the isolated assertion-enabled candidate.

This is compiler error handling for an unsupported constraint, not a runtime
miscompile claim. The SelectionDAG implementation has a similar assertion in
its own register walk; this investigation does not establish or repair a
separate SelectionDAG failure.

## Artifacts and reproduction

All new logs and manifests are in
[`2026-09-25-shift-inlineasm-fixes/`](../defects/evidence/2026-09-25-shift-inlineasm-fixes/).
`compile-runs.json` and `runtime-runs.json` retain exact commands, exit codes,
oracle values, and ROM/map hashes. `final-checks.json` records the candidate and
installed compiler hashes, reduced-input comparison, and diagnostic checks.
`lto-runs.json` additionally records the retained bitcode hashes, preserved and
rebuilt linker identities, three LTO runtime results, and installed LLD hash.
`patch-checks.json` verifies both vendor bundles apply to preserved source and
reproduce the working source. `dev/toolchain.sh` applies both patches;
`dev/regen-patch.sh` keeps 0055 separate from the native-width base patch.

The preserved baselines are not overwritten. Candidate binaries remain in
`build/llvm-mos/bin/` and `build/inlineasm-bounds-fix/llc`; the installed
`build/llvm-mos-install/bin/mos-clang` matches the rebuilt Clang hash and passes
the captured shift command; installed `ld.lld` also matches its rebuilt binary.
Capture scripts are records of the runs and write
to recorded output paths; use a fresh evidence directory for a new capture.

```sh
python3 dev/check-inlineasm-register-diagnostic.py \
  --llc build/inlineasm-bounds-fix/llc
build/llvm-mos/bin/llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 \
  -O2 -verify-machineinstrs \
  docs/defects/evidence/2026-09-25-shift-inlineasm-fixes/extend-masked.ll \
  -o /dev/null
```
