#!/usr/bin/env bash
# dev/epicycles.sh — render the Fourier-epicycles demo (#10 compiler stress-test) ON the SNES
# (examples/snes/epicycles.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/epicycles-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/epicycles.lua snapshots + asserts (skipped without the SPC700 IPL).
# Plus a disasm gate proving the hot loop has the per-harmonic complex multiply (__mulsi3) + native-16
# (rep/sep), and NO 32-bit divide (the many-multiply profile). The full 5-way differential
# (host==default==+mos-a16==+mos-xy16) is the corpus slice gate (examples/snes/corpus/epicycles_sim.c).
#
# Drive: dev/run.sh epicycles.  Outputs build/epicycles-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh epicycles   # render the Fourier-epicycles demo on SNES; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/epicycles.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; epicycles.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/epicycles-sim.c" -o "$BUILD/epicycles-sim"
EXPECT=$("$BUILD/epicycles-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: Fourier-epicycles gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/epicycles.map" -o "$BUILD/epicycles.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/epicycles.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/epicycles.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/epicycles.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the per-harmonic complex multiply must be present (__mulsi3) and native-16
# (rep/sep); and there must be NO 32-bit divide (this is the many-multiply, not the divide, profile).
echo "==> disasm gate (complex-multiply + native-16, no divide)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/epicycles_sim.c" -I"$ROOT/examples" -o "$BUILD/epicycles_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/epicycles_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
dv=$(printf  '%s\n' "$dis" | grep -cE '__udivsi3|__divsi3|__udivmodsi4' || true)
if [ "$mul" -ge 1 ] && [ "$rs" -ge 1 ] && [ "$dv" -eq 0 ]; then
  echo "    PASS  __mulsi3=$mul  rep/sep=$rs  divide=$dv  (complex multiply + native-16, divide-free)"
else
  echo "    FAIL  __mulsi3=$mul  rep/sep=$rs  divide=$dv  (expected mul>=1, rep/sep>=1, divide==0)"; rc=1
fi

# 4. bsnes-jg — build the harness if needed, then dump framebuffer + assert (frame 500 = full star).
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
  echo "==> bsnes-jg: render + framebuffer dump (build/epicycles-jg.png) + assert"
  "$JGX" "$BUILD/epicycles.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/epicycles-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot + assert. Needs the SPC700 IPL; skip cleanly when absent.
if command -v xvfb-run >/dev/null 2>&1 && [ -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/epicycles-mame.png)"
  SNAP="$BUILD/.epi-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/epicycles.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/epicycles.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/epicycles-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run or no SPC700 IPL — bsnes-jg + browser carry the bar)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Fourier epicycles rendered on SNES; bsnes-jg (+ MAME if present) + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
