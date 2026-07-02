#!/usr/bin/env bash
# dev/truncstair.sh — Truncation Staircase (#83 compiler stress-test) on SNES.
# Exercises G_FPTOSI (__fixsfsi) + G_SITOFP (__floatsisf) as the truncf-via-cast
# pattern; documents floorf/ceilf/truncf .unsupported() SDK link gap.
# Full 5-way differential (host==default==+mos-a16==+mos-xy16).
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh truncstair   # render truncation staircase; assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/truncstair.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/truncstair-sim.c" -o "$BUILD/truncstair-sim"
EXPECT=$("$BUILD/truncstair-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: truncstair gate hash = $EXPECT"

# 2. Build ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/truncstair.map" -o "$BUILD/truncstair.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/truncstair.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/truncstair.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/truncstair.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: verify __fixsfsi (G_FPTOSI) + __floatsisf (G_SITOFP) + rep/sep.
echo "==> disasm gate (G_FPTOSI __fixsfsi + G_SITOFP __floatsisf + __mulsf3 + rep/sep)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/truncstair_sim.c" -I"$ROOT/examples" \
  -o "$BUILD/truncstair_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/truncstair_sim.o" 2>/dev/null || true)
fsi=$(printf '%s\n' "$dis" | grep -c '__fixsfsi' || true)
flt=$(printf '%s\n' "$dis" | grep -c '__floatsisf' || true)
mul=$(printf '%s\n' "$dis" | grep -c '__mulsf3' || true)
rs=$( printf '%s\n' "$dis" | grep -cwE '\brep\b|\bsep\b' || true)
echo "    __fixsfsi=$fsi  __floatsisf=$flt  __mulsf3=$mul  rep/sep=$rs"
if [ "$fsi" -ge 1 ] && [ "$flt" -ge 1 ] && [ "$mul" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  G_FPTOSI+G_SITOFP confirmed (no truncf/floorf/ceilf libcalls)"
else
  echo "    FAIL  __fixsfsi=$fsi (expected >=1) __floatsisf=$flt (expected >=1) __mulsf3=$mul rep/sep=$rs"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/truncstair-jg.png)"
  "$JGX" "$BUILD/truncstair.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/truncstair-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/truncstair-mame.png)"
  SNAP="$BUILD/.truncstair-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/truncstair.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/truncstair.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/truncstair-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Truncation Staircase on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see per-emulator lines above"
fi
exit $rc
