#!/usr/bin/env bash
# dev/fetch-torture.sh — fetch + sha256-verify the GCC c-torture/execute suite.
#
# The GCC test suite is GPLv3; this repo is Apache-2.0-with-LLVM-exception, so we do
# NOT commit the test sources. This script reproduces them locally from a pinned,
# sha256-verified GCC release tarball into the gitignored vendor/c-torture/ tree —
# the same "fetch-don't-commit" model as dev/fetch-refs.sh (the WDC816CC/ORCA refs)
# and vendor/llvm-mos itself. Idempotent: re-runs skip the download when the cached
# tarball already matches the pin, and re-extract only if execute/ is missing.
#
# Used by tools/torture_filter.py (Phase 0 host-side filter) and, later, the
# differential runner. See docs/plans/2026-06-19-321-c-torture-execute-differential-suite.md.
set -euo pipefail

usage() { echo "Usage: dev/fetch-torture.sh [-h]   # fetch + sha256-verify the GCC c-torture/execute suite (gitignored)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HERE/../vendor/c-torture"

# Pinned GCC release. Bump VER + SHA256 together (compute the new hash with sha256sum).
VER="14.2.0"
URL="https://ftp.gnu.org/gnu/gcc/gcc-${VER}/gcc-${VER}.tar.xz"
SHA256="a7b39bc69cbf9e25826c5a60ab26477001f7c08d85cec04bc0e29cabed6f3cc9"
SUBDIR="gcc-${VER}/gcc/testsuite/gcc.c-torture/execute"

TARBALL="$DEST/gcc-${VER}.tar.xz"
mkdir -p "$DEST"

verify() { [ -f "$1" ] && [ "$(sha256sum "$1" | cut -d' ' -f1)" = "$SHA256" ]; }

if verify "$TARBALL"; then
  echo "==> tarball cached + verified (sha256 $SHA256)"
else
  echo "==> fetching gcc-${VER}.tar.xz (~90 MB) …"
  curl -fsSL --max-time 600 "$URL" -o "$TARBALL"
  got="$(sha256sum "$TARBALL" | cut -d' ' -f1)"
  if [ "$got" != "$SHA256" ]; then
    echo "    sha256 MISMATCH"
    echo "      want: $SHA256"
    echo "      got:  $got"
    echo "      -> the pin is stale or the download is corrupt; do NOT trust it."
    exit 1
  fi
  echo "    sha256 OK ($got)"
fi

if [ -d "$DEST/execute" ] && [ -n "$(ls -A "$DEST/execute"/*.c 2>/dev/null || true)" ]; then
  echo "==> execute/ already extracted ($(find "$DEST/execute" -name '*.c' | wc -l) .c files)"
else
  echo "==> extracting $SUBDIR …"
  tar --xz -xf "$TARBALL" -C "$DEST" "$SUBDIR"
  rm -rf "$DEST/execute"
  mv "$DEST/$SUBDIR" "$DEST/execute"
  rm -rf "$DEST/gcc-${VER}"
  echo "    extracted $(find "$DEST/execute" -name '*.c' | wc -l) .c files"
fi

echo "==> ready: $DEST/execute  (top-level: $(ls "$DEST/execute"/*.c | wc -l) tests)"
