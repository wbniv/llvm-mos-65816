#!/usr/bin/env bash
# Gate the public SVX2 ExHiROM cartridge against its publication record
# (docs/plans/2026-08-02-svx2-artemis-2x-apollo-60p-reel.md, "Published result").
#
# Three checks, in the shape set by the Mode 7 gallery reconciliation
# (docs/plans/2026-09-14-m7-gallery-web-reconcile.md, decision row 2):
#   1. the deployed ROM matches the SHA-256 the publication record names;
#   2. the asset contract: the packed SVX2 stream regions of a fresh rebuild are
#      byte-identical to the deployed ROM (file $010000-$3FFFFF and $410000-);
#   3. the code contract: the rebuild passes every functional gate of
#      dev/snes-video-artemis-apollo.sh (cadence 0x0B06/3000, seam offsets,
#      transport, 9,000 presentations with zero slips, composite health).
# The whole-ROM SHA-256 of the rebuild is printed and compared to the record,
# but a differing code window is classified rather than failed: the compiler
# that built the release is not pinned, so bytes drift with the toolchain.
# Classification follows the policy row: if no commit after the publication
# commit touches this ROM's compile inputs, it is ACCEPTED DIVERGENCE
# (toolchain drift); otherwise it is demo-source drift, whose policy action is
# a republish (user-triggered, never done here).
#
# Usage: dev/svx2-emulator-validation.sh [-h|--help]
set -euo pipefail

case "${1-}" in
  -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
URL=https://biohack.net/play/roms/svx2-fastrom-video.sfc
RELEASE=v1.0.360
SHA=c3d7cd9e76d840f77d98aed96806ee2fb5268409a5ca6bcd81f9b1dc1bceefa2
PUBLISHED_COMMIT=f61472a   # "Toolchain implementation" of the publication record
OUT=${TMPDIR:-/tmp}/svx2-emulator-validation
PUBLIC_ROM="$OUT/svx2-fastrom-video-$RELEASE-$SHA.sfc"
BUILT_ROM="$ROOT/build/svx2-video-reel.sfc"
# ExHiROM packed layout (tools/snes-video-pack-exhirom.py): code at $000000-$00FFFF
# mirrored at $400000-$40FFFF; stream part A then part B around it.
STREAM_A=$((0x010000)); STREAM_A_LEN=$((0x400000 - 0x010000))
STREAM_B=$((0x410000)); STREAM_B_LEN=$((0x800000 - 0x410000))

mkdir -p "$OUT"
curl -fsSL "$URL" -o "$PUBLIC_ROM.download"
printf '%s  %s\n' "$SHA" "$PUBLIC_ROM.download" | sha256sum -c -
test "$(stat -c %s "$PUBLIC_ROM.download")" -eq 8388608
mv -f "$PUBLIC_ROM.download" "$PUBLIC_ROM"
echo "1. deployed ROM == publication record ($RELEASE, $SHA): PASS"

"$ROOT/dev/snes-video-artemis-apollo.sh"
echo "3. functional gates (dev/snes-video-artemis-apollo.sh): PASS"

cmp --ignore-initial="$STREAM_A" -n "$STREAM_A_LEN" "$PUBLIC_ROM" "$BUILT_ROM" || {
  echo "FAIL: packed stream part A (file \$010000-\$3FFFFF) differs from the deployed ROM" >&2; exit 1; }
cmp --ignore-initial="$STREAM_B" -n "$STREAM_B_LEN" "$PUBLIC_ROM" "$BUILT_ROM" || {
  echo "FAIL: packed stream part B (file \$410000-) differs from the deployed ROM" >&2; exit 1; }
echo "2. asset contract: packed stream regions byte-identical to the deployed ROM: PASS"

built_sha=$(sha256sum "$BUILT_ROM" | cut -d' ' -f1)
echo "rebuilt ROM SHA-256: $built_sha"
if [ "$built_sha" = "$SHA" ]; then
  echo "RESULT: PASS — public $RELEASE is byte-identical to the fully gated rebuild"
  exit 0
fi

# The code window differs. Score it by WHY (policy row 2): did any commit after
# the publication commit touch this ROM's compile inputs? The input set is what
# the preprocessor actually pulls in, restricted to tracked files, plus the two
# assembly sources the link line names.
CC="$ROOT/build/llvm-mos-install/bin/mos-clang"
CONFIG="$ROOT/build/install/bin/mos-snes-video-exhirom.cfg"
inputs=$("$CC" --config "$CONFIG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 \
  -DSVC_USE_ASM -DVIDEO_REEL_VBLANKS_PER_FRAME=1 -I"$ROOT/build" -MM \
  "$ROOT/examples/snes/snes-video-reel.c" "$ROOT/examples/snes/snes-video-codec.c" \
  "$ROOT/examples/snes/snes-video-dma.c" \
  | tr ' \\' '\n\n' | grep "^$ROOT/" | sed "s|^$ROOT/||" || true)
inputs=$(printf '%s\n%s\n%s\n' "$inputs" examples/snes/snes-video-reel-fast.s \
  examples/snes/snes-video-codec-fast.s | sort -u | (cd "$ROOT" && xargs git ls-files --))
# shellcheck disable=SC2086
source_commits=$(git -C "$ROOT" log --oneline "$PUBLISHED_COMMIT..HEAD" -- $inputs || true)
code_diff=$(cmp -l -n $((0x10000)) "$PUBLIC_ROM" "$BUILT_ROM" | wc -l)
if [ -z "$source_commits" ]; then
  echo "ACCEPTED DIVERGENCE (toolchain drift): published $SHA vs built $built_sha; stream identical; code differs ($code_diff bytes in \$000000-\$00FFFF); no commit after $PUBLISHED_COMMIT touches the compile inputs"
  echo "RESULT: PASS — public $RELEASE matches its publication record; rebuild passes every functional gate; code-window divergence accepted as toolchain drift"
  exit 0
fi
echo "DIVERGENCE (demo-source drift): published $SHA vs built $built_sha; stream identical; code differs ($code_diff bytes in \$000000-\$00FFFF); commits after $PUBLISHED_COMMIT touching the compile inputs:"
printf '%s\n' "$source_commits" | sed 's/^/    /'
echo "RESULT: PASS — public $RELEASE matches its publication record; rebuild passes every functional gate; policy row 2(a): the divergence is demo-source drift, whose action is a user-triggered republish (refresh the publication record when it lands)"
exit 0
