#!/usr/bin/env bash
# FAST host-side repro of the default-8bit 65816 matrix-fold-LOOP miscompile.
# NEW finding (2026-06-25): it reproduces in *sd* mode (snes platform, single-bank)
# entirely host-side in ~10 s — the prior investigation believed it needed the full
# hd multi-bank demo + the Docker container. This makes cvise reduction tractable.
#
# Prereqs (all already in the main checkout): build/llvm-mos-install (toolchain),
# build/install (SNES SDK / mos-snes.cfg), vendor/bsnes-jg (core + Database).
# Usage: loopfold-repro.sh [loop|unroll]   (default loop = the FAILING form)
set -euo pipefail
FORM="${1:-loop}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLANG="$ROOT/build/llvm-mos-install/bin/mos-clang"
CFG="$ROOT/build/install/bin/mos-snes.cfg"
DB="$ROOT/vendor/bsnes-jg/Database"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

# 1. sources (scratch copy so the tracked tree is untouched)
mkdir -p "$W/snes" "$W/65816"
cp "$ROOT"/examples/snes/{mandel-zoom.c,zoom.h,mode7.h} "$W/snes/"
cp "$ROOT"/examples/65816/*.h "$W/65816/"
# bake the sd pyramid header (64x64x6, single-bank)
cc -O2 -I "$ROOT/examples/65816" -I "$ROOT/tools" "$ROOT/tools/mandel-bake-pyramid.c" -o "$W/bake" -lm
EXPECT="$(PYR_MULTIBANK=0 "$W/bake" "$W/snes/pyramid_image.h" 64 64 6 32 "$W/pyr" | awk '/level 0:/{for(i=1;i<=NF;i++)if($i~/^hash=/){sub(/hash=/,"",$i);print $i}}')"

# 2. select the fold form
if [ "$FORM" = loop ]; then
  python3 - "$W/snes/zoom.h" <<'PY'
import sys
p=sys.argv[1]; t=open(p).read()
blk="".join('  crc = zoom_crc16_byte(crc, (uint8_t)m[%d]);\n  crc = zoom_crc16_byte(crc, (uint8_t)((uint16_t)m[%d] >> 8));\n'%(i,i) for i in range(4))
loop="  for (int i = 0; i < 4; i++) {\n    crc = zoom_crc16_byte(crc, (uint8_t)m[i]);\n    crc = zoom_crc16_byte(crc, (uint8_t)((uint16_t)m[i] >> 8));\n  }\n"
assert blk in t; open(p,"w").write(t.replace(blk,loop))
PY
fi

# 3. build the zoom harness (host-side; replays zoom.h over the ROM pad log) + the ROM
ARCHIVE="$(find "$ROOT/vendor/bsnes-jg/objs" -name '*.a' | head -1)"
g++ -O2 -std=c++11 -DJGX_ZOOM -I"$ROOT/vendor/bsnes-jg/src" -I"$ROOT/tools" -I"$W/snes" -I"$W/65816" \
    -c "$ROOT/dev/jgxcheck.cpp" -o "$W/jgxz.o"
g++ "$W/jgxz.o" "$ARCHIVE" -lsamplerate -lm -o "$W/jgxcheck-zoom"
"$CLANG" --config "$CFG" -mcpu=mosw65816 -Os -mllvm -verify-machineinstrs \
    -Wl,-Map="$W/z.map" -o "$W/z.sfc" "$W/snes/mandel-zoom.c"
python3 "$ROOT/tools/snes-checksum.py" "$W/z.sfc" >/dev/null

# 4. run the ZOOM differential (host replay of zoom.h == ROM rolling CRC?)
vma(){ awk -v s="$1" '$NF==s{print $1; exit}' "$W/z.map"; }
JGX_SCRIPT="R:30,A:10,SELECT:4,R:50,NONE:120" JGX_PADLOG="0x$(vma pad_log)" JGX_PADLOG_N=64 \
  JGX_ZOOMCRC="0x$(vma zoom_crc)" JGX_NFRAMES="0x$(vma nframes)" \
  JGX_LEVELHASH="0x$(vma level_hash)" JGX_CURLEVEL="0x$(vma cur_level)" \
  "$W/jgxcheck-zoom" "$W/z.sfc" "$DB" "0x$(vma corpus_result)" 2 "$EXPECT" 200 /dev/null 2>/dev/null \
  | grep -E 'ZOOM' | sed "s/^/[$FORM] /"
