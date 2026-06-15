#!/usr/bin/env bash
# dev/fetch-refs.sh — re-fetch the vendored reference docs for the 65816 C ABI
# prior-art note and verify them against the sha256 in
# docs/refs/65816-c-abi/SOURCES.md.
#
# These docs are redistribution-restricted (copyrighted WDC manual; ORCA/C
# source-available-not-redistributable), so they are gitignored — this script
# is how a fresh checkout reproduces them locally. See SOURCES.md for licenses.
set -euo pipefail

usage() { echo "Usage: dev/fetch-refs.sh [-h]   # fetch + sha256-verify the vendored 65816 C ABI refs"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HERE/../docs/refs/65816-c-abi"
mkdir -p "$DEST"

# name|url|sha256  (sha256 mirrors docs/refs/65816-c-abi/SOURCES.md)
REFS=(
  "816cc.pdf|https://www.westerndesigncenter.com/wdc/documentation/816cc.pdf|1924c3669279834e64ffcc7b06d6aae5f01bcf3dbfce2d98e450f30440afe56c"
  "ORCA-C-Gen.pas|https://raw.githubusercontent.com/byteworksinc/ORCA-C/master/Gen.pas|924e5760851bc8d72f7dae06544cd773a06d59aa518fead76fc5aa573685cd7d"
)

rc=0
for ref in "${REFS[@]}"; do
  IFS='|' read -r name url want <<<"$ref"
  echo "==> fetch $name"
  curl -fsSL "$url" -o "$DEST/$name"
  got="$(sha256sum "$DEST/$name" | cut -d' ' -f1)"
  if [ "$got" = "$want" ]; then
    echo "    sha256 OK ($got)"
  else
    echo "    sha256 MISMATCH for $name"
    echo "      want: $want"
    echo "      got:  $got"
    echo "      -> upstream changed; update SOURCES.md + re-verify the citations in"
    echo "         docs/320-321-65816-c-abi-prior-art.md before trusting them."
    rc=1
  fi
done
exit $rc
