#!/usr/bin/env bash
# dev/boids.sh — render the #26 Boids flock (examples/snes/boids.c, +mos-a16) ON the SNES and capture a
# REAL emulator screenshot from BOTH cores headless, each asserting corpus_result == the host oracle
# (tools/boids-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/boids.lua snapshots + asserts.
# Plus a disasm gate proving the steering kernel's STRUCT-BY-VALUE calls survive -Os (the aggregate-
# return ABI under test) alongside the fixed-point __mulsi3 + rep/sep. The full 5-way differential
# (host==default==+mos-a16==+mos-xy16) is the corpus slice (boids_sim.c), run by dev/run.sh corpus-a16.
#
# Drive: dev/run.sh boids. Outputs build/boids-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh boids   # render the Boids flock on SNES; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/boids.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; boids.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/boids-sim.c" -o "$BUILD/boids-sim"
EXPECT=$("$BUILD/boids-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: Boids gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/boids.map" -o "$BUILD/boids.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/boids.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/boids.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/boids.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the STRUCT-BY-VALUE steering kernel. The vec2 take/return-by-value functions are
# noinline, so under -Os their definitions (and the aggregate-return calls) must SURVIVE — that is the
# ABI corner under test; plus the fixed-point __mulsi3 and native-16 rep/sep.
echo "==> disasm gate (struct-by-value / aggregate-return ABI codegen)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/boids_sim.c" -I"$ROOT/examples" -o "$BUILD/boids_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/boids_sim.o" 2>/dev/null || true)
byval=$(printf '%s\n' "$dis" | grep -cE 'v2_add|v2_sub|v2_scale|boid_acc|boid_cohesion' || true)
mul=$(printf   '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3' || true)
dv=$(printf    '%s\n' "$dis" | grep -cE '__divsi3|__udivsi3'  || true)
rs=$(printf    '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$byval" -ge 1 ] && [ "$mul" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  by-value-calls=$byval  __mulsi3=$mul  __divsi3=$dv  rep/sep=$rs  (aggregate-return ABI, native-16)"
else
  echo "    FAIL  by-value-calls=$byval  __mulsi3=$mul  __divsi3=$dv  rep/sep=$rs  (expected by-value/mul/rep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/boids-jg.png) + assert"
  "$JGX" "$BUILD/boids.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 1400 "$BUILD/boids-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/boids-mame.png)"
  SNAP="$BUILD/.boids-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/boids.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/boids.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 28 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/boids-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Boids flock rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
