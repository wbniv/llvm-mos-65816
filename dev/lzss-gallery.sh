#!/usr/bin/env bash
# Build and verify demo #119: the on-SNES LZSS compression/decompression gallery benchmark.
set -euo pipefail

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes-gallery.cfg"
SRC="$ROOT/examples/snes/lzss-gallery.c"
ROM="$BUILD/lzss-gallery.sfc"
MAP="$BUILD/lzss-gallery.map"
EXPECT=0x29AF

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: missing toolchain; run dev/run.sh build"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: missing snes-gallery SDK platform; run dev/run.sh build"; exit 1; }

echo "==> host codec oracle (-O0 and -O2)"
for opt in 0 2; do
  cc "-O$opt" -I"$ROOT/examples/65816" "$ROOT/tools/lzss-gallery-sim.c" \
    -o "$BUILD/lzss-gallery-sim-O$opt"
  : >"$BUILD/lzss-gallery-host-O$opt.txt"
  for frame in "$ROOT"/assets/snes/lzss-gallery/derived/*.idx; do
    printf '%s ' "$(basename "$frame")" >>"$BUILD/lzss-gallery-host-O$opt.txt"
    "$BUILD/lzss-gallery-sim-O$opt" "$frame" >>"$BUILD/lzss-gallery-host-O$opt.txt"
  done
done
cmp "$BUILD/lzss-gallery-host-O0.txt" "$BUILD/lzss-gallery-host-O2.txt"
cat "$BUILD/lzss-gallery-host-O2.txt"

echo "==> target build (+mos-a16, 512 KiB LoROM)"
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"
[ "$(stat -c %s "$ROM")" = 524288 ]

VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$MAP")
[ -n "$VMA" ]
OFF="0x$VMA"
echo "==> corpus_result @ WRAM $OFF; oracle $EXPECT"

if [ "${QUICK:-0}" = 1 ]; then
  FRAMES=1000
  CHECK_OFF=$(awk '$NF=="gallery_progress"{print $1; exit}' "$MAP")
  CHECK_WANT=0x00
  CHECK_LEN=1
  OUT="$BUILD/lzss-gallery-quick-jg.png"
else
  FRAMES="${FRAMES:-45000}"
  CHECK_OFF="$VMA"
  CHECK_WANT="$EXPECT"
  CHECK_LEN=2
  OUT="$BUILD/lzss-gallery-jg.png"
fi

JGX="$BUILD/jgxcheck"
if [ -x "$JGX" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  "$JGX" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$CHECK_OFF" "$CHECK_LEN" "$CHECK_WANT" "$FRAMES" "$OUT"
else
  echo "FATAL: bsnes-jg harness/core missing; run dev/run.sh xcheck"
  exit 1
fi

sha256sum "$ROM"
echo "RESULT: PASS — ten-work LZSS gallery host oracle, relink, header and bsnes-jg gate"
