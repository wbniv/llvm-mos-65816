#!/usr/bin/env bash
# dev/corpus.sh — run the M0 regression corpus headless in MAME.
#
# For each row of examples/snes/corpus/expected.tsv, assert the program's result symbol
# (read from the prebuilt build/<name>.map + .sfc, at the byte length the map records)
# against the manifest's expected value. Prints a table + "N/N passed"; exits nonzero if
# any program fails. Runs INSIDE the dev container; drive from host: dev/run.sh corpus.
# Build first (dev/run.sh build) so the ROMs + maps exist.
set -euo pipefail

usage() { echo "Usage: dev/run.sh corpus   # assert every examples/snes/corpus/*.c vs expected.tsv"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
. "$ROOT/dev/_emu.sh"

MANIFEST="$ROOT/examples/snes/corpus/expected.tsv"
BUILD="$ROOT/build"
[ -f "$MANIFEST" ] || { echo "no manifest: $MANIFEST"; exit 1; }

require_bios || exit $?

echo "==> MAME version: $(mame -version 2>/dev/null | head -1 || echo '?')"
echo "==> corpus: $(basename "$MANIFEST")"

pass=0; fail=0; total=0
# `desc` soaks up the rest of each line (may contain spaces); the `|| [ -n … ]` guard
# handles a final line with no trailing newline.
while read -r cfile symbol expected desc || [ -n "${cfile:-}" ]; do
  case "${cfile:-}" in ''|\#*) continue ;; esac     # skip blanks + comments
  total=$((total + 1))
  name="$(basename "$cfile" .c)"
  rom="$BUILD/$name.sfc"
  map="$BUILD/$name.map"

  if [ ! -f "$rom" ] || [ ! -f "$map" ]; then
    printf '  %-10s FAIL  (missing %s — run dev/run.sh build first)\n' "$name" "$(basename "$rom")"
    fail=$((fail + 1)); continue
  fi

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
