#!/usr/bin/env bash
# dev/rotozoom.sh — render the Rotozoom demo (#56 compiler stress-test) ON
# the SNES (examples/snes/rotozoom.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/rotozoom-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/rotozoom.lua snapshots + asserts.
# Plus a disasm gate proving the hot loop is the Q16.16 WIDENING MULTIPLY-HIGH (q16mul = (int64)a*b>>16,
# G_SMULH/G_UMULH .lower() @300 = extend/mul/shift/trunc, via __muldi3 on this soft-multiply target).
# The gate is heavy (each iter ~18 __muldi3), so the snapshot/assert frame is 700 (not 500).
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh rotozoom. Outputs build/rotozoom-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh rotozoom   # render the affine rotozoom; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/rotozoom.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; rotozoom.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/rotozoom-sim.c" -o "$BUILD/rotozoom-sim"
EXPECT=$("$BUILD/rotozoom-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: rotozoom gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/rotozoom.map" -o "$BUILD/rotozoom.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/rotozoom.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/rotozoom.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/rotozoom.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the Q16.16 widening multiply-high (q16mul = (int64)a*b >> 16) is the G_SMULH/G_UMULH
# `.lower()` expansion (@300) = extend -> mul -> shift -> trunc; on this soft-multiply target that goes
# through __muldi3 (32x32->64), with the Q8.8 coefficient products via __mulsi3, and SINCOS referenced.
echo "==> disasm gate (widening multiply-high: Q16.16 q16mul via __muldi3, extend/mul/shift/trunc)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/rotozoom_sim.c" -I"$ROOT/examples" -o "$BUILD/rotozoom_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/rotozoom_sim.o" 2>/dev/null || true)
mdi=$(printf '%s\n' "$dis" | grep -c '__muldi3' || true)   # widening 32x32->64 for the mul-high
msi=$(printf '%s\n' "$dis" | grep -c '__mulsi3' || true)   # Q8.8 coefficient products
sc=$(printf  '%s\n' "$dis" | grep -c 'SINCOS' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$mdi" -ge 1 ] && [ "$msi" -ge 1 ] && [ "$sc" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __muldi3=$mdi  __mulsi3=$msi  SINCOS-refs=$sc  rep/sep=$rs  (widening multiply-high)"
else
  echo "    FAIL  __muldi3=$mdi  __mulsi3=$msi  SINCOS-refs=$sc  rep/sep=$rs  (expected muldi3>=1,mulsi3>=1,SINCOS>=1,rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/rotozoom-jg.png) + assert"
  "$JGX" "$BUILD/rotozoom.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 700 "$BUILD/rotozoom-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/rotozoom-mame.png)"
  SNAP="$BUILD/.rotozoom-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/rotozoom.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/rotozoom.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/rotozoom-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — affine rotozoom rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
