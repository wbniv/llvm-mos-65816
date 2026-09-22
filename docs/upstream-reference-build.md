# Saved unpatched upstream compiler

The reference compiler is pinned to llvm-mos revision
`742d554bf08042b8df93d791c335260fadd16643` and retained at:

```text
build/upstream-reference/742d554bf08042b8df93d791c335260fadd16643/
```

Use it for stock-upstream reproduction checks. Keep candidate patches in separate
source/build directories; do not replace files in this snapshot. A new upstream
revision gets its own directory, leaving existing evidence reproducible.

## Run a test

From the host, with repository-relative input and output paths:

```sh
dev/upstream-reference.sh --verify
dev/upstream-reference.sh clang --version
dev/upstream-reference.sh clang --target=mos -mcpu=mos6502 -Os \
  -mllvm -verify-machineinstrs -c examples/65816/rcundef2.c \
  -o build/rcundef2-upstream-6502.o
```

The wrapper mounts the repository at `/work`, mounts the compiler snapshot read
only, and runs the tool in the exact saved Docker image ID without networking.
It neither rebuilds the compiler nor applies patches. `/work` absolute paths also
work. `MOS_UPSTREAM_REFERENCE_REVISION` selects another saved revision.

The snapshot contains Clang, `llc`, `opt`, `FileCheck`, the assembler/object tools,
LLD, and Clang's resource headers. It is a compiler reference, not a platform SDK;
programs needing SDK headers or libraries must name those dependencies separately.

## Provenance and preservation

- Built September 22, 2026, from a checkout with an empty tracked diff against the
  pinned revision. Two untracked 0028 MIR tests are recorded in the manifest;
  they do not change compiler source or binaries.
- Release build, MOS target only, `LLVM_ENABLE_ASSERTIONS=OFF`.
  MachineVerifier is explicitly enabled in the reproduction commands; compiler
  assertions are a separate setting and are not claimed for this build.
- `manifest.json` records the revision, container image ID, tool versions, build
  settings, source/build locations, and untracked test files.
- `CMakeCache.txt` and `logs/` preserve the configuration and build records.
- `SHA256SUMS` covers the binaries, headers, manifest, configuration, and logs.
  `--verify` checks their integrity.
- The snapshot holds independent copies of the binaries and headers, so rebuilding
  a development compiler cannot overwrite the saved reference.
- The incremental build is `build/upstream-llc`. Its configured source path inside
  Docker is `/work/build/upstream-src`; the clean checkout used for this build is
  `build/0028-upstream-src`, mounted at that path. Keep these available for baseline
  rebuilds; use separate directories for patched builds.

These are local, gitignored build artifacts. The checked-in wrapper and this
document identify them; they do not imply that another clone already has the
binaries. Preserve the snapshot directory and recorded Docker image when cleaning
build outputs.

The [plain-6502 investigation](investigations/2026-09-22-0028-plain-6502-reachability.md)
records its initial C and MIR checks.

After copying the snapshot, all 322 checksum entries verified. The wrapper
reported the pinned Clang revision and compiled `rcundef2.c` to a 6502 object at
`-Os` with MachineVerifier enabled. The saved `llc` also rejected the constructed
0028 MIR control as expected; the separate patched `llc` accepted it.

## Patch 0029 candidate builds

The register-exhaustion validation uses the same pinned revision plus only
patch 0029. Its source is `build/register-exhaustion-src`; the saved reference
above remains unpatched.

| Build | Configuration | Recorded result |
| --- | --- | --- |
| `build/register-exhaustion-build` | MOS, Release, assertions off | Six-level C matrix passes with and without MachineVerifier; CodeGen/MC 131 pass / one unsupported |
| `build/0029-cross-target-build` | X86, ARM, AArch64, MOS; Release, assertions on | 231 focused X86/ARM/AArch64 tests and both bundled MOS tests pass, no skips |

Both builds use the isolated candidate source and their own build directories.
The assertion-enabled build contains `llc`, `opt`, and the test helpers; it is
not a Clang/SDK installation. See the [validation record](pr-preparations/2026-09-22/0029-validation.md)
and [cross-target commands and coverage](pr-preparations/2026-09-22/0029-cross-target-validation.md)
before choosing a compiler for a follow-up check. These are patch 0029 results;
they do not validate patch 0028 on other backends.

## Patch 0030 candidate build

`build/newton-postra-src` contains the same pinned revision plus only the
physical-copy liveness fix. `build/newton-postra-build` reuses a separate copy of
the assertion-enabled build's objects; the generic two-address source/object is
restored to pristine upstream. Neither 0028 nor 0029 is applied to this candidate.

Its configuration retains `/work/build/register-exhaustion-src` and
`/work/build/0029-cross-target-build` as the source and build paths. Mount the
0030 source and build at those paths when building or running lit; do not point
this build at the 0029 source. The saved unpatched reference remains unchanged.

The [0030 validation record](pr-preparations/2026-09-22/0030-validation.md)
documents five focused MIR cases, 84 passing MOS CodeGen tests and one
unsupported, and six levels of C-derived object emission with identical assembly.
The unchanged frontend is the saved upstream Clang; the candidate provides
patched `llc` and `opt`. Non-MOS backends were not tested for 0030.
