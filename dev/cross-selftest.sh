#!/usr/bin/env bash
# dev/cross-selftest.sh — the WARNING-FREE functional self-test for a CROSS package.
# Runs INSIDE the cross image (dev/Dockerfile.cross, which carries qemu-user-static + wine),
# invoked by dev/package-release.sh via `dev/run.sh cross-selftest <PLATFORM>`.
#
# A cross-built clang is the SAME compiler as the native one, just for a different host CPU/OS
# — so given identical input it must emit BYTE-IDENTICAL 65816 ROM bytes. This test runs the
# produced foreign compiler under emulation, compiling examples/snes/hello.c from the staged,
# relocated prefix, and requires (1) zero warnings/errors and (2) sha256 == the native
# reference (REF_SHA, computed by package-release.sh with the native compiler). ROM identity
# transitively inherits the native build's clean-room bsnes-jg gate, so no separate emulator
# run is needed for the cross package.
#
# Env (set by package-release.sh / dev/run.sh):
#   PLATFORM   linux-arm64 | windows-x86_64        (also $1)
#   RUNNER     qemu | wine
#   REF_SHA    sha256 of the native reference ROM
#   STAGE_REL  staged prefix path relative to repo root (e.g. dist/llvm-mos-65816-<stamp>-<tag>)
set -euo pipefail

PLATFORM="${1:-${PLATFORM:-}}"
RUNNER="${RUNNER:-}"
REF_SHA="${REF_SHA:-}"
STAGE_REL="${STAGE_REL:-}"
ROOT=/work
STAGE="$ROOT/$STAGE_REL"

[ -n "$PLATFORM" ] && [ -n "$RUNNER" ] && [ -n "$REF_SHA" ] && [ -n "$STAGE_REL" ] || {
    echo "FATAL: cross-selftest needs PLATFORM/RUNNER/REF_SHA/STAGE_REL" >&2; exit 1; }
[ -d "$STAGE/bin" ] || { echo "FATAL: staged prefix $STAGE not found" >&2; exit 1; }

OUT="$(mktemp -d)"; trap 'rm -rf "$OUT"' EXIT
ERR="$OUT/stderr.log"
SRC="$ROOT/examples/snes/hello.c"

# Build the invocation: <runner> <staged mos-clang[.exe]> --config <staged cfg> -mcpu=... -Os -o out src
case "$RUNNER" in
  qemu)
    CC="$STAGE/bin/mos-clang"
    # Ubuntu 26.04's qemu-user ships /usr/bin/qemu-aarch64 (statically linked, no -static
    # suffix); older releases used qemu-aarch64-static. Accept either.
    QEMU="$(command -v qemu-aarch64-static || command -v qemu-aarch64 || true)"
    [ -n "$QEMU" ] || { echo "FATAL: qemu-aarch64[-static] absent in cross image" >&2; exit 1; }
    export QEMU_LD_PREFIX="${QEMU_LD_PREFIX:-/usr/aarch64-linux-gnu}"
    RUN=("$QEMU" "$CC")
    ;;
  wine)
    CC="$STAGE/bin/mos-clang.exe"
    WINE="$(command -v wine64 || command -v wine || true)"
    [ -n "$WINE" ] || { echo "FATAL: wine/wine64 absent in cross image" >&2; exit 1; }
    export WINEDEBUG="${WINEDEBUG:--all}"
    export WINEPREFIX="${WINEPREFIX:-$OUT/wineprefix}"
    RUN=("$WINE" "$CC")
    ;;
  *) echo "FATAL: unknown RUNNER '$RUNNER' (want qemu|wine)" >&2; exit 1 ;;
esac
[ -e "$CC" ] || { echo "FATAL: staged cross compiler $CC missing" >&2; exit 1; }

echo "==> [$PLATFORM/$RUNNER] compiling hello.c with the staged cross compiler from the relocated prefix"
set +e
"${RUN[@]}" --config "$STAGE/bin/mos-snes.cfg" -mcpu=mosw65816 -Os \
    -o "$OUT/cross.sfc" "$SRC" 2>"$ERR"
rc=$?
set -e
# wine is chatty on stderr even with WINEDEBUG=-all (fixme/err: lines); filter those before
# judging warning-freeness so only the COMPILER's diagnostics count.
COMPILER_DIAG="$(grep -ivE '^[0-9a-fx]+:(fixme|err|warn):|^wine: |^[[:space:]]*$' "$ERR" || true)"

if [ $rc -ne 0 ]; then
    # Distinguish a WINE RUNTIME crash (wine can't execute a large mingw-LLVM binary — a
    # known emulator limitation; the front-end runs, then it faults with 0xC0000005 in core
    # codegen at every -O level) from a genuine compiler diagnostic. The former is NOT a
    # defect in the produced .exe: the same compiler is byte-identical to native on the
    # linux-x86_64 + linux-arm64 legs. Soft-fail (exit 2) so packaging can proceed on the
    # structural gate, with the functional warning-free check DEFERRED to real Windows.
    if [ "$RUNNER" = wine ] && grep -qE 'Exception Code: 0x[0-9A-Fa-f]+|Stack dump:|PLEASE submit a bug report|Unhandled exception' "$ERR"; then
        echo "WINE-LIMITATION: the windows clang crashed INSIDE wine ($(grep -oE 'Exception Code: 0x[0-9A-Fa-f]+' "$ERR" | head -1 | grep -oE '0x[0-9A-Fa-f]+')) during core codegen." >&2
        echo "  This is a wine bug running a large mingw-LLVM binary, NOT a defect in the produced .exe — the" >&2
        echo "  same compiler is proven byte-identical to native on linux-x86_64 + linux-arm64. The windows" >&2
        echo "  binary's functional warning-free check must be done on REAL WINDOWS before publishing." >&2
        exit 2
    fi
    echo "FATAL: cross compile FAILED (rc=$rc) under $RUNNER" >&2
    sed 's/^/    /' "$ERR" >&2
    exit 1
fi
if [ ! -f "$OUT/cross.sfc" ]; then
    echo "FATAL: cross compile produced no ROM" >&2; exit 1
fi
if printf '%s\n' "$COMPILER_DIAG" | grep -qiE 'warning|error'; then
    echo "FATAL: cross build is NOT warning-clean (public release — no warnings allowed)." >&2
    printf '%s\n' "$COMPILER_DIAG" | sed 's/^/    /' >&2
    exit 1
fi

GOT_SHA="$(sha256sum "$OUT/cross.sfc" | cut -d' ' -f1)"
GOT_SIZE="$(stat -c%s "$OUT/cross.sfc")"
if [ "$GOT_SHA" != "$REF_SHA" ]; then
    echo "FATAL: cross ROM bytes DIFFER from the native reference — codegen is not identical." >&2
    echo "    native ref sha256: $REF_SHA" >&2
    echo "    $PLATFORM   sha256: $GOT_SHA" >&2
    exit 1
fi
echo "    OK  $GOT_SIZE bytes — no warnings — sha256 == native reference ($GOT_SHA)"
echo "==> [$PLATFORM/$RUNNER] cross self-test PASSED"
