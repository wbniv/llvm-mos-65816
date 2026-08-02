#!/usr/bin/env bash
# Build and gate the Apollo 11 daylight-launch SVX2 cartridge — the codec's
# hardest realistic input. Structure follows dev/snes-video-reel.sh.
#
# Correctness is gated; throughput is REPORTED. This ROM exists to produce the
# cadence measurement on hard content, so a slower number than the Artemis reel
# is the finding, not a gate failure.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: dev/apollo-reel.sh [-h|--help]

Bakes the Apollo daylight corpus into a linkable asset header, builds the slow
and FastROM cartridges, and runs the gate:

  1. asset bake reproduces the recorded corpus SHA-256
  2. whole-loop byte-correct decode on bsnes-jg (all 300 frames + loop delta)
  2b. negative control: one flipped stream byte must FAIL the gate
  3. cadence: presented frames per 600 VBlanks, slow ROM and FastROM
  4. entropy fingerprint (None/Low/High x2) and -verify-machineinstrs

Environment:
  APOLLO_REEL_CORPUS   corpus directory holding apollo-daylight-floyd.{tiles,pal}
  APOLLO_REEL_DITHER   floyd (default; the shipping dither) or bayer
  APOLLO_REEL_FRAMES   frames to bake (default 300)
  APOLLO_REEL_KEYFRAME seek-keyframe interval K (default 120, policy Option A)
  APOLLO_REEL_CADENCE  VBlanks per presented frame (default 2)
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) usage >&2; echo >&2; echo "FATAL: unexpected argument '$1'" >&2; exit 2 ;;
esac

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build"
CC="$BUILD/llvm-mos-install/bin/mos-clang"
CONFIG="$BUILD/install/bin/mos-snes-hirom.cfg"
JGX="$BUILD/jgxcheck"
DATABASE="$ROOT/vendor/bsnes-jg/Database"

CORPUS=${APOLLO_REEL_CORPUS:-/tmp/claude-1000/-home-will-llvm-mos-65816/a18c5d7f-022f-40ce-9bd4-41fe3d290b79/scratchpad/apollo-work}
DITHER=${APOLLO_REEL_DITHER:-floyd}
FRAMES=${APOLLO_REEL_FRAMES:-300}
KEYFRAME=${APOLLO_REEL_KEYFRAME:-120}
CADENCE=${APOLLO_REEL_CADENCE:-2}

TILES="$CORPUS/apollo-daylight-$DITHER.tiles"
PALETTE="$CORPUS/apollo-daylight-$DITHER.pal"
RGB="$CORPUS/apollo-daylight.rgb"
# Recorded in docs/plans/.../real-video-codec-benchmark.md §Hard-content stressor.
RGB_SHA=a78c4c8c96ba7a00e99475b9545466b21cd12a041597d867994318a33f514080

HEADER="$BUILD/apollo-reel-assets.h"
STREAM="$BUILD/apollo-reel-stream.bin"
EFFECTIVE_PAL="$BUILD/apollo-reel-effective.pal"
SCREENSHOT="$BUILD/apollo-daylight.png"

[ -x "$CC" ]  || { echo "FATAL: missing compiler $CC"; exit 1; }
[ -x "$JGX" ] || { echo "FATAL: missing $JGX (run dev/run.sh xcheck)"; exit 1; }
[ -f "$CONFIG" ] || { echo "FATAL: missing $CONFIG"; exit 1; }
[ -f "$TILES" ] || { echo "FATAL: missing tile corpus $TILES"; exit 1; }
[ -f "$PALETTE" ] || { echo "FATAL: missing palette $PALETTE"; exit 1; }

rc=0

echo "==> 1) asset bake reproduces the recorded corpus SHA-256"
if [ -f "$RGB" ]; then
  have=$(sha256sum "$RGB" | cut -d' ' -f1)
  if [ "$have" = "$RGB_SHA" ]; then
    echo "  PASS: RGB24 corpus $have"
  else
    echo "  FAIL: RGB24 corpus $have != recorded $RGB_SHA"; rc=1
  fi
else
  echo "  WARN: $RGB absent; regenerate with tools/snes-video-rgb24-convert.sh"
  echo "        --start 3410 --duration 10 <master>.mp4 (provenance in the benchmark doc)"
fi

PYTHONPATH="$ROOT/tools" python3 "$ROOT/tools/snes-video-reel-assets.py" \
  --frames "$FRAMES" --packed-far --keyframe-interval "$KEYFRAME" \
  --frame-checks --dashboard-palette-fixup \
  --palette-output "$EFFECTIVE_PAL" --stream-output "$STREAM" \
  "$TILES" "$PALETTE" "$HEADER"
echo "  tiles  sha256 $(sha256sum "$TILES" | cut -d' ' -f1)"
echo "  stream sha256 $(sha256sum "$STREAM" | cut -d' ' -f1)"
echo "  stream bytes  $(stat -c%s "$STREAM")"

# ---------------------------------------------------------------------------
build_rom() { # <rom> <map> <fastrom 0|1> <stream>
  local rom=$1 map=$2 fast=$3 stream=$4
  local defines=(-DAPOLLO_REEL_VBLANKS_PER_FRAME="$CADENCE")
  local checksum=(--hirom)
  if [ "$fast" = 1 ]; then
    defines+=(-DAPOLLO_REEL_FASTROM)
    checksum+=(--fastrom)
  fi
  "$CC" --config "$CONFIG" -mcpu=mosw65816 \
    -Xclang -target-feature -Xclang +mos-a16 -Os -DSVC_USE_ASM \
    "${defines[@]}" -I"$BUILD" -I"$ROOT/examples/snes" \
    -Wl,-Map="$map" -o "$rom" \
    "$ROOT/examples/snes/apollo-reel.c" \
    "$ROOT/examples/snes/apollo-reel-fast.s" \
    "$ROOT/examples/snes/snes-video-codec.c" \
    "$ROOT/examples/snes/snes-video-dma.c" \
    "$ROOT/examples/snes/snes-video-codec-fast.s"
  python3 "$ROOT/tools/snes-video-pack-hirom.py" "$rom" "$stream" >/dev/null
  python3 "$ROOT/tools/snes-checksum.py" "${checksum[@]}" "$rom" >/dev/null
}

sym() { # <map> <symbol> -> hex offset
  local vma
  vma=$(awk -v s="$2" '$NF==s {print $1; exit}' "$1")
  [ -n "$vma" ] || { echo "FATAL: symbol $2 missing from $1" >&2; return 1; }
  printf '%x' "$((16#$vma))"
}

read_value() { # <rom> <offset> <len> <frames> -> decimal
  local line hex
  line=$("$JGX" "$1" "$DATABASE" "$2" "$3" 0 "$4" || true)
  hex=$(printf '%s\n' "$line" | sed -n 's/.*got=0x\([0-9A-Fa-f]*\).*/\1/p')
  [ -n "$hex" ] || { echo "FATAL: cannot parse jgxcheck output: $line" >&2; return 1; }
  printf '%d\n' "$((16#$hex))"
}

SLOW_ROM="$BUILD/apollo-daylight-slow.sfc"
SLOW_MAP="$BUILD/apollo-daylight-slow.map"
FAST_ROM="$BUILD/apollo-daylight.sfc"
FAST_MAP="$BUILD/apollo-daylight.map"

build_rom "$SLOW_ROM" "$SLOW_MAP" 0 "$STREAM"
build_rom "$FAST_ROM" "$FAST_MAP" 1 "$STREAM"

corpus_off=$(sym "$FAST_MAP" apollo_reel_corpus_result)
health_off=$(sym "$FAST_MAP" apollo_reel_health)
window_off=$(sym "$FAST_MAP" apollo_reel_window_presented)
wvbl_off=$(sym "$FAST_MAP" apollo_reel_window_vblanks)
slips_off=$(sym "$FAST_MAP" apollo_reel_deadline_slips)
frame_off=$(sym "$FAST_MAP" apollo_reel_frame)

# The boot validation pass is the long pole, and it is much longer on the slow
# ROM: the C Fletcher loop runs 4,480 iterations per frame on top of the decode,
# so 301 checked decodes cost ~2,400 VBlanks there (measured) versus ~700 on
# FastROM. Two playback loops at cadence 2 add a further 1,200. 6,000 clears
# both builds with margin; the health word only latches after those two loops.
GATE_FRAMES=${APOLLO_REEL_GATE_FRAMES:-6000}

echo
echo "==> 2) whole-loop byte-correct decode (all $FRAMES frames + loop delta)"
for label in slow fastrom; do
  if [ "$label" = slow ]; then rom=$SLOW_ROM; map=$SLOW_MAP; else rom=$FAST_ROM; map=$FAST_MAP; fi
  c_off=$(sym "$map" apollo_reel_corpus_result)
  h_off=$(sym "$map" apollo_reel_health)
  line=$("$JGX" "$rom" "$DATABASE" "$c_off" 1 0 "$GATE_FRAMES" || true)
  case "$line" in
    *PASS*) echo "  PASS: $label corpus gate: $line" ;;
    *) echo "  FAIL: $label corpus gate: $line"; rc=1 ;;
  esac
  line=$("$JGX" "$rom" "$DATABASE" "$h_off" 4 0 "$GATE_FRAMES" || true)
  case "$line" in
    *PASS*) echo "  PASS: $label composite health: $line" ;;
    *) echo "  FAIL: $label composite health: $line"; rc=1 ;;
  esac
done

echo
echo "==> 2b) negative control: one flipped stream byte must FAIL the gate"
BAD_STREAM="$BUILD/apollo-reel-stream-corrupt.bin"
BAD_ROM="$BUILD/apollo-daylight-corrupt.sfc"
BAD_MAP="$BUILD/apollo-daylight-corrupt.map"
FLIP_AT=${APOLLO_REEL_FLIP_OFFSET:-400000}
python3 - "$STREAM" "$BAD_STREAM" "$FLIP_AT" <<'PY'
import sys
from pathlib import Path
src, dst, at = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3])
data = bytearray(src.read_bytes())
if at >= len(data):
    raise SystemExit(f"flip offset {at} outside {len(data)}-byte stream")
before = data[at]
data[at] ^= 0x01
dst.write_bytes(bytes(data))
print(f"  flipped stream byte {at}: 0x{before:02x} -> 0x{data[at]:02x}")
PY
build_rom "$BAD_ROM" "$BAD_MAP" 1 "$BAD_STREAM"
bad_off=$(sym "$BAD_MAP" apollo_reel_corpus_result)
bad_line=$("$JGX" "$BAD_ROM" "$DATABASE" "$bad_off" 1 0 "$GATE_FRAMES" || true)
case "$bad_line" in
  *PASS*) echo "  FAIL: corrupted stream still passed — the gate cannot fail: $bad_line"; rc=1 ;;
  *) echo "  PASS: corrupted stream rejected: $bad_line" ;;
esac

echo
echo "==> 3) cadence: presented frames per $((CADENCE * 300)) VBlanks"
printf '  %-10s %10s %10s %10s %10s\n' build presented vblanks per600 slips
for label in slow fastrom; do
  if [ "$label" = slow ]; then rom=$SLOW_ROM; map=$SLOW_MAP; else rom=$FAST_ROM; map=$FAST_MAP; fi
  w_off=$(sym "$map" apollo_reel_window_presented)
  v_off=$(sym "$map" apollo_reel_window_vblanks)
  s_off=$(sym "$map" apollo_reel_deadline_slips)
  presented=$(read_value "$rom" "$w_off" 2 "$GATE_FRAMES") || { rc=1; continue; }
  vblanks=$(read_value "$rom" "$v_off" 2 "$GATE_FRAMES") || { rc=1; continue; }
  slips=$(read_value "$rom" "$s_off" 2 "$GATE_FRAMES") || { rc=1; continue; }
  if [ "$vblanks" -gt 0 ]; then
    per600=$(( (presented * 600 + vblanks / 2) / vblanks ))
  else
    per600=0; echo "  WARN: $label cadence window never closed"; rc=1
  fi
  printf '  %-10s %10s %10s %10s %10s\n' "$label" "$presented" "$vblanks" "$per600" "$slips"
done
echo "  (reported, not gated — a slower number on this content is the measurement)"

echo
echo "==> 4a) -verify-machineinstrs clean"
vlog="$BUILD/apollo-reel.vlog"
if "$CC" --config "$CONFIG" -mcpu=mosw65816 \
     -Xclang -target-feature -Xclang +mos-a16 -Os -DSVC_USE_ASM \
     -DAPOLLO_REEL_VBLANKS_PER_FRAME="$CADENCE" -DAPOLLO_REEL_FASTROM \
     -I"$BUILD" -I"$ROOT/examples/snes" -mllvm -verify-machineinstrs \
     -c -o "$BUILD/apollo-reel.o" "$ROOT/examples/snes/apollo-reel.c" 2>"$vlog"; then
  if grep -qiE 'error|Bad machine' "$vlog"; then
    echo "  FAIL: verifier complaints"; grep -iE 'error|Bad machine' "$vlog" | head -5; rc=1
  else
    echo "  PASS: no verifier complaints"
  fi
else
  echo "  FAIL: compile failed"; head -20 "$vlog"; rc=1
fi

echo
echo "==> 4b) picture is independent of power-on entropy (None/Low/High x2)"
# bsnes-jg reseeds from clock() at every power-on and randomises every PPU
# register the ROM does not write, so a ROM that inherits one renders a
# different picture every boot while its WRAM verdict stays deterministic.
ENTROPY_FRAMES=${APOLLO_REEL_ENTROPY_FRAMES:-2400}
fps=""
for ent in 0 0 1 1 2 2; do
  # `|| true` INSIDE the substitution: this probe only wants the FRAMESCAN line
  # and asks for a WRAM value it does not care about, so jgxcheck's exit status
  # is meaningless here and pipefail would otherwise kill the gate.
  fp="$( { JGX_ENTROPY=$ent JGX_FRAMESCAN=1 JGX_FRAMESCAN_MAX=0 \
           "$JGX" "$FAST_ROM" "$DATABASE" 0x0 1 0x00 \
           "$ENTROPY_FRAMES" 2>/dev/null || true; } \
        | sed -n 's/.*final hash=\([0-9A-F]*\) dom=#\([0-9A-F]*\).*/\1:#\2/p')"
  fps="$fps $ent=${fp:-NONE}"
done
uniq_n=$(printf '%s\n' $fps | sed 's/^[0-9]*=//' | sort -u | wc -l)
if printf '%s\n' $fps | grep -q '=NONE$'; then
  echo "  FAIL: jgxcheck printed no FRAMESCAN line — rebuild it (dev/run.sh xcheck)"; rc=1
elif [ "$uniq_n" = 1 ]; then
  echo "  PASS: one picture across all six boots ($(printf '%s\n' $fps | head -1 | sed 's/^[0-9]*=//'))"
else
  echo "  FAIL: $uniq_n distinct pictures across six boots — the ROM inherits PPU"
  echo "        state it never sets. Call snes_ppu_reset_blank() before drawing."
  for f in $fps; do echo "          entropy $f"; done
  rc=1
fi

echo
echo "==> 5) frame capture"
shot_line=$(JGX_POLL=1 "$JGX" "$FAST_ROM" "$DATABASE" "$frame_off" 2 96 "$GATE_FRAMES" \
  "$SCREENSHOT" || true)
case "$shot_line" in
  *PASS*) echo "  PASS: captured frame 150: $shot_line" ;;
  *) echo "  WARN: capture rendezvous missed: $shot_line" ;;
esac

echo
echo "SLOW_ROM=$SLOW_ROM"
echo "ROM=$FAST_ROM"
echo "ROM_SHA256=$(sha256sum "$FAST_ROM" | cut -d' ' -f1)"
[ "$rc" = 0 ] && echo "GATE: PASS" || echo "GATE: FAIL"
exit "$rc"
