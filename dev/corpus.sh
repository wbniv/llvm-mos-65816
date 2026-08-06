#!/usr/bin/env bash
# dev/corpus.sh — run the M0 regression corpus headless in MAME.
#
# For each row of examples/snes/corpus/expected.tsv, assert the program's result symbol
# (read from build/<name>.map + .sfc, at the byte length the map records)
# against the manifest's expected value. Prints a table + "N/N passed"; exits nonzero if
# any program fails. Runs INSIDE the dev container; drive from host: dev/run.sh corpus.
# The gate rebuilds exactly the manifest rows before execution, so missing or stale
# corpus artifacts cannot turn the runtime result into a prior-build accident.
set -euo pipefail

usage() { echo "Usage: dev/run.sh corpus   # assert every examples/snes/corpus/*.c vs expected.tsv"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
# shellcheck disable=SC1091 # container-absolute shared helper
. "$ROOT/dev/_emu.sh"

MANIFEST="$ROOT/examples/snes/corpus/expected.tsv"
BUILD="$ROOT/build"
if [ -z "${MOS_TOOLCHAIN:-}" ]; then
  if [ -x "$BUILD/llvm-mos-install/bin/mos-clang" ]; then MOS_TOOLCHAIN="$BUILD/llvm-mos-install"
  else MOS_TOOLCHAIN=/opt/llvm-mos; fi
fi
MOS_CLANG="$MOS_TOOLCHAIN/bin/mos-clang"
CFG="$BUILD/install/bin/mos-snes.cfg"
[ -f "$MANIFEST" ] || { echo "no manifest: $MANIFEST"; exit 1; }
[ -x "$MOS_CLANG" ] || { echo "FATAL: no compiler at $MOS_CLANG"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK config missing: $CFG (run dev/run.sh build)"; exit 1; }

require_bios || exit $?

# Match the already-proven corpus-a16 budget. MAME is unthrottled, so the
# generous uniform bound is cheaper and less fragile than a per-row timeout table.
export SMOKE_SETTLE="${SMOKE_SETTLE:-1000}"
export SMOKE_SECONDS="${SMOKE_SECONDS:-20}"

echo "==> MAME version: $(mame -version 2>/dev/null | head -1 || echo '?')"
echo "==> corpus: build $(basename "$MANIFEST") with $MOS_CLANG"

# Build every manifest row, including hello.c. This is intentionally scoped to
# the manifest rather than invoking the all-examples SDK build.
while read -r cfile symbol expected desc || [ -n "${cfile:-}" ]; do
  case "${cfile:-}" in ''|\#*) continue ;; esac
  src="$ROOT/examples/snes/$cfile"
  name="$(basename "$cfile" .c)"
  rom="$BUILD/$name.sfc"
  map="$BUILD/$name.map"
  [ -f "$src" ] || { echo "FATAL: manifest source missing: $src"; exit 1; }
  if ! "$MOS_CLANG" --config "$CFG" -Os -Wl,-Map="$map" -o "$rom" "$src"; then
    echo "FATAL: corpus build failed: $cfile"
    exit 1
  fi
  if ! python3 "$ROOT/tools/snes-checksum.py" "$rom" >/dev/null; then
    echo "FATAL: corpus checksum failed: $cfile"
    exit 1
  fi
  printf '  %-18s built\n' "$name"
done < "$MANIFEST"

echo "==> corpus: run $(basename "$MANIFEST") (MAME settle=$SMOKE_SETTLE, backstop=${SMOKE_SECONDS}s)"

pass=0; fail=0; total=0
# `desc` soaks up the rest of each line (may contain spaces); the `|| [ -n … ]` guard
# handles a final line with no trailing newline.
while read -r cfile symbol expected desc || [ -n "${cfile:-}" ]; do
  case "${cfile:-}" in ''|\#*) continue ;; esac     # skip blanks + comments
  total=$((total + 1))
  name="$(basename "$cfile" .c)"
  rom="$BUILD/$name.sfc"
  map="$BUILD/$name.map"

  if line="$(run_assert "$rom" "$map" "$symbol" "$expected")"; then
    printf '  %-10s PASS  %s=%s  %s\n' "$name" "$symbol" "$expected" "$desc"
    pass=$((pass + 1))
  else
    printf '  %-10s FAIL  %s\n' "$name" "$line"
    fail=$((fail + 1))
  fi
done < "$MANIFEST"

echo "==> corpus: $pass/$total passed"
[ "$fail" -eq 0 ]
