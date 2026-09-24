#!/usr/bin/env bash
# dev/lit.sh — refresh the lit tool set in build/llvm-mos, then run llvm-lit
# against the MOS lit suites (or the given paths).
#
# dev/toolchain.sh's "distribution" target installs clang+lld only — llc, opt,
# llvm-mc, llvm-objdump, llvm-readobj, FileCheck, not are NOT part of it, so a
# green toolchain rebuild can leave them stale and a lit run silently reads
# months-old codegen (see docs/agent-handoff.md SECOND GOTCHA; it produced a
# false 13-vs-9 failure count during the 0040 work). This target rebuilds
# exactly that tool set — same targets dev/toolchain.sh now refreshes on every
# `toolchain` run — then runs llvm-lit, so a lit reading is never taken against
# a stale tool.
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh lit [PATHS...].
# PATHS are relative to the repo root (/work inside the container); default is
# the two MOS suites. Needs `dev/run.sh toolchain` first (build/llvm-mos must
# already be configured — this does not run cmake configure).
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: dev/run.sh lit [PATHS...]
  Refresh llc/opt/llvm-mc/llvm-objdump/llvm-readobj/FileCheck/not in
  build/llvm-mos, then run build/llvm-mos/bin/llvm-lit -s against PATHS.
  PATHS are under the repo root (/work inside the container); default:
    vendor/llvm-mos/llvm/test/CodeGen/MOS
    vendor/llvm-mos/llvm/test/MC/MOS
  Needs `dev/run.sh toolchain` first.
USAGE
  exit 0
}
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
SRC="$ROOT/vendor/llvm-mos"
BUILDDIR="$ROOT/build/llvm-mos"
JOBS="${BUILD_JOBS:-6}"
export CCACHE_DIR="$ROOT/build/.ccache"
# See dev/toolchain.sh: put host /usr/bin first so this native build never
# resolves the mos cross toolchain that shadows it on the image PATH.
export PATH="/usr/bin:$PATH"

LIT="$BUILDDIR/bin/llvm-lit"
[ -e "$BUILDDIR/CMakeCache.txt" ] || {
  echo "FATAL: $BUILDDIR is not configured (run: dev/run.sh toolchain first)"; exit 1
}
[ -x "$LIT" ] || { echo "FATAL: no $LIT (run: dev/run.sh toolchain first)"; exit 1; }

# The tool set llvm/test/CodeGen/MOS + llvm/test/MC/MOS RUN lines actually
# invoke (checked by grepping the RUN lines, not guessed). llvm-lit itself is
# generated at configure time (a python script templated with the build's own
# paths), not a ninja target, so it needs no rebuild here.
echo "==> refresh the lit tool set in $BUILDDIR (-j$JOBS)"
cmake --build "$BUILDDIR" --target llc opt llvm-mc llvm-objdump llvm-readobj FileCheck not --parallel "$JOBS"

paths=()
if [ $# -gt 0 ]; then
  for p in "$@"; do
    case "$p" in
      /*) paths+=("$p") ;;
      *)  paths+=("$ROOT/$p") ;;
    esac
  done
else
  paths=("$SRC/llvm/test/CodeGen/MOS" "$SRC/llvm/test/MC/MOS")
fi

echo "==> llvm-lit -s ${paths[*]}"
rc=0
"$LIT" -s "${paths[@]}" || rc=$?
exit $rc
