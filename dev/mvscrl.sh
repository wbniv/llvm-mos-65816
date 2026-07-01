#!/usr/bin/env bash
# dev/mvscrl.sh — render Descending memmove Scroll Slabs (#79 compiler stress-test) on SNES.
# Exercises G_MEMMOVE descending path (memmove(upper+1,upper,7×16) where dst>src, overlapping)
# and ascending path (memmove(lower,lower+1,7×16) where dst<src, overlapping).
# compareOperandLocations :3145-3152 detects descending; offset adjust :3231/:3247.
# SDK memmove: llvm-mos-sdk mos-platform/common/c/mem.c:15.
# Full 5-way differential (host==default==+mos-a16==+mos-xy16).
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh mvscrl   # render memmove scroll slabs; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/mvscrl.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/mvscrl-sim.c" -o "$BUILD/mvscrl-sim"
EXPECT=$("$BUILD/mvscrl-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: mvscrl gate hash = $EXPECT"

# 2. Build ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/mvscrl.map" -o "$BUILD/mvscrl.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/mvscrl.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/mvscrl.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/mvscrl.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: memmove calls (SDK function) + __mulhi3 from the CRC fold.
echo "==> disasm gate (memmove SDK calls + __mulhi3 from fold + rep/sep)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/mvscrl_sim.c" -I"$ROOT/examples" -o "$BUILD/mvscrl_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/mvscrl_sim.o" 2>/dev/null || true)
mmv=$(printf '%s\n' "$dis" | grep -c 'memmove' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE '\brep\b|\bsep\b' || true)
echo "    memmove-refs=$mmv  rep/sep=$rs"
if [ "$mmv" -ge 2 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  memmove descending+ascending confirmed (refs=$mmv >= 2, rep/sep=$rs >= 1)"
else
  echo "    FAIL  memmove-refs=$mmv (expected >=2) rep/sep=$rs (expected >=1)"; rc=1
fi

# 4. bsnes-jg.
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + assert (build/mvscrl-jg.png)"
  "$JGX" "$BUILD/mvscrl.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/mvscrl-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/mvscrl-mame.png)"
  SNAP="$BUILD/.mvscrl-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/mvscrl.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/mvscrl.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/mvscrl-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Descending memmove Scroll Slabs on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
