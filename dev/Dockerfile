# Reproducible dev/build environment for the llvm-mos 65816 effort.
# Host stays clean — toolchain, build tools, and (later) an emulator live here.
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

ENV PATH=/opt/llvm-mos/bin:$PATH
WORKDIR /work
