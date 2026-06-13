# Reproducible dev/build environment for the llvm-mos 65816 effort.
# Host stays clean — toolchain, build tools, and the emulator live here.
#
# Base: Ubuntu 26.04 (foundry default). Toolchain: llvm-mos prebuilt rolling
# release `llvm-mos-linux-main` (clang 23.0.0git @ c798c314, as of 2026-04-23).
FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake ninja-build python3 python3-pip \
      git curl ca-certificates xz-utils xxd \
    && rm -rf /var/lib/apt/lists/*

# Prebuilt llvm-mos toolchain (clang/lld/compiler-rt for target mos) → /opt/llvm-mos.
RUN curl -fsSL https://github.com/llvm-mos/llvm-mos/releases/download/llvm-mos-linux-main/llvm-mos-linux-main.tar.xz \
      | tar -xJ -C /opt \
    && /opt/llvm-mos/bin/mos-clang --version

# Emulator for the M0 smoke loop: MAME's `snes` driver, driven headless via a Lua
# autoboot script (dev/smoke.lua). Same emulation core drdevtools' drmon debugs
# against, so green-in-CI == attachable-in-drmon. Last (and own) layer: it is the
# heaviest/most-likely-to-bump install, so keeping it after the toolchain means a
# MAME version bump never re-downloads the toolchain. Debian installs the binary to
# /usr/games (not on the default non-login PATH) — added to PATH below. Version is
# recorded by the smoke run (`mame -version`); the Lua memory API is stable across
# recent MAME. The snes driver also needs the SPC700 IPL ROM at runtime — supplied
# out-of-band via -rompath (gitignored), never baked into the image. See dev/smoke.sh.
RUN apt-get update && apt-get install -y --no-install-recommends \
      mame \
    && rm -rf /var/lib/apt/lists/*

ENV PATH=/opt/llvm-mos/bin:/usr/games:$PATH
WORKDIR /work
