# Integrated SDK longjmp validation

Base: `3f6968bbc156ff9a63102a8e158db868819bd61c`, fetched from current SDK main.
Preparation checkout: `/tmp/sdk-longjmp-pr`, branch `fix-longjmp-zero`.
The [patch](sdk-longjmp-zero.patch) contains the assembly fix, simulator test source,
CMake/CTest registration, and testing instructions. Published as [SDK PR #450](https://github.com/llvm-mos/llvm-mos-sdk/pull/450), head `0f8ad11589f556daa8b4c02707c53a17db1cadb0`; live head and description verified.

The new `test-sim` target follows the existing SDK ExternalProject structure,
depends on both SDK installation and the host `mos-sim` target, and runs 20 CTest
cases without an external emulator. Each test has a ten-second timeout. Source/test
comments passed `dev/check-comment-history.py`; the staged diff passed whitespace checks.

## Reproduction

```sh
cmake -S /tmp/sdk-longjmp-pr -B /tmp/sdk-longjmp-build -G Ninja \
  -DLLVM_MOS=/home/will/llvm-mos-65816/build/llvm-mos-install \
  -DLLVM_MOS_BOOTSTRAP_COMPILER=OFF -DLLVM_MOS_BUILD_EXAMPLES=OFF
cmake --build /tmp/sdk-longjmp-build --target test-sim -j 6
```

For the baseline, apply the test integration but leave `setjmp.S` unchanged.
For the fixed run, apply the assembly fix, clean the test executables, and rerun:

```sh
cmake --build /tmp/sdk-longjmp-build/test/sim/build --target clean
cmake --build /tmp/sdk-longjmp-build --target test-sim -j 6
```

The SDK selects libraries implicitly through platform configuration files; the
nested test build does not track archive timestamps. An initial incremental run
retained the baseline executables. Cleaning and relinking tests is necessary when
comparing SDK library revisions; this is also documented in the proposed test README.

| SDK assembly | Zero at O0/O1/O2/Os | 1, 7, 256, -1 at each level | Total |
|---|---|---|---|
| Unmodified upstream | Four failures | 16 passes | 16/20 pass |
| With normalization | Four passes | 16 passes | 20/20 pass |

[Baseline CTest output](sdk-longjmp-ctest-baseline.txt) ·
[Fixed CTest output](sdk-longjmp-ctest-fixed.txt).

SDK libraries and the simulator were built from the current SDK checkout. The
compiler was the local installed MOS compiler, not a fresh stock compiler build.
Only the simulator test suite was run; no hardware/native-SNES behavior is claimed.

Website tracking: the compiler product page now includes an Upstream contributions
entry for SDK #450, with open/review status and the 20-case validation result.
Website commit: `faf21525ec600003cd695a61a405ce40c3709089` in `wbniv/indri.studio`;
local Astro build passed (153 pages). Deployment workflow
[35481801726](https://github.com/wbniv/indri.studio/actions/runs/35481801726) completed its test, build and Cloudflare deployment steps successfully.
The live page https://indri.studio/apps/llvm-mos-65816/ was fetched and verified
to contain the PR link and zero-return fix entry. Post-deployment Lighthouse audit
was still running at verification time.

Comment-only follow-up `0f8ad11589f5` adds the POSIX.1-2024 URL beside
the normalization epilogue. Comment and whitespace checks pass; executable code
is unchanged, so the recorded runtime results still apply.
