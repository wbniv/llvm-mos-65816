#!/usr/bin/env bash
# dev/sync-platform.sh — refresh the fast-changing platform SOURCE files (C headers + the linker
# script) from platforms/<plat>/ into the already-built SDK install ($INSTALL/mos-platform/),
# so an edit to e.g. platforms/snes/snes.h is picked up by the very NEXT compile/link with no
# full `dev/run.sh build` re-vendor.
#
# Why this exists: these files are pure compile/link INPUTS — no library recompile is needed when
# they change. <snes.h> resolves to the INSTALLED copy (not platforms/snes/snes.h), so without
# this refresh a demo silently builds against a stale header (the bug this fixes). This is the
# SINGLE owner of that header/linker dependency: every script that compiles platform code calls
# it, so none can drift. (crt0.c and the CMake-built libs still require `dev/run.sh build`; that
# full path does the vendor + CMake install — see dev/build.sh.) Idempotent; self-locating, so a
# host-side caller works too (ROOT = the repo this script lives in).
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/sync-platform.sh   # refresh platform headers + link.ld into build/install"
  exit 0;; esac

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
INSTALL="${INSTALL:-$ROOT/build/install}"
[ -d "$INSTALL/mos-platform" ] || {
  echo "sync-platform: no SDK install at $INSTALL — run: dev/run.sh build" >&2; exit 1; }

n=0
for pdir in "$ROOT"/platforms/*/; do
  name="$(basename "$pdir")"
  dst="$INSTALL/mos-platform/$name"
  [ -d "$dst" ] || continue
  for h in "$pdir"*.h; do
    [ -e "$h" ] || continue
    cp -f "$h" "$dst/include/" && n=$((n + 1))
  done
  if [ -e "$pdir/link.ld" ] && [ -d "$dst/lib" ]; then
    cp -f "$pdir/link.ld" "$dst/lib/link.ld" && n=$((n + 1))
  fi
done
echo "sync-platform: refreshed $n file(s) into $INSTALL/mos-platform"
