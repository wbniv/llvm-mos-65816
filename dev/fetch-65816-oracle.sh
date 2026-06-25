#!/usr/bin/env bash
# dev/fetch-65816-oracle.sh — re-fetch the (CC0) 65c816 opcode-matrix datasheet used
# as the audit oracle for tools/gen-65816-ref.py, verify its sha256 against
# docs/refs/65816/SOURCES.md, and regenerate the committed normalised TSV.
#
# The raw datasheet is gitignored (kept lean); the normalised
# docs/refs/65816/oracle-65c816-opcodes.tsv it produces IS committed (CC0 facts).
set -euo pipefail

usage() { echo "Usage: dev/fetch-65816-oracle.sh [-h]   # fetch + sha256-verify the CC0 oracle, regen the TSV"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DEST="$ROOT/docs/refs/65816/oracle"
RAW="$DEST/65c816-datasheet.txt"
TSV="$ROOT/docs/refs/65816/oracle-65c816-opcodes.tsv"

URL="https://raw.githubusercontent.com/larsbrinkhoff/awesome-cpus/master/MCS6500/65c816.txt"
WANT="b2ba1db7f8a49eb575f0a444bb5d66af34e762999d0db2a00bff03e9993f0196"

mkdir -p "$DEST"
echo "fetch: $URL"
curl -fsSL "$URL" -o "$RAW"

GOT="$(sha256sum "$RAW" | cut -d' ' -f1)"
if [ "$GOT" != "$WANT" ]; then
  echo "WARN: sha256 mismatch (upstream changed?)"
  echo "  want $WANT"
  echo "  got  $GOT"
  echo "  -> review the new content, then update WANT here + SOURCES.md before trusting the audit"
  exit 1
fi
echo "sha256 OK: $GOT"

echo "regenerate: $TSV"
python3 "$ROOT/tools/gen-65816-oracle.py" "$RAW" > "$TSV"
echo "done: $(grep -vc '^#' "$TSV") opcodes"
