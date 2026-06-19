#!/usr/bin/env bash
# dev/fetch-csmith.sh — fetch + build Csmith (BSD-2) into gitignored vendor/csmith (HOST-side).
#
# Csmith is the off-the-shelf random C generator that becomes the primary fuzzer generator
# (replacing the hand-rolled generator in tools/a16_fuzz.py — the engine/differential harness
# stays; the builtin generator stays selectable via `--gen builtin`). It runs HOST-side, like
# tools/torture_filter.py: the host has g++/cmake/m4 AND mame, so neither generation nor the
# differential run needs Docker. The generated programs are made UB-free *at the target's
# 16-bit int width* by examples/65816/csmith/platform.info (integer size = 2) + Csmith's
# type-parametric safe_math wrappers — the linchpin of the default-build-as-oracle differential.
# See docs/plans/2026-06-19-321-csmith-differential-fuzzer.md.
#
# Reproducibility: fetch-don't-commit (Csmith sources are gitignored under vendor/). The
# resolved commit is recorded in vendor/csmith/PINNED_SHA; pin a specific ref with
#   CSMITH_REF=<sha|tag> dev/fetch-csmith.sh
set -euo pipefail

usage() { echo "Usage: dev/fetch-csmith.sh [-h]   # clone+build Csmith into vendor/csmith (gitignored)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
DEST="$ROOT/vendor/csmith"
SRC="$DEST/src"
REPO="${CSMITH_REPO:-https://github.com/csmith-project/csmith.git}"
REF="${CSMITH_REF:-master}"
BIN="$DEST/bin/csmith"

if [ -x "$BIN" ]; then
  echo "==> csmith already built: $BIN  ($("$BIN" --version 2>/dev/null | head -1))"
  exit 0
fi

for t in git g++ cmake make m4; do
  command -v "$t" >/dev/null || { echo "FATAL: missing build tool '$t' (Csmith needs g++ + cmake + m4)"; exit 1; }
done

mkdir -p "$DEST"
if [ ! -d "$SRC/.git" ]; then
  echo "==> clone Csmith into vendor/csmith/src (gitignored)"
  git clone "$REPO" "$SRC"
fi
git -C "$SRC" fetch --tags --quiet || true
git -C "$SRC" checkout --quiet "$REF" 2>/dev/null || echo "    ('$REF' not a ref — using current $(git -C "$SRC" rev-parse --abbrev-ref HEAD))"
PINNED="$(git -C "$SRC" rev-parse HEAD)"
printf '%s\n' "$PINNED" > "$DEST/PINNED_SHA"
echo "    pinned Csmith @ $PINNED"

echo "==> configure + build (cmake, Release; -j$(nproc))"
cmake -S "$SRC" -B "$DEST/build" -DCMAKE_INSTALL_PREFIX="$DEST" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$DEST/build" -j"$(nproc)" >/dev/null
cmake --install "$DEST/build" >/dev/null

[ -x "$BIN" ] || { echo "FATAL: build finished but $BIN is missing"; exit 1; }
echo "==> built: $("$BIN" --version | head -1)"
echo "    runtime headers (the -I dir for generated TUs):"
find "$DEST" -name 'csmith.h' -o -name 'stdint_msp430.h' 2>/dev/null | sed 's/^/      /' || true
