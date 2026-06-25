# `dev/sdks/` — the one manual input for the macOS cross build

Cross-compiling the toolchain for **macOS arm64** (osxcross) needs Apple's macOS SDK.
Apple's license **forbids redistributing** it, so it can't be baked into the public image —
it's the single manual step in the whole cross-platform release (everything else is automated).

## What to drop here

A macOS SDK tarball named like **`MacOSX<version>.sdk.tar.xz`** (e.g. `MacOSX14.sdk.tar.xz`),
extracted from Xcode or the Command-Line-Tools **on a Mac**, per osxcross's instructions:

- Install Xcode (or `xcode-select --install` for the Command-Line-Tools) on any Mac.
- Run osxcross's `tools/gen_sdk_package.sh` (or `gen_sdk_package_pbzx.sh` for an `.xip`) — it
  emits `MacOSX<version>.sdk.tar.xz`.
- Copy that file into this directory.

See the [osxcross README](https://github.com/tpoechtrager/osxcross#packaging-the-sdk).

## What happens then

`dev/Dockerfile.cross`'s osxcross layer (added in Increment 3) consumes the SDK from here and
builds the arm64 wrapper compilers; `dev/run.sh cross-toolchain macos-arm64` then cross-builds
the host binaries. Without an SDK here, `task package-all` builds the other three platforms and
**skips macOS with a notice** — it never hard-fails.

> The macOS package's functional warning-free self-test can't run on x86-64 Linux (no Mach-O
> emulation); it's verified on real Mac hardware before that tarball is published — see the plan's
> Verification §4.

This directory is tracked (so the path/instructions exist), but **SDK tarballs are gitignored** —
never commit Apple's SDK.
