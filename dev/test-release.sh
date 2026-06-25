#!/usr/bin/env bash
# dev/test-release.sh — clean-room test of the *published* 65816 SNES compiler.
#
# Builds a throwaway rig image (dev/Dockerfile.release-test: pinned bsnes-jg +
# jgxcheck + the host CRC oracle + the reference fixtures, NO toolchain) and runs it
# with NO repo mount, so the container can only ever see the *published* compiler —
# never this checkout's build/llvm-mos-install. Inside, it acquires mos-snes-clang,
# compiles the reference Mandelbrot (default-8bit + +mos-a16), runs each ROM headless
# in bsnes-jg (embedded SPC700 IPL → no BIOS, no sound), and asserts the WRAM CRC
# matches an independent host oracle. See docs/plans/2026-06-25-test-published-snes-compiler.md.
#
# This is also the PUBLISH GATE: dev/package-release.sh runs `METHOD=local` on the
# freshly-built tarball, so every `task package` is clean-room-verified before upload.
#
# Usage:  dev/test-release.sh [METHOD=local|apt|tarball] [A16=both|1|0]
#                             [PROGRAM=mandel-display|k_mandel] [TARBALL=<path>] [FRAMES=n]
# All knobs are environment variables (also accepted as KEY=VALUE arguments).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: dev/test-release.sh [KEY=VALUE ...]

Clean-room test the published llvm-mos-65816 SNES compiler in a throwaway container.

Knobs (env or KEY=VALUE args):
  METHOD   local | apt | tarball   where mos-snes-clang comes from        (default local)
             local   = the freshly-built dist/*.tar.xz (the publish gate; no live repo needed)
             apt     = apt install llvm-mos-65816 from the live apt.indri.studio
             tarball = scrape + download the product-page tarball link
  PROGRAM  mandel-display | k_mandel    reference program                 (default mandel-display)
  A16      both | 1 | 0                 which builds to test              (default both)
  TARBALL  <path>                       tarball for METHOD=local          (default: newest dist/*.tar.xz)
  FRAMES   <n>                          emulated frames before sampling   (default: per program)
  NO_CACHE 1                            docker build --no-cache (force a fresh rig image)

Examples:
  dev/test-release.sh                                  # gate the newest dist tarball
  METHOD=apt dev/test-release.sh                       # verify the LIVE apt repo
  METHOD=tarball PROGRAM=k_mandel dev/test-release.sh  # product-page link, fast gate grid
EOF
}

case "${1-}" in -h|--help) usage; exit 0;; esac
# Allow KEY=VALUE positional args (convenience; env still works).
for a in "$@"; do case "$a" in *=*) export "${a?}";; *) echo "unknown arg: $a" >&2; usage; exit 2;; esac; done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
METHOD="${METHOD:-local}"
PROGRAM="${PROGRAM:-mandel-display}"
A16="${A16:-both}"
IMAGE="${MOS_RELEASE_TEST_IMAGE:-llvm-mos-65816-release-test}"
OUTDIR="$ROOT/build/release-test"

command -v docker >/dev/null || { echo "FATAL: docker not found — the clean-room rig needs Docker." >&2; exit 1; }

# --- resolve the local tarball (METHOD=local) -------------------------------
RUN_ARGS=()
if [ "$METHOD" = local ]; then
  TARBALL="${TARBALL:-}"
  if [ -z "$TARBALL" ]; then
    TARBALL="$(ls -t "$ROOT"/dist/llvm-mos-65816-*-linux-x86_64.tar.xz 2>/dev/null | head -1 || true)"
  fi
  [ -n "$TARBALL" ] && [ -f "$TARBALL" ] || {
    echo "FATAL: METHOD=local needs a tarball — none found in dist/." >&2
    echo "  build one first:  task package    (or pass TARBALL=/path/to/...tar.xz)" >&2
    exit 1; }
  TARBALL="$(cd "$(dirname "$TARBALL")" && pwd)/$(basename "$TARBALL")"
  echo "==> METHOD=local — testing $(basename "$TARBALL")"
  RUN_ARGS+=(-v "$TARBALL":/artifact/src.tar.xz:ro)
fi

# --- build the rig image (cached; fixtures are the cheap final layers) -------
echo "==> building rig image $IMAGE (dev/Dockerfile.release-test)"
build_flags=()
[ "${NO_CACHE:-0}" = 1 ] && build_flags+=(--no-cache)
docker build "${build_flags[@]}" -t "$IMAGE" -f "$ROOT/dev/Dockerfile.release-test" "$ROOT" >/dev/null

mkdir -p "$OUTDIR"

# --- run the clean-room test (NO repo mount) --------------------------------
# Root in-container (apt install + /opt writes); the inner script chowns /out back.
# tee the container's (uncoloured, non-TTY) output to the compile-log artifact — it
# carries each build's exact mos-snes-clang command + compiler output. PIPESTATUS[0]
# preserves docker's exit code through the tee.
LOG="$OUTDIR/release-test-$METHOD.log"
echo "==> running clean-room test (transcript -> $LOG)"
docker run --rm \
  -e METHOD="$METHOD" -e PROGRAM="$PROGRAM" -e A16="$A16" \
  ${FRAMES:+-e FRAMES="$FRAMES"} \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  "${RUN_ARGS[@]}" \
  -v "$OUTDIR":/out \
  "$IMAGE" 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}

echo
echo "==> compile log : $LOG"
echo "==> screenshots : $(ls "$OUTDIR"/*.png 2>/dev/null | tr '\n' ' ')"
exit $rc
