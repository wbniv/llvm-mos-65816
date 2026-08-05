#!/usr/bin/env bash
# Record a natural-source pass only after the demo's own differential gates succeed.
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SLUG=${1:?usage: write-natural-rom-receipt.sh SLUG ROM}
ROM=${2:?usage: write-natural-rom-receipt.sh SLUG ROM}
CONTRACT="$ROOT/dev/natural-rom-contracts/$SLUG.contract"
RECEIPT="$ROOT/build/$SLUG.natural-pass"

[ -f "$CONTRACT" ] || { echo "FATAL: no natural-source contract for $SLUG" >&2; exit 1; }
[ -f "$ROM" ] || { echo "FATAL: ROM not found: $ROM" >&2; exit 1; }
source_rel=$(awk -F= '$1 == "source" { print substr($0, index($0, "=") + 1); exit }' "$CONTRACT")
evidence=$(awk -F= '$1 == "evidence" { print substr($0, index($0, "=") + 1); exit }' "$CONTRACT")
[ -n "$source_rel" ] && [ -n "$evidence" ] || { echo "FATAL: incomplete contract: $CONTRACT" >&2; exit 1; }
[ -f "$ROOT/$source_rel" ] || { echo "FATAL: contracted source not found: $source_rel" >&2; exit 1; }

tmp=$(mktemp "$ROOT/build/$SLUG.natural-pass.XXXXXX")
trap 'rm -f "$tmp"' EXIT
{
  echo "slug=$SLUG"
  echo "status=NATURAL_PASS"
  echo "rom_sha256=$(sha256sum "$ROM" | cut -d' ' -f1)"
  echo "source=$source_rel"
  echo "source_sha256=$(sha256sum "$ROOT/$source_rel" | cut -d' ' -f1)"
  echo "contract_sha256=$(sha256sum "$CONTRACT" | cut -d' ' -f1)"
  echo "evidence=$evidence"
} > "$tmp"
mv "$tmp" "$RECEIPT"
trap - EXIT
echo "NATURAL RECEIPT: $RECEIPT"
