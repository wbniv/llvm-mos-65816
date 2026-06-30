#!/usr/bin/env bash
# dev/hilbert.sh — render the Hilbert curve demo (#28 compiler stress-test) ON the SNES.
# Hot op: hil_d2xy uses __ashlsi3(rx,k) and __ashlsi3(1,k) — variable-count 32-bit shifts.
# Drive: dev/run.sh hilbert. Outputs build/hilbert-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh hilbert   # render the Hilbert curve demo on SNES + assert"; exit 0;; esac

ROOT=/work; BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/hilbert.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/hilbert-sim.c" -o "$BUILD/hilbert-sim"
EXPECT=$("$BUILD/hilbert-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: Hilbert gate hash = $EXPECT"

# 2. Build ROM (+mos-a16)
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/hilbert.map" -o "$BUILD/hilbert.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/hilbert.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/hilbert.map")
OFF="0x$VMA"; ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/hilbert.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: must have __ashlsi3 or __lshrsi3 (variable-count 32-bit shifts).
# The loop variable k (0..ORDER-1) drives shifts of runtime size → libcall, not inline.
echo "==> disasm gate (variable-count 32-bit shifts: __ashlsi3 / __lshrsi3)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/hilbert_sim.c" \
  -I"$ROOT/examples" -o "$BUILD/hilbert_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/hilbert_sim.o" 2>/dev/null || true)
shl=$(printf '%s\n' "$dis" | grep -cE '__ashlsi3|__lshrsi3|__ashrsi3' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3' || true)
if [ "$shl" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __ashlsi3+__lshrsi3=$shl  rep/sep=$rs  __mulsi3=$mul  (variable-count 32-bit shifts)"
else
  echo "    FAIL  shift_libcalls=$shl  rep/sep=$rs  (expected shl>=1, rep/sep>=1)"; rc=1
fi

# 4. bsnes-jg
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
  echo "==> bsnes-jg: render + framebuffer dump (build/hilbert-jg.png) + assert"
  "$JGX" "$BUILD/hilbert.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/hilbert-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent)"
fi

# 5. MAME
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL — gitignored; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (Xvfb): snapshot + assert (build/hilbert-mame.png)"
  SNAP="$BUILD/.hilbert-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/hilbert.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/hilbert.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/hilbert-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Hilbert curve rendered on SNES; hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see per-emulator lines above"
fi
exit $rc
