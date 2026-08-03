#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
URL=https://biohack.net/play/roms/svx2-fastrom-video.sfc
RELEASE=v1.0.360
SHA=c3d7cd9e76d840f77d98aed96806ee2fb5268409a5ca6bcd81f9b1dc1bceefa2
OUT=${TMPDIR:-/tmp}/svx2-emulator-validation
PUBLIC_ROM="$OUT/svx2-fastrom-video-$RELEASE-$SHA.sfc"

mkdir -p "$OUT"
curl -fsSL "$URL" -o "$PUBLIC_ROM.download"
printf '%s  %s\n' "$SHA" "$PUBLIC_ROM.download" | sha256sum -c -
test "$(stat -c %s "$PUBLIC_ROM.download")" -eq 8388608
mv -f "$PUBLIC_ROM.download" "$PUBLIC_ROM"

"$ROOT/dev/snes-video-artemis-apollo.sh"
printf '%s  %s\n' "$SHA" "$ROOT/build/svx2-video-reel.sfc" | sha256sum -c -
cmp "$PUBLIC_ROM" "$ROOT/build/svx2-video-reel.sfc"

echo "RESULT: PASS — public v1.0.360 is byte-identical to the fully gated bsnes-jg build"
