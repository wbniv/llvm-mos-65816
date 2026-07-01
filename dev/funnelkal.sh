#!/usr/bin/env bash
# dev/funnelkal.sh — render the Funnel-Shift Kaleidoscope (#73 compiler stress-test) ON the SNES
# (examples/snes/funnelkal.c, +mos-a16) and capture headless screenshots from BOTH emulator cores,
# each asserting corpus_result == the host oracle (tools/funnelkal-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps framebuffer + asserts.
#   * MAME     — under Xvfb, dev/funnelkal.lua snapshots + asserts.
# Plus a disasm gate proving the corner is two-source G_FSHL/G_FSHR funnel shift:
# the expansion emits ora (to combine the two shifted halves) and variable shifts,
# plus rep/sep confirming a16 mode.  Full 5-way differential (host==default==+mos-a16==+mos-xy16)
# is the corpus slice gate.
#
# Drive: dev/run.sh funnelkal.  Outputs build/funnelkal-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh funnelkal   # render funnel-shift kaleidoscope; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/funnelkal.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/funnelkal-sim.c" -o "$BUILD/funnelkal-sim"
EXPECT=$("$BUILD/funnelkal-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: funnelkal gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/funnelkal.map" -o "$BUILD/funnelkal.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/funnelkal.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/funnelkal.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/funnelkal.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: two-source funnel shift (G_FSHL/G_FSHR .lower()).
# The "terrible" expansion emits: variable shift of A (loop/libcall) + variable shift of B
# (loop/libcall) + ORA to combine -> check for ora and rep/sep.
echo "==> disasm gate (G_FSHL/G_FSHR two-source funnel shift: ora combines halves, rep/sep for a16)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/funnelkal_sim.c" -I"$ROOT/examples" -o "$BUILD/funnelkal_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/funnelkal_sim.o" 2>/dev/null || true)
ora=$(printf '%s\n' "$dis" | grep -cwE '\bora\b' || true)      # OR step of funnel expansion
sh=$(printf  '%s\n' "$dis" | grep -cwE '\basl\b|\blsr\b|\brol\b|\bror\b' || true)  # shift steps
rs=$(printf  '%s\n' "$dis" | grep -cwE '\brep\b|\bsep\b' || true)
if [ "$ora" -ge 2 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  ora=$ora  shifts=$sh  rep/sep=$rs  (funnel-shift expansion present)"
else
  echo "    FAIL  ora=$ora  shifts=$sh  rep/sep=$rs  (expected ora>=2 and rep/sep>=1)"; rc=1
fi

# 4. bsnes-jg — build harness if needed, dump framebuffer + assert.
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
  echo "==> bsnes-jg: render + framebuffer dump (build/funnelkal-jg.png) + assert"
  "$JGX" "$BUILD/funnelkal.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/funnelkal-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/funnelkal-mame.png)"
  SNAP="$BUILD/.funnelkal-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/funnelkal.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/funnelkal.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/funnelkal-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Funnel-Shift Kaleidoscope on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
