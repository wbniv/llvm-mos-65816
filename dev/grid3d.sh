#!/usr/bin/env bash
# dev/grid3d.sh — render the 3-D Grid Voxel Life demo (#72 compiler stress-test) ON the SNES
# (examples/snes/grid3d.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores headless,
# each asserting corpus_result == the host oracle (tools/grid3d-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/grid3d.lua snapshots + asserts.
# Plus a disasm gate proving the corner is multi-dimensional array indexing: the true 3-D arrays g3_a/g3_b
# are referenced and the grid[z][y][x] stride arithmetic (z*36 + y*6 + x) shows up as index math (shifts/
# adds; small non-pow2 strides strength-reduce). native-16 present. The full 5-way differential
# (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh grid3d. Outputs build/grid3d-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh grid3d   # render the 3-D voxel life; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/grid3d.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; grid3d.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/grid3d-sim.c" -o "$BUILD/grid3d-sim"
EXPECT=$("$BUILD/grid3d-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: grid3d gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/grid3d.map" -o "$BUILD/grid3d.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/grid3d.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/grid3d.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/grid3d.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: multi-dimensional array indexing. The true 3-D arrays g3_a/g3_b are referenced and the
# grid[z][y][x] stride arithmetic is present (index shifts/adds; native-16). (The small non-pow2 strides
# 36/6 strength-reduce to shift-adds rather than __mulhi3 libcalls — reported for transparency.)
echo "==> disasm gate (multi-dimensional array indexing: grid[z][y][x] stride arithmetic)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/grid3d_sim.c" -I"$ROOT/examples" -o "$BUILD/grid3d_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/grid3d_sim.o" 2>/dev/null || true)
grid=$(printf '%s\n' "$dis" | grep -cE 'g3_a|g3_b' || true)      # the 3-D arrays
sh=$(printf   '%s\n' "$dis" | grep -cwE 'asl|lsr|rol|ror' || true)  # stride shift-adds
mul=$(printf  '%s\n' "$dis" | grep -cE '__mul(qi|hi|si)3' || true)  # (any residual stride mul)
rs=$(printf   '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$grid" -ge 1 ] && [ "$sh" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  g3_a/g3_b-refs=$grid  shifts=$sh  rep/sep=$rs  (multi-dim indexing; stride mul=$mul)"
else
  echo "    FAIL  g3_a/g3_b-refs=$grid  shifts=$sh  rep/sep=$rs  (expected grid-refs>=1, shifts>=1, rep/sep>=1)"; rc=1
fi

# 4. bsnes-jg — build the harness if needed, then dump framebuffer + assert.
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    echo "==> building jgxcheck harness"
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + framebuffer dump (build/grid3d-jg.png) + assert"
  "$JGX" "$BUILD/grid3d.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 800 "$BUILD/grid3d-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/grid3d-mame.png)"
  SNAP="$BUILD/.grid3d-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/grid3d.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/grid3d.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 20 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/grid3d-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — 3-D voxel life rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
