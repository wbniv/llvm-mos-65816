#!/usr/bin/env bash
# dev/newton.sh — render the Newton's-method fractal demo (#2 compiler stress-test)
# on the SNES (+mos-a16) and assert corpus_result == host oracle on MAME + bsnes-jg.
# Disasm gate: __divsi3 (complex division) + __mulsi3 (complex multiply) + rep/sep.
# Full 5-way differential is the corpus-a16 slice gate (newton_sim.c).
# Drive: dev/run.sh newton.  Outputs build/newton-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh newton   # render Newton fractal; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ]            || { echo "FATAL: SDK/snes not built (run: dev/run.sh build)"; exit 1; }

# §1. Host oracle: golden gate hash (differential anchor; newton.h compiled host-side).
cc -O2 -I "$ROOT/examples" "$ROOT/tools/newton-sim.c" -o "$BUILD/newton-sim"
EXPECT=$("$BUILD/newton-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: Newton fractal gate_crc = $EXPECT"

# §2. Build the on-console ROM (+mos-a16) and locate corpus_result in the link map.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/newton.map" -o "$BUILD/newton.sfc" \
  "$ROOT/examples/snes/newton.c"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/newton.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/newton.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/newton.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# §3. Disasm gate: complex Newton iteration must contain __divsi3 + __mulsi3 + rep/sep.
echo "==> disasm gate (complex division + multiply + native-16 mode)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/newton_sim.c" \
  -I"$ROOT/examples" -o "$BUILD/newton_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/newton_sim.o" 2>/dev/null || true)
div=$(printf '%s\n' "$dis" | grep -cE '__divsi3|__udivsi3'  || true)
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3'  || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep'            || true)
if [ "$div" -ge 1 ] && [ "$mul" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __divsi3=$div  __mulsi3=$mul  rep/sep=$rs"
else
  echo "    FAIL  __divsi3=$div  __mulsi3=$mul  rep/sep=$rs  (expected all >= 1)"; rc=1
fi

# §4. bsnes-jg — build the harness if needed, then dump framebuffer + assert.
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    echo "==> building jgxcheck harness"
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" \
        -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + framebuffer dump (build/newton-jg.png) + assert"
  "$JGX" "$BUILD/newton.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/newton-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# §5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/newton-mame.png)"
  SNAP="$BUILD/.newton-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/newton.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/newton.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/newton-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Newton fractal rendered on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see per-emulator lines above"
fi
exit $rc
