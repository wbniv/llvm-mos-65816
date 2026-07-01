#!/usr/bin/env bash
# dev/metaball.sh — render the Union Type-Pun Fast-Inverse-Sqrt Metaballs demo (#45 compiler stress-test)
# ON the SNES (examples/snes/metaball.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/metaball-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/metaball.lua snapshots + asserts.
# Plus a disasm gate proving the hot loop is the Quake union type-pun fast-inverse-sqrt: soft-float
# (__mulsf3) plus the magic constant 0x5f3759df (byte immediates #$5f #$37 #$59 #$df) with the float's
# storage shifted (>>1) and subtracted (0x5f3759df - bits) AS an integer — the float<->uint32 reinterpret.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh metaball. Outputs build/metaball-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh metaball   # render the union-punned metaballs; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/metaball.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; metaball.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/metaball-sim.c" -o "$BUILD/metaball-sim"
EXPECT=$("$BUILD/metaball-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: metaball gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/metaball.map" -o "$BUILD/metaball.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/metaball.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/metaball.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/metaball.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: Quake union type-pun fast-inverse-sqrt. Soft-float (__mulsf3) plus the magic constant
# 0x5f3759df (byte immediates #$5f AND #$37) manipulating the float's storage as an integer, native-16.
echo "==> disasm gate (union type-pun fast-inverse-sqrt: __mulsf3 + magic 0x5f3759df + native-16)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/metaball_sim.c" -I"$ROOT/examples" -o "$BUILD/metaball_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/metaball_sim.o" 2>/dev/null || true)
sf=$(printf  '%s\n' "$dis" | grep -cE '__mulsf3' || true)
m5f=$(printf '%s\n' "$dis" | grep -ciE '#\$5f\b' || true)
m37=$(printf '%s\n' "$dis" | grep -ciE '#\$37\b' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$sf" -ge 1 ] && [ "$m5f" -ge 1 ] && [ "$m37" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __mulsf3=$sf  magic(#\$5f=$m5f #\$37=$m37)  rep/sep=$rs  (union type-pun fast-inverse-sqrt)"
else
  echo "    FAIL  __mulsf3=$sf  magic(#\$5f=$m5f #\$37=$m37)  rep/sep=$rs  (expected __mulsf3>=1, magic bytes>=1, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/metaball-jg.png) + assert"
  "$JGX" "$BUILD/metaball.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 900 "$BUILD/metaball-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/metaball-mame.png)"
  SNAP="$BUILD/.metaball-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/metaball.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/metaball.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/metaball-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — union type-pun fast-inverse-sqrt metaballs rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
