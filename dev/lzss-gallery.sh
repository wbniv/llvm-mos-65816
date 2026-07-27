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
EXPECT=$(python3 -c 'import json
r=json.load(open("/work/assets/snes/lzss-gallery/derived/report.json"));h=0xffff
for a in r:
  for x in (a["checksum"]&255,a["checksum"]>>8,a["compressed_bytes"]&255,a["compressed_bytes"]>>8):
    h=(((h<<1)|(h>>15))&65535)^x
print(f"0x{h:04X}")')
WORKS=$(python3 -c 'import json; print(len(json.load(open("/work/assets/snes/lzss-gallery/derived/report.json"))))')

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

echo "==> target build (+mos-a16, 1 MiB LoROM)"
EXTRA_DEFS=()
if [ -n "${GALLERY_RUN_COLOR:-}" ]; then
  EXTRA_DEFS+=("-DGALLERY_RUN_COLOR=$GALLERY_RUN_COLOR")
fi
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Oz \
  -DGALLERY_START="${GALLERY_START:-0}" \
  "${EXTRA_DEFS[@]}" \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"
[ "$(stat -c %s "$ROM")" = 1048576 ]
# The MOS assembler currently neither diagnoses a resolved wrapped PCRel8
# fixup nor tracks 65816 M width through REP/SEP. Fail this build if the NMI's
# deliberately safe branch-over-JMP or explicit ADC #$0010 encoding regresses.
NMI_VMA=$(awk '$NF=="nmi"{print $1; exit}' "$MAP")
python3 - "$ROM" "$NMI_VMA" <<'PY'
from pathlib import Path
import sys
rom = Path(sys.argv[1]).read_bytes()
start = int(sys.argv[2], 16) & 0x7fff
nmi = rom[start:start + 0x400]
required = {
    "branch-over-JMP": bytes.fromhex("d0 03 4c"),
    "16-bit ADC #$0010": bytes.fromhex("69 10 00"),
}
missing = [name for name, opcode in required.items() if opcode not in nmi]
if missing:
    raise SystemExit("FATAL: NMI opcode audit failed: missing " + ", ".join(missing))
if bytes.fromhex("f0 a2") in nmi:
    raise SystemExit("FATAL: NMI opcode audit found the formerly wrapped BEQ")
print("NMI opcode audit: PASS (long conditional and 16-bit immediate are explicit)")
PY
python3 "$ROOT/tools/snes-rom-map.py" "$MAP" \
  "$ROOT/assets/snes/lzss-gallery/derived/report.json" \
  "$ROOT/assets/snes/lzss-gallery/derived/rom-map.md"

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
  FRAMES="${FRAMES:-150000}"
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
echo "RESULT: PASS — $WORKS-work LZSS gallery host oracle, relink, header and bsnes-jg gate"
