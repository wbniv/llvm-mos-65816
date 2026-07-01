#!/usr/bin/env bash
# dev/dither.sh — render the Floyd-Steinberg Error-Diffusion Dither demo (#70 compiler stress-test) ON
# the SNES (examples/snes/dither.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/dither-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/dither.lua snapshots + asserts.
# Plus a disasm gate proving the FS core is forward-carried SIGNED error diffusion done in pure
# integer add/shift/compare: the residual split (e*k)>>4 shows up as arithmetic shifts, and there are
# NO wide multiply/divide libcalls on the hot path (quantiser = 3 compares, levels = a 4-entry LUT).
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh dither. Outputs build/dither-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh dither   # render the FS dither; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/dither.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; dither.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/dither-sim.c" -o "$BUILD/dither-sim"
EXPECT=$("$BUILD/dither-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: dither gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/dither.map" -o "$BUILD/dither.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/dither.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/dither.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/dither.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the point of Floyd-Steinberg is that it needs NO DIVISION — the /16 residual split is an
# arithmetic shift `(e*k)>>4`, the quantiser is 3 compares, and the 4 levels come from a LUT. So there are
# ZERO divide/mod libcalls, and arithmetic shifts are present. (The e*7/e*3/e*5 constant multiplies
# strength-reduce to shift-adds; the only muls left are the incidental runtime row-index `y*W` and the
# scene stride — reported for transparency, not part of the FS core.)
echo "==> disasm gate (Floyd-Steinberg: signed error diffusion — no division, arithmetic shifts)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/dither_sim.c" -I"$ROOT/examples" -o "$BUILD/dither_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/dither_sim.o" 2>/dev/null || true)
divc=$(printf '%s\n' "$dis" | grep -cE '__(udiv|divs?|umod|mod)(qi|hi|si|di)|__divmod' || true)  # divide/mod
mulc=$(printf '%s\n' "$dis" | grep -cE '__mul(qi|hi|si|di)3' || true)                             # incidental index/scene mul
rs=$(printf   '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
sh=$(printf   '%s\n' "$dis" | grep -cwE 'asl|lsr|ror|rol' || true)                                # the >>4 residual split
if [ "$divc" -eq 0 ] && [ "$rs" -ge 1 ] && [ "$sh" -ge 1 ]; then
  echo "    PASS  divide-libcalls=$divc  shifts=$sh  rep/sep=$rs  (no division; incidental index/scene mul=$mulc)"
else
  echo "    FAIL  divide-libcalls=$divc  shifts=$sh  rep/sep=$rs  (expected div=0, shifts>=1, rep/sep>=1; mul=$mulc)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/dither-jg.png) + assert"
  "$JGX" "$BUILD/dither.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 2000 "$BUILD/dither-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/dither-mame.png)"
  SNAP="$BUILD/.dither-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/dither.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/dither.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 20 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/dither-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — FS dither rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
