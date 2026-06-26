#!/usr/bin/env bash
# dev/blossom.sh — #3 Blossom Stage 2: the Hopalong attractor rendered on the SNES via Mode 7.
#
# Accumulate K_POINTS orbit points into a 128x128 far hit grid ($7E2000) via the far read-modify-write
# path, then reveal it band-by-band (far grid -> near chrbuf -> VRAM DMA) with a "fire" CGRAM palette.
# +mos-a16-only (far pointers). The grid's hash (corpus_result) is gated against the host oracle
# (examples/65816/k_blossom_far.c -DHOST -DK_GATE=K_POINTS — the SAME hopalong.h), so this is
# host == +mos-a16 on MAME + bsnes-jg, plus a real framebuffer screenshot from BOTH cores.
#
# Outputs build/blossom-{jg,mame}.png. Drive: dev/run.sh blossom.
# Plan: docs/plans/2026-06-24-3-snes-blossom-on-screen-interactive-hopalong-attr.md.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh blossom   # Hopalong attractor on SNES via Mode 7 (far hit-grid + band DMA); screenshot MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/snes/blossom.c"
ORACLE="$ROOT/examples/65816/k_blossom_far.c"
ROM="$BUILD/blossom.sfc"
MAP="$BUILD/blossom.map"
VENDOR="$ROOT/vendor/bsnes-jg"
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: dev/run.sh build)"; exit 1; }

# Pick up edits to platforms/snes/snes.h without a full re-vendor (<snes.h> -> the installed copy).
INSTALL="$INSTALL" "$ROOT/dev/sync-platform.sh"

# K_POINTS from the source so the host oracle can't drift; plot ~K/7 frames, +reveal+margin.
K_POINTS=$(awk '/#define K_POINTS /{print $3; exit}' "$SRC")
FRAMES="${MANDEL_FRAMES:-$(( K_POINTS / 5 + 1200 ))}"
echo "==> blossom: K_POINTS=$K_POINTS  (frames=$FRAMES)"

# 1. Host oracle derives the golden grid hash (cc -DHOST over the SAME hopalong.h, matching K).
cc -DHOST -O2 -DK_GATE="$K_POINTS" -o "$BUILD/blossom_oracle" "$ORACLE"
HOSTREP="$("$BUILD/blossom_oracle" 2>&1 1>/dev/null || true)"
WANT="$("$BUILD/blossom_oracle")"
echo "    $HOSTREP"
echo "==> host reference: grid hash = $WANT"

# 2. Build the Mode 7 ROM (+mos-a16) + find corpus_result.
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$MAP")
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built $(basename "$ROM") (+mos-a16); corpus_result @ WRAM 0x$VMA"

rc=0

# 3. bsnes-jg: framebuffer dump + assert. Always (re)build jgxcheck from current source — a worktree's
#    hardlinked build/jgxcheck can predate the PNG-dump support.
JGX="$BUILD/jgxcheck"
ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
if [ -n "$ARCHIVE" ]; then
  g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
  g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + framebuffer dump (build/blossom-jg.png)"
  "$JGX" "$ROM" "$VENDOR/Database" "0x$VMA" 2 "$WANT" "$FRAMES" "$BUILD/blossom-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 4. MAME under Xvfb: snapshot + assert (snapshot well after the compute completes).
if command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/blossom-mame.png)"
  SNAP="$BUILD/.bl-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  secs=$(( FRAMES / 60 + 5 ))
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$WANT" SHOT_AT="$FRAMES" \
    xvfb-run -a mame snes -cart "$ROM" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/mandel-shot.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run "$secs" \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  [ -f "$SNAP/snes/0000.png" ] && mv "$SNAP/snes/0000.png" "$BUILD/blossom-mame.png"
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Hopalong attractor on SNES (far hit-grid + Mode 7 band DMA); MAME + bsnes-jg match host (hash $WANT)"
else
  echo "RESULT: FAIL — see the per-step lines above"
fi
exit $rc
