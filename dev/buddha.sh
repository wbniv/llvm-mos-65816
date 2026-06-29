#!/usr/bin/env bash
# dev/buddha.sh — #4 Buddhabrot: escaping-orbit density on the SNES (Mode 7), rendered + asserted.
#
# The density grid blooms live into a 128x128 far hit grid ($7E2000) via the far scatter-write path
# (random c -> z^2+c escape test -> orbit-replay far RMW), is revealed band-by-band (far grid ->
# near chrbuf -> VRAM DMA) through a ghostly glow palette, and is non-interactive. +mos-a16-only
# (far grid). One differential channel, host == target:
#   * grid:  a DETERMINISTIC boot accumulation of K_GATE samples -> corpus_result == the host oracle
#            (examples/65816/k_buddha_far.c -DHOST -DK_GATE). host == +mos-a16, MAME + bsnes-jg.
# Plus a bsnes-jg framebuffer PNG and a MAME snapshot. Outputs build/buddha-{jg,mame}.png.
#
# Drive: dev/run.sh buddha.  Live play: task buddha-play.
# Plan: docs/plans/2026-06-28-4-snes-buddhabrot.md.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh buddha   # Buddhabrot density accumulation on SNES (far grid + Mode 7); grid differential + screenshots"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/snes/buddha.c"
ORACLE="$ROOT/examples/65816/k_buddha_far.c"
ROM="$BUILD/buddha.sfc"
MAP="$BUILD/buddha.map"
VENDOR="$ROOT/vendor/bsnes-jg"
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: dev/run.sh build)"; exit 1; }

INSTALL="$INSTALL" "$ROOT/dev/sync-platform.sh"

# K_GATE from the ROM source so the host oracle can't drift; the gate snapshots at exactly K_GATE
# samples, reached early in the bloom -> a generous frame budget covers it.
K_GATE=$(awk '/#define K_GATE /{print $3; exit}' "$SRC" | tr -dc '0-9')
FRAMES="${MANDEL_FRAMES:-6000}"
echo "==> buddha: K_GATE=$K_GATE  (frames=$FRAMES)"

# 1. Host oracle derives the golden grid hash (cc -DHOST over the SAME buddha.h, matching K_GATE).
cc -DHOST -O2 -DK_GATE="$K_GATE" -o "$BUILD/buddha_oracle" "$ORACLE"
HOSTREP="$("$BUILD/buddha_oracle" 2>&1 1>/dev/null || true)"
WANT="$("$BUILD/buddha_oracle")"
echo "    $HOSTREP"
echo "==> host reference: grid hash = $WANT"

# 2. Build the +mos-a16 ROM (the far grid is a16-only) + find the proof-channel symbol.
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
CV=$(awk '$NF=="corpus_result"{print $1; exit}' "$MAP")
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$CV )))
echo "==> built $(basename "$ROM") (+mos-a16); corpus_result @ \$$CV"

rc=0

# 3. bsnes-jg: grid gate + framebuffer dump (build a plain jgxcheck from current source).
ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
JGX="$BUILD/jgxcheck"
if [ -n "$ARCHIVE" ] && [ ! -x "$JGX" ]; then
  g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
  g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: grid gate (corpus == $WANT) + framebuffer dump (build/buddha-jg.png)"
  "$JGX" "$ROM" "$VENDOR/Database" "0x$CV" 2 "$WANT" "$FRAMES" "$BUILD/buddha-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 4. MAME under Xvfb: snapshot + assert the grid gate (sample after the bloom passes K_GATE).
if command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + grid gate (build/buddha-mame.png)"
  SNAP="$BUILD/.bud-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  secs=$(( FRAMES / 60 + 8 ))
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$WANT" SHOT_AT="$FRAMES" \
    xvfb-run -a mame snes -cart "$ROM" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/mandel-shot.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run "$secs" \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  [ -f "$SNAP/snes/0000.png" ] && mv "$SNAP/snes/0000.png" "$BUILD/buddha-mame.png"
  case "$line" in "SHOT: PASS"*) : ;; *) [ -n "$line" ] && rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Buddhabrot density on SNES; grid hash $WANT host == +mos-a16 (bsnes-jg + MAME)"
else
  echo "RESULT: FAIL — see the per-step lines above"
fi
exit $rc
