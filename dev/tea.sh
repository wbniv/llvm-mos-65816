#!/usr/bin/env bash
# dev/tea.sh — render the TEA cipher avalanche demo (#30 compiler stress-test) ON the SNES.
# Hot loop: 32-bit <<4, >>5, +, ^ — no multiply, no divide. Novel 32-bit shift/add/XOR corner.
# Drive: dev/run.sh tea. Outputs build/tea-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh tea   # render the TEA cipher avalanche demo on SNES + assert"; exit 0;; esac

ROOT=/work; BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/tea.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/tea-sim.c" -o "$BUILD/tea-sim"
EXPECT=$("$BUILD/tea-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: TEA gate hash = $EXPECT"

# 2. Build ROM (+mos-a16)
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/tea.map" -o "$BUILD/tea.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/tea.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/tea.map")
OFF="0x$VMA"; ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/tea.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: must have rep/sep (32-bit ops under +mos-a16); NO multiply libcall.
# Constant <<4/>>5 may be inlined (ASL/ROL chains) or delegated to __ashlsi3/__lshrsi3 at -Os.
echo "==> disasm gate (32-bit add/XOR/shift chain, multiply-free)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/tea_sim.c" \
  -I"$ROOT/examples" -o "$BUILD/tea_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/tea_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3|__mulsf3' || true)
shl=$(printf '%s\n' "$dis" | grep -cE '__ashlsi3|__lshrsi3|__ashrsi3' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$mul" -eq 0 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __mulsi3=$mul  shift_libcalls=$shl  rep/sep=$rs  (32-bit add/xor/shift, multiply-free)"
else
  echo "    FAIL  __mulsi3=$mul  shift_libcalls=$shl  rep/sep=$rs  (expected mul=0, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/tea-jg.png) + assert"
  "$JGX" "$BUILD/tea.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/tea-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent)"
fi

# 5. MAME
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL — gitignored; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (Xvfb): snapshot + assert (build/tea-mame.png)"
  SNAP="$BUILD/.tea-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/tea.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/tea.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/tea-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — TEA cipher avalanche rendered on SNES; hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see per-emulator lines above"
fi
exit $rc
