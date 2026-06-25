# Cross-compile the toolchain for macOS arm64, Windows x86_64, Linux arm64 (from the Linux Docker)

**Date:** 2026-06-25 · **Status:** PLANNED (decisions locked below) · **Issue:** #321 distribution
follow-on. Interim-preview capability: the 8-patch fork (`patches/llvm-mos/0001–0008`) is being upstreamed;
once it lands, upstream llvm-mos's own release CI emits these platforms, so this is an **interim** lever, not
a permanent fork-only burden.

## Decisions (locked via Q&A 2026-06-25)
- **Targets:** `macos-arm64`, `windows-x86_64`, `linux-arm64` — **plus** the existing `linux-x86_64`
  (kept). *Not* macOS Intel.
- **Approach:** **cross-compile from the existing Ubuntu-26.04 x86-64 Docker** (`dev/Dockerfile`). **No**
  GitHub Actions macos/windows runners. One build environment, fully reproducible from the image — matches
  how this repo already works and how [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) /
  [osxcross](https://github.com/tpoechtrager/osxcross) cross-build LLVM today.

## Context — why

Today `dev/run.sh toolchain` builds llvm-mos **inside the Linux container** (cmake recipe in
`dev/toolchain.sh`, `MOS.cmake` cache → `distribution`/`install-distribution`), producing **x86-64 ELF**
`clang-23` + `lld` + `llvm-*`. `dev/package-release.sh` merges that with the SDK into a relocatable tarball
whose platform tag is **hardcoded `linux-x86_64`** (`NAME=…-linux-x86_64`). No mac/Windows path exists
anywhere; all CI is `ubuntu-latest`.

**The key insight that makes this tractable:** only the **host executables** (clang/lld/llvm-tools) differ
per platform. *Everything target-side is host-agnostic* and built **once** by the existing native Linux
build:
- the **MOS compiler-rt builtins** (`lib/clang/23/lib/mos-unknown-unknown/libclang_rt.builtins.a`) — 65816
  object code,
- the **clang resource headers** (`lib/clang/23/include`) — text,
- the **SNES SDK** (`mos-platform/`, `.cfg` files, cmake package) — 65816 libc/crt0/linker-scripts, already
  proven host-independent (`build/install/`).

So each platform package = **[cross-built host binaries]** + **[the identical target artifacts copied from
the canonical Linux build]**. The cross builds therefore **don't need to run the just-built clang** (which
they couldn't — wrong host arch), so we **disable the runtimes sub-build** in the cross configs and graft in
the prebuilt MOS builtins.

## Architecture

Cross-compiling LLVM host tools from x86-64 Linux needs three things per target; all are standard:

1. **Native tablegens** for the build host — reuse the existing native build's `build/llvm-mos/bin/llvm-tblgen`
   + `clang-tblgen` via `-DLLVM_NATIVE_TOOL_DIR=$PWD/build/llvm-mos/bin` (so the existing
   `dev/run.sh toolchain` Linux build is a **prerequisite** of every cross build).
2. **A cross C/C++ toolchain + sysroot** for the target host OS:

   | Target | Cross toolchain (apt / built) | Notes |
   |---|---|---|
   | `linux-arm64` | `g++-aarch64-linux-gnu` (apt) | easiest; sysroot ships with the package |
   | `windows-x86_64` | `g++-mingw-w64-x86-64-posix` (apt) | **posix** threads variant (libstdc++ threading); → native `.exe`, no WSL |
   | `macos-arm64` | **osxcross** built in-image + the **macOS SDK** (one manual input, see Risks) | provides `oa64-clang`, cctools/ld64, libtapi |

3. **A CMake toolchain file** per target setting `CMAKE_SYSTEM_NAME` (Linux/Windows/Darwin),
   `CMAKE_C/CXX_COMPILER`, `CMAKE_SYSROOT`, `LLVM_HOST_TRIPLE` (`aarch64-unknown-linux-gnu` /
   `x86_64-w64-windows-gnu` / `arm64-apple-darwin`), `CMAKE_CROSSCOMPILING=ON`, `LLVM_NATIVE_TOOL_DIR`, and
   **`LLVM_ENABLE_RUNTIMES=""` + drop `LLVM_BUILTIN/RUNTIME_TARGETS`** (target libs come from the Linux build).

**Stripping** the cross binaries uses the **native Linux** `llvm-objcopy`/`llvm-strip` (multi-format: it
strips Mach-O, COFF/PE, and ELF) — never the un-runnable cross binary.

**Warning-free self-test gate** (the release blocker) is preserved where the foreign binary can be *run* in
the container:
- `linux-arm64` → run the produced `clang-23` under **`qemu-aarch64-static`**,
- `windows-x86_64` → run the produced `clang.exe` under **`wine64`** (llvm-mingw's CI does exactly this),
- `macos-arm64` → **cannot** run Mach-O/arm64 on x86-64 Linux. Substitute a **structural** gate (all expected
  binaries present + non-dangling + correct Mach-O arch via native `llvm-readobj`); the functional
  warning-free self-test is **deferred to a real Mac** before that tarball is published (documented, not
  silently skipped). *(This is the one accepted limitation of the cross-from-Linux choice.)*

## Increments (risk-ordered — each lands independently; `linux-x86_64` stays byte-identical)

**Increment 0 — refactor the build to be host-parameterized (foundation).**
- Factor the cmake *configure → build distribution → install-distribution* out of `dev/toolchain.sh` into a
  reusable function taking a **host profile**; the native build calls it with the `native` profile and must
  stay **byte-identical** (regression gate: corpus 7/7, `clang-23` unchanged).
- Add cross toolchain files under **`dev/cross/{linux-arm64,windows-x86_64,macos-arm64}.cmake`** and a driver
  **`dev/cross-toolchain.sh <profile>`** (configures into `build/llvm-mos-<profile>/`, installs into
  `build/llvm-mos-install-<profile>/`). Wire `dev/run.sh cross-toolchain <profile>`.
- Generalize **`dev/package-release.sh`**: derive the platform tag from a `PLATFORM` arg (default `linux-x86_64`),
  and copy the **host-agnostic** `lib/clang/23` + `mos-platform/` + `.cfg` + cmake from the canonical Linux
  `build/llvm-mos-install` / `build/install` (not the per-target install). Keep the existing Linux output identical.

**Increment 1 — `linux-arm64` (proves the refactor; cheapest).**
- Dockerfile: `apt-get install g++-aarch64-linux-gnu qemu-user-static`.
- Build via the new cross path; package `…-linux-aarch64.tar.xz`; self-test the `clang-23` under `qemu-aarch64`.

**Increment 2 — `windows-x86_64`.**
- Dockerfile: `g++-mingw-w64-x86-64-posix wine64`.
- Package specifics in `package-release.sh` (Windows branch): append **`.exe`**, replace driver **symlinks
  with copies** (`clang→clang-23`, `mos-clang→clang`, `ld.lld`/`lld-link`/`ld64.lld` multicall copies),
  emit a **`.zip`** (Windows-friendly) instead of `.tar.xz`. Self-test `clang.exe` under `wine64`. Confirm
  `--config <CFGDIR>` relocatability resolves under Windows paths.

**Increment 3 — `macos-arm64` (highest risk; gated on the SDK input).**
- Dockerfile: build **osxcross** (clone, `apt` its deps: `clang cmake libssl-dev liblzma-dev libxml2-dev`),
  consume the user-provided macOS SDK from `dev/sdks/`.
- Build via osxcross's `oa64-clang`/`oa64-clang++`; package `…-macos-arm64.tar.xz`; **structural** verify
  (format/arch/no-dangling); document the real-Mac functional check before publish.

**Increment 4 — orchestration (no CI matrix, per decision).**
- `Taskfile.yml`: `task package PLATFORM=<p>` and `task package-all` (loops the four platforms; mac skipped
  if `dev/sdks/` has no SDK, with a clear notice). Outputs all tarballs + `.sha256` into `dist/`.
- Releasing stays a **local human step** (matches today); optionally a one-line `gh release upload` documented,
  *not* an auto-CI workflow.

## Files (create / modify)
- **Create:** `dev/cross/linux-arm64.cmake`, `dev/cross/windows-x86_64.cmake`, `dev/cross/macos-arm64.cmake`;
  `dev/cross-toolchain.sh`; `dev/sdks/README.md` (the macOS-SDK ask).
- **Modify:** `dev/toolchain.sh` (extract host-parameterized configure/build/install + `LLVM_NATIVE_TOOL_DIR`);
  `dev/Dockerfile` (cross toolchains + qemu/wine + osxcross); `dev/package-release.sh` (PLATFORM tag, reuse
  target artifacts, Windows `.exe`/copy/zip branch, strip via native objcopy, qemu/wine/structural self-test);
  `dev/run.sh` (`cross-toolchain` dispatch); `Taskfile.yml` (`package PLATFORM=`, `package-all`); `README.md`
  (download table once builds exist).
- **Reuse (host-agnostic, copied verbatim):** `build/llvm-mos-install/lib/clang/23/{include,lib/mos-unknown-unknown}`,
  `build/install/{mos-platform,bin/*.cfg,lib/cmake}` — and `build/llvm-mos/bin/{llvm,clang}-tblgen` as the native tools.

## Verification (per increment — same WARNING-FREE bar as the Linux release)
1. **Native unchanged (Inc 0):** after the refactor, `dev/run.sh toolchain` then `dev/run.sh corpus` → **7/7**;
   `task package` → the `linux-x86_64` tarball self-test passes, **0 warnings**; `clang-23` byte-identical to pre-refactor.
2. **Format/arch (every cross target):** `llvm-readobj --file-headers build/llvm-mos-install-<p>/bin/clang-23`
   reports the expected arch (`aarch64` / `x86_64 COFF` / `arm64 Mach-O`); no dangling symlinks in the staged tree.
3. **Functional self-test where runnable:** `linux-arm64` compiles `examples/snes/hello.c` via the produced
   clang under `qemu-aarch64` with **0 warnings/errors**; `windows-x86_64` the same under `wine64`.
4. **macOS:** structural gate green in-container; record a manual real-Mac `mos-clang --config mos-snes.cfg
   examples/snes/hello.c` → boots in MAME/bsnes, **0 warnings** — paste output here before publishing the mac tarball.
5. **Artifacts:** `dist/` holds `llvm-mos-65816-<stamp>-{linux-x86_64,linux-aarch64,macos-arm64}.tar.xz` +
   `windows-x86_64.zip`, each with a `.sha256`; unpack-and-run a target package as the final check.

## Risks & the single manual input
- **macOS SDK (the one unavoidable manual ask, Apple licensing):** osxcross needs `MacOSX<ver>.sdk.tar.xz`
  extracted from Xcode / Command-Line-Tools on a Mac (Apple's license forbids redistribution, so it can't be
  baked into the public image). Reduce to **one** documented step: drop the SDK tarball in `dev/sdks/`; the
  image build and Increment 3 automate everything downstream. Without it, `package-all` builds the other three
  and skips mac with a notice.
- **macOS cross is the riskiest leg.** If osxcross proves too painful, the fallback is a one-off build on real
  Mac hardware using the same `dev/cross`/package scripts (the refactor makes the binaries the only difference).
- **Cost:** build time only (no runner $ — runs in the existing Docker). Each cross target is a full LLVM
  build (~30–90 min cold, ccache-warm after); native tblgens are reused, not rebuilt.
- **Upstream framing:** once patches `0001–0008` land upstream, upstream llvm-mos's release CI emits these
  platforms — so keep the generated README's "interim preview; prefer upstream once merged" note.
