#!/usr/bin/env bash
# dev/invaders.sh — Space Invaders on snesgfx: the differential gate + a real screenshot.
#
# Runs the deterministic ATTRACT sequence (no joypad) and asserts the rolling state-CRC on every
# differential point, then captures the rendered frame:
#   host oracle (tools/invaders-sim.c)  ==  default@MAME == +mos-a16@MAME  ==  default/+mos-a16@bsnes-jg
#   + MAME-under-Xvfb snapshot of the +mos-a16 ROM  -> build/invaders-mame.png
#   + bsnes-jg framebuffer dump                      -> build/invaders-jg.png  (if jgxcheck supports it)
# Space Invaders uses no far pointers, so it builds BOTH default and +mos-a16 (richer than the
# a16-only mandel gate). Drive: dev/run.sh invaders.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh invaders   # attract-mode CRC on MAME + bsnes-jg (default + a16) + a screenshot"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/invaders.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }
"$ROOT/dev/sync-platform.sh"

# 1. Host oracle CRC (the single source of truth, mirrors the game's INV_FRAMES).
cc -O2 -I "$ROOT/examples/snes" "$ROOT/tools/invaders-sim.c" -o "$BUILD/invaders-sim"
EXPECT=$("$BUILD/invaders-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: attract CRC16=$EXPECT"

# 2. Build DEFAULT and +mos-a16 ROMs (both must match the oracle). The committed gfx4snes
#    binaries are objcopied into bank-$00 .rodata objects and linked (Option B — no C arrays).
OBJCOPY="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin/llvm-objcopy"
ASSETS=()
for ext in pic pal; do
  [ -e "$ROOT/examples/snes/invaders.$ext" ] || continue
  ( cd "$ROOT/examples/snes" && "$OBJCOPY" -I binary -O elf32-mos \
      --rename-section ".data=.rodata.invaders_${ext},alloc,load,readonly,data,contents" \
      "invaders.$ext" "$BUILD/invaders.$ext.o" )
  ASSETS+=("$BUILD/invaders.$ext.o")
done
build_rom() { # <tag> <extra-flags...>
  local tag="$1"; shift
  "$TOOL/mos-clang" --config "$CFG" "$@" -mllvm -verify-machineinstrs -Os \
    -Wl,-Map="$BUILD/invaders$tag.map" -o "$BUILD/invaders$tag.sfc" "$SRC" "${ASSETS[@]}"
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/invaders$tag.sfc" >/dev/null
}
build_rom ""    -mcpu=mosw65816
build_rom "-a16" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/invaders.map"); OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built default + a16; corpus_result @ WRAM $OFF"

# Emulator frames to let the attract sim reach the latch point. The game runs ~1 sim step per loop
# iteration, but a frame's render+update can span up to ~2 v-blanks, so allow 2x + margin.
FRAMES=$(awk '/#define INV_FRAMES/{print $3; exit}' "$ROOT/examples/snes/invaders_logic.h")
SETTLE=$(( FRAMES * 2 + 200 )); SECS=$(( SETTLE / 40 + 5 ))
rc=0

# 3. MAME assert (default + a16) via smoke.lua.
for tag in "" "-a16"; do
  echo "==> MAME assert: invaders$tag.sfc"
  line="$(SDL_VIDEODRIVER=offscreen SMOKE_ADDR="$ADDR" SMOKE_WANT="$EXPECT" SMOKE_LEN=2 SMOKE_SETTLE="$SETTLE" \
    mame snes -cart "$BUILD/invaders$tag.sfc" -rompath "$ROOT/dev/roms" -autoboot_script "$ROOT/dev/smoke.lua" \
      -skip_gameinfo -video none -sound none -nothrottle -seconds_to_run "$SECS" \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SMOKE:' || true)"
  echo "    $line"; case "$line" in *PASS*) : ;; *) rc=1 ;; esac
done

# 4. bsnes-jg — (re)build the harness if stale, assert (default + a16), dump a PNG if supported.
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ] || [ "$ROOT/dev/jgxcheck.cpp" -nt "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    echo "==> building jgxcheck harness"
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  for tag in "" "-a16"; do
    png=(); [ "$tag" = "-a16" ] && png=("$BUILD/invaders-jg.png")
    echo "==> bsnes-jg assert: invaders$tag.sfc"
    "$JGX" "$BUILD/invaders$tag.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" "$SETTLE" "${png[@]}" || rc=1
  done
  # bsnes power-on determinism (handoff §3.1): 3 captures must be byte-identical, else the PPU is
  # under-initialised and the screen flaps — which would also flap on the biohack bsnes-jg WASM page.
  for i in 1 2 3; do "$JGX" "$BUILD/invaders-a16.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" "$SETTLE" "$BUILD/.inv-det$i.png" >/dev/null 2>&1 || true; done
  if [ "$(sha1sum "$BUILD"/.inv-det1.png "$BUILD"/.inv-det2.png "$BUILD"/.inv-det3.png 2>/dev/null | awk '{print $1}' | sort -u | wc -l)" = "1" ]; then
    echo "    bsnes determinism: PASS (3x byte-identical)"
  else
    echo "    bsnes determinism: FAIL (screen flaps — under-initialised PPU)"; rc=1
  fi
  rm -f "$BUILD"/.inv-det1.png "$BUILD"/.inv-det2.png "$BUILD"/.inv-det3.png
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the rendered attract frame (a16 ROM) + assert.
if command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot (build/invaders-mame.png)"
  SNAP="$BUILD/.invaders-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" SHOT_AT="$SETTLE" \
    xvfb-run -a mame snes -cart "$BUILD/invaders-a16.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/mandel-shot.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run "$SECS" \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  [ -f "$SNAP/snes/0000.png" ] && mv "$SNAP/snes/0000.png" "$BUILD/invaders-mame.png"
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Space Invaders attract CRC $EXPECT: host == default == a16 on MAME + bsnes-jg; screenshots in build/invaders-{mame,jg}.png"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
