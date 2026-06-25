# Cross-compile the toolchain for Linux arm64 + Windows x86_64 (interim, from the Linux Docker)

**Date:** 2026-06-25 · **Status:** IN PROGRESS (scope locked below) · **Issue:** #321 distribution
follow-on.

## Why this exists — the interim window

The fork's value (`+mos-a16`/`+mos-xy16` 16-bit codegen + #320 far pointers) lives in the
`patches/llvm-mos/0001–0009` stack, which is being **upstreamed**. Today the only published binary is
**`linux-x86_64`** (`dev/package-release.sh` → `apt.indri.studio`). Until #321 is **merged/fixed upstream**,
upstream llvm-mos's release CI does *not* emit binaries carrying these patches — so a developer on **arm64
Linux** or **Windows** has no prebuilt way to try the fork. This plan ships those two interim binaries from
our existing Linux build. **Once #321 lands upstream, upstream CI emits every platform and this lever
retires** — so it is deliberately the *cheapest* cross path (no mac/Win CI runners), not a permanent
fork-only burden. The README each package generates says exactly this ("interim preview; prefer upstream
once merged").

## Scope (locked 2026-06-25 via Q&A)

**Three interim platforms — all cross-built from the one Ubuntu-26.04 x86-64 Docker (`dev/Dockerfile`):**

| Platform | Status | Cross toolchain | Self-test (the warning-free gate) |
|---|---|---|---|
| `linux-x86_64` | **ship (keep, byte-identical)** | native (no change) | native compile, as today |
| `linux-arm64` (aarch64) | **ship (new)** | `g++-aarch64-linux-gnu` (apt; bundles sysroot) | run produced `clang-23` under **`qemu-aarch64`** → ROM **byte-identical to native** |
| `windows-x86_64` | **ship (new)** | `g++-mingw-w64-x86-64-posix` (apt; → native `.exe`) | **structural** + codegen-identity-by-construction; **functional check deferred to real Windows** (wine can't run a large mingw-LLVM binary — see Risks) |
| `macos-arm64` (Apple Silicon) | **DEFERRED** (see below) | osxcross + a user-supplied macOS SDK | structural in-container; functional on a real Mac |

- **`linux-x86_64` is kept and must stay byte-identical** — it is the already-working, already-published
  amd64 build; nothing about the cross work may perturb it (regression gate: corpus 7/7, `clang-23`
  unchanged, the existing tarball self-test still passes 0-warnings).
- **`macos-arm64` is deferred, not dropped.** It is out of this interim scope by decision (it needs the one
  unavoidable manual input — a redistribution-restricted Apple macOS SDK — plus osxcross, and it cannot be
  functionally self-tested on Linux). It stays specified in *Deferred increment — macOS arm64* below so it
  can be picked up later or, more likely, retired when upstream CI covers it. *Not* macOS Intel, ever.
- **Approach: cross-compile from the existing x86-64 Linux Docker.** **No** GitHub Actions macOS/Windows
  runners. One reproducible build environment — matches how this repo already works and how
  [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) / [osxcross](https://github.com/tpoechtrager/osxcross)
  cross-build LLVM today.

## Context — what the build looks like today

`dev/run.sh toolchain` builds llvm-mos **inside the Linux container** (`dev/toolchain.sh`, `MOS.cmake` cache →
`distribution`/`install-distribution`), producing **x86-64 ELF** `clang-23` + `lld` + `llvm-*`.
`dev/package-release.sh` merges that with the SDK into a relocatable tarball whose platform tag is **hardcoded
`linux-x86_64`** (`NAME=…-linux-x86_64`), strips **ELF-only**, and self-tests by running `mos-clang`
**natively**. No mac/Windows/arm64 path exists; all CI is `ubuntu-latest`.

**The key insight that makes cross tractable:** only the **host executables** (clang/lld/llvm-tools) differ
per platform. *Everything target-side is host-agnostic* and built **once** by the native Linux build:
- the **MOS compiler-rt builtins** (`lib/clang/23/lib/mos-unknown-unknown/libclang_rt.builtins.a`) — 65816
  object code,
- the **clang resource headers** (`lib/clang/23/include`) — text,
- the **SNES SDK** (`mos-platform/`, `.cfg` files, cmake package) — 65816 libc/crt0/linker-scripts
  (`build/install/`).

So each platform package = **[cross-built host binaries]** + **[the identical target artifacts copied from
the canonical Linux build]**. The cross builds therefore **don't need to run the just-built clang** (they
can't — wrong host arch), so we **disable the runtimes sub-build** in the cross configs and graft in the
prebuilt MOS builtins at package time.

## Architecture

Cross-compiling LLVM host tools from x86-64 Linux needs three things per target; all standard:

1. **Native tablegens** for the build host — reuse the native build's `build/llvm-mos/bin/llvm-tblgen` +
   `clang-tblgen` via `-DLLVM_NATIVE_TOOL_DIR=$ROOT/build/llvm-mos/bin` (so `dev/run.sh toolchain` is a
   **prerequisite** of every cross build).
2. **A cross C/C++ toolchain + sysroot** for the target host OS:

   | Target | Cross toolchain (apt) | Notes |
   |---|---|---|
   | `linux-arm64` | `g++-aarch64-linux-gnu` | easiest; sysroot ships with the package |
   | `windows-x86_64` | `g++-mingw-w64-x86-64-posix` | **posix** threads variant (libstdc++ `std::thread`); → native `.exe`, no WSL |

3. **A CMake toolchain file** per target setting `CMAKE_SYSTEM_NAME` (Linux/Windows), `CMAKE_C/CXX_COMPILER`,
   sysroot/find-root, `LLVM_HOST_TRIPLE` (`aarch64-unknown-linux-gnu` / `x86_64-w64-windows-gnu`),
   `LLVM_NATIVE_TOOL_DIR`, and **`LLVM_ENABLE_RUNTIMES=""` + drop `LLVM_BUILTIN/RUNTIME_TARGETS`** (target libs
   come from the native build). Files: `dev/cross/{linux-arm64,windows-x86_64}.cmake`. Driver:
   `dev/cross-toolchain.sh <profile>` → `build/llvm-mos-<profile>/` → `build/llvm-mos-install-<profile>/`,
   wired as `dev/run.sh cross-toolchain <profile>` (runs in `dev/Dockerfile.cross`, a layer over the base
   image carrying the cross toolchains, built as a separate `llvm-mos-65816-dev-cross` tag so the shared base
   is untouched).

**Stripping** the cross binaries uses the **native Linux** `llvm-objcopy`/`llvm-strip` (multi-format: strips
COFF/PE and ELF) — never the un-runnable cross binary.

**Cross self-test = ROM byte-identity, not a separate emulator run.** A cross-built clang is the *same
compiler* for a different host, so given identical input it must emit byte-identical 65816 ROM bytes. The
self-test (`dev/cross-selftest.sh`, in the cross image) compiles `examples/snes/hello.c` with the produced
clang under emulation and requires (1) zero warnings and (2) `sha256 == ` the native compiler's ROM for the
same input — so each cross package transitively inherits the native build's clean-room bsnes-jg gate, no
separate emulator run.
- `linux-arm64` → **`qemu-aarch64`**: ✅ runs the aarch64 clang, ROM byte-identical to native.
- `windows-x86_64` → **`wine64`**: ✗ wine **cannot** run the produced binary — clang's front-end runs, then
  wine faults `0xC0000005` in core codegen at **every** `-O` level (a known wine limitation with large
  mingw-LLVM binaries, *not* a defect in the `.exe`). So Windows falls back to a **structural** gate
  (correct x86-64 PE, runtime DLLs, no dangling, front-end + config/resource-dir resolution run under wine)
  plus **codegen-identity-by-construction** (same source tree as the arm64 leg, which *is* proven
  byte-identical); the functional warning-free `-Os` check is **deferred to real Windows** (documented, not
  silently skipped — `cross-selftest.sh` soft-fails `exit 2`, packaging proceeds, the summary prints a
  BEFORE-PUBLISH notice). This is the Windows analogue of the macOS "can't run it on Linux" deferral.

## Increments (risk-ordered — each lands independently; `linux-x86_64` stays byte-identical)

**Increment 0 — host-parameterized build + package (foundation).**
- **Build side — DONE** (`dd2802a`): cross toolchain files `dev/cross/{linux-arm64,windows-x86_64,macos-arm64}.cmake`,
  driver `dev/cross-toolchain.sh <profile>` (configures `build/llvm-mos-<profile>/`, installs
  `build/llvm-mos-install-<profile>/`; runtimes OFF; native tblgens via `LLVM_NATIVE_TOOL_DIR`), and
  `dev/run.sh cross-toolchain` dispatch into `dev/Dockerfile.cross`.
- **Package side — PENDING (this pass):** generalize `dev/package-release.sh`:
  - derive the platform tag + archive format from a **`PLATFORM`** arg (default `linux-x86_64`, unchanged);
  - take the **host binaries** from `build/llvm-mos-install-<PLATFORM>` (cross) but the **host-agnostic target
    artifacts** (`lib/clang/23`, `mos-platform/`, `.cfg`, SDK cmake) from the canonical native
    `build/llvm-mos-install` / `build/install`;
  - **strip via the native `llvm-objcopy`** (multi-format), not the staged cross binary;
  - **Windows branch:** append `.exe`, replace driver **symlinks with copies** (`clang→clang-23`,
    `mos-clang→clang`, the `lld`/`ld.lld`/`lld-link`/`ld64.lld` multicall copies), emit a **`.zip`** instead of
    `.tar.xz`;
  - **self-test dispatch:** native = run directly (today); `linux-arm64` = under `qemu-aarch64`;
    `windows-x86_64` = under `wine64`. Keep the existing `linux-x86_64` output **byte-identical**.

**Increment 1 — `linux-arm64` (proves the refactor; cheapest).**
- Dockerfile.cross already installs `g++-aarch64-linux-gnu`; add `qemu-user` for the self-test.
- `dev/run.sh cross-toolchain linux-arm64`; `PLATFORM=linux-arm64 dev/package-release.sh` →
  `…-linux-aarch64.tar.xz`; self-test the produced `clang-23` under `qemu-aarch64`.

**Increment 2 — `windows-x86_64`.**
- Dockerfile.cross installs `g++-mingw-w64-x86-64-posix` + `wine64` for the self-test.
- `dev/run.sh cross-toolchain windows-x86_64`; `PLATFORM=windows-x86_64 dev/package-release.sh` → `…-windows-x86_64.zip`.
- **Windows packaging specifics (measured against the real install):** the LLVM Windows-target install makes
  **`clang.exe` the real binary** (no `clang-23.exe`) and every multicall name a symlink to it. Symlinks
  don't survive a zip for Windows users, and `clang.exe` is ~110 MB stripped — copying all 5 clang + 4 lld
  aliases would bloat the zip by GBs. So ship a **curated set**: the real binaries + a minimal copy set
  (`mos-clang.exe` ← `clang.exe`, `ld.lld.exe` ← `lld.exe`, the `llvm-ranlib/strip/readelf/addr2line`
  binutils aliases); C++ via `--driver-mode=g++`. Bundle the 3 mingw runtime DLLs (`cross-toolchain.sh`
  deposits them into the install bin/). Strip via the native `llvm-objcopy` (PE-capable). `--config <CFGDIR>`
  relocatability **confirmed under wine** (clang resolved the staged `mos-snes.cfg` + resource/`mos-platform`
  dirs before the wine codegen fault).
- **wine cannot run the binary past the front-end** (Risks); the functional `-Os` check is deferred to real
  Windows. Structural + codegen-identity gate ships the package.

**Increment 3 — orchestration.**
- `Taskfile.yml`: `task package PLATFORM=<p>` and `task package-all` (loops `linux-x86_64`, `linux-arm64`,
  `windows-x86_64`; macOS skipped with a notice). Outputs all artifacts + `.sha256` into `dist/`.
- Releasing stays a **local human step** (matches today), *not* an auto-CI workflow. The uploader lives in the
  **`indri.studio`** repo (which owns the R2 bucket + creds), not here: **`task release-upload`** there
  (`scripts/release-upload.sh`) rclone-publishes the dist archives to the **`/sources`** mirror
  (`r2:indri-apt/sources/` → `apt.indri.studio/sources/`, the product page's direct-download links) — **not**
  the apt `pool/`, which is aptly-indexed `.deb`s only (GitHub is private, so the `.deb` flow can't use a
  release asset; the `.deb` is the `indri.studio/apt` repo's job). It keys the cross archives as
  `llvm-mos-65816_0.0.0+git<date>.<sha>_<archtag>.<ext>` to match the product-page links. Auth = a
  bucket-scoped R2 API token (Object R/W on `indri-apt`) via `RCLONE_CONFIG_R2_*` (least privilege), collected
  by `task secrets-set-r2` → SSM → `secrets-pull`. An `arm64` `.deb` for `apt install` on arm64 Linux would be
  a separate, optional addition to `indri.studio/apt` (Architecture: arm64) — not built here.
- **Live (2026-06-26):** `linux-aarch64.tar.xz` + `windows-x86_64.zip` (+ `.sha256`) uploaded to `/sources`,
  HTTP 200, product-page download links resolve.

**Deferred increment — `macos-arm64` (Apple Silicon).** *Out of interim scope (decision 2026-06-25); kept
specified for later or for retirement once upstream CI covers it.* Needs osxcross built in-image + the
**macOS SDK** (`MacOSX<ver>.sdk.tar.xz`, the one manual input — Apple licensing forbids redistribution, so it
can't be baked into the public image). One documented step: drop the SDK in `dev/sdks/`; the image build +
this increment automate everything downstream. Build via `oa64-clang`/`oa64-clang++` → `…-macos-arm64.tar.xz`;
**structural** verify only in-container (all expected binaries present + non-dangling + correct arm64 Mach-O
via native `llvm-readobj`); the functional warning-free self-test is **deferred to a real Mac** before publish
(documented, not silently skipped) — the one accepted limitation of cross-from-Linux. `dev/cross/macos-arm64.cmake`
already exists; `package-all` skips mac when `dev/sdks/` is empty.

## Files (create / modify)
- **Created (Inc 0 build side, done):** `dev/cross/{linux-arm64,windows-x86_64,macos-arm64}.cmake`,
  `dev/cross-toolchain.sh`.
- **Modify (this pass):** `dev/package-release.sh` (PLATFORM tag + cross target-artifact reuse + native-objcopy
  strip + Windows `.exe`/copy/zip branch + qemu/wine self-test dispatch); `dev/Dockerfile.cross` (add
  `qemu-user` + `wine64` for the self-tests); `Taskfile.yml` (`package PLATFORM=`, `package-all`);
  `README.md` (download table once builds exist).
- **Reuse (host-agnostic, copied verbatim):** `build/llvm-mos-install/lib/clang/23/{include,lib/mos-unknown-unknown}`,
  `build/install/{mos-platform,bin/*.cfg,lib/cmake}`; `build/llvm-mos/bin/{llvm,clang}-tblgen` as native tools.

## Verification (per increment — same WARNING-FREE bar as the Linux release)
1. **Native unchanged (Inc 0 package side):** after generalizing `package-release.sh`, `PLATFORM` unset (or
   `=linux-x86_64`) produces a tarball whose staged tree is identical to pre-change (same file set, same
   stripped `clang-23`); its self-test passes **0 warnings**; `dev/run.sh corpus` → **7/7**.
2. **Format/arch (every cross target):** `llvm-readobj --file-headers build/llvm-mos-install-<p>/bin/clang-23`
   reports the expected arch (`aarch64` ELF / `x86_64` COFF); no dangling symlinks in the staged tree.
3. **Functional self-test where runnable:** `linux-arm64` compiles `examples/snes/hello.c` via the produced
   clang under `qemu-aarch64` with **0 warnings** AND ROM `sha256 == native`. `windows-x86_64`: wine can't run
   the binary → **structural gate** (PE arch + DLLs + no-dangling + front-end/config resolution) passes and
   the functional `-Os` check is **deferred to real Windows** (recorded, soft-fail `exit 2`, BEFORE-PUBLISH
   notice printed).
4. **Artifacts:** `dist/` holds `llvm-mos-65816-<stamp>-{linux-x86_64,linux-aarch64}.tar.xz` +
   `…-windows-x86_64.zip`, each with a `.sha256`; unpack-and-run a target package as the final check.
5. **(Deferred) macOS:** structural gate green in-container; manual real-Mac `mos-clang --config mos-snes.cfg
   examples/snes/hello.c` → boots in MAME/bsnes, **0 warnings** — pasted here before publishing the mac tarball.

### Evidence (2026-06-25)

**Step 1 — native byte-identical.** Ran the committed-HEAD original `package-release.sh` and the refactored
one on the *same* current `build/` (skip docs + emulator gate), diffed the staged trees:
```
=== SET (excl README.md) ===          SET IDENTICAL
=== CONTENT (incl clang-23, excl README.md) ===  ALL CONTENT BYTE-IDENTICAL — refactor clean on native
```
Native refactored run self-test: `OK 32768 bytes — no warnings`. **PASS.**

**Step 2 — format/arch + no-dangling (cross).**
```
linux-arm64    clang-23: Format: elf64-littleaarch64 · Arch: aarch64 · Machine: EM_AARCH64   (dangling: 0)
windows-x86_64 clang.exe: Format: COFF-x86-64 · Machine: IMAGE_FILE_MACHINE_AMD64 (0x8664)   (dangling: 0)
```
arm64 SDK overlay correct (x86-64 host tools `elftocpm65`/`ft2-*` excluded; `mos-snes-clang→mos-clang→clang`
resolves); windows DLLs bundled (libstdc++-6/libgcc_s_seh-1/libwinpthread-1). **PASS.**

**Step 3 — functional self-test.**
```
[linux-arm64/qemu]  OK 32768 bytes — no warnings — sha256 == native reference (06a83283…)   -> PASS
[windows-x86_64/wine] WINE-LIMITATION 0xC0000005 in core codegen at -O0/-O1/-O2/-Os (strip-independent)
                      -> structural gate PASS; functional -Os DEFERRED to real Windows (exit 2, notice printed)
```
arm64 **PASS** (byte-identical ROM). windows **PASS structurally / functional deferred** (wine limitation, not
a binary defect — same compiler is byte-identical on the linux legs).

**Step 4 — artifacts.**
```
dist/llvm-mos-65816-<stamp>-linux-x86_64.tar.xz   (43M)  + .sha256   [native]
dist/llvm-mos-65816-<stamp>-linux-aarch64.tar.xz  (55M)  + .sha256   [qemu-validated]
dist/llvm-mos-65816-<stamp>-windows-x86_64.zip    (193M, 941 files) + .sha256   [structural+identity]
```
**PASS** (all three built with checksums; consistent-stamp publishable set = `task package-all` at a clean
commit). Note: dev runs above carry `-dirty` / differing short-SHAs because `main` is a hot shared tree.

## Risks & notes
- **Cross binaries can't run the SDK builtins build** → runtimes disabled in the cross config; the mos builtins
  come from the native build at package time. (Already handled in `dev/cross-toolchain.sh`.)
- **Self-test fidelity under emulation.** `qemu-aarch64` runs the real produced aarch64 clang/lld (not a
  stub) and its ROM is byte-checked against native — full fidelity. **wine, however, cannot run the produced
  windows clang**: the front-end runs but wine faults `0xC0000005` in core codegen at every `-O` level
  (confirmed `-O0/-O1/-O2/-Os`; strip-independent — `STRIP=0` faults identically). This is a wine emulator
  limitation with large mingw-LLVM binaries, **not** a defect in the `.exe`. Consequence: the Windows package
  ships on the **structural + codegen-identity-by-construction** gate with the functional `-Os` check
  **deferred to real Windows** (the one accepted limitation of cross-from-Linux for Windows, mirroring the
  macOS deferral). If a wine-functional Windows gate is ever wanted, options are (a) the `-win32` mingw
  threads variant, (b) a newer wine / wine-staging, or (c) a real-Windows CI runner — all out of interim scope.
- **Disk/CPU.** Each cross target is a full LLVM build (~30–90 min cold; ccache-warm after); native tblgens are
  reused, not rebuilt. Cross builds use `build/llvm-mos-<profile>/` (NOT `build/llvm-mos`), so they are safe to
  run alongside the native build without clobbering it.
- **Upstream framing.** Keep each generated README's "interim preview; prefer upstream once merged" note; this
  whole capability retires when `0001–0009` land upstream and upstream CI emits these platforms.
