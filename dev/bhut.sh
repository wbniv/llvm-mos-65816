#!/usr/bin/env bash
# dev/bhut.sh — render the Barnes-Hut quadtree galaxy demo (#31 compiler stress-test) ON the SNES.
# Codegen corner: pointer-chasing dynamic trees — recursive bh_insert/bh_force walk runtime
# child[] indices through a node pool (JSR-to-self tree-shaped call graph) + __mulsi3/__divsi3.
# Drive: dev/run.sh bhut. Outputs build/bhut-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh bhut   # render the Barnes-Hut galaxy demo on SNES + assert"; exit 0;; esac

ROOT=/work; BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/bhut.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/bhut-sim.c" -o "$BUILD/bhut-sim"
EXPECT=$("$BUILD/bhut-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | head -1)
echo "==> host oracle: Barnes-Hut gate hash = $EXPECT"

# 2. Build ROM (+mos-a16)
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/bhut.map" -o "$BUILD/bhut.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/bhut.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/bhut.map")
OFF="0x$VMA"; ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/bhut.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: recursive tree walk (bh_force self-call) + __mulsi3 + __divsi3.
echo "==> disasm gate (pointer-chasing tree walk + mul/div gravity kernel)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/bhut_sim.c" \
  -I"$ROOT/examples" -o "$BUILD/bhut_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/bhut_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3'   || true)
div=$(printf '%s\n' "$dis" | grep -cE '__divsi3|__udivsi3'   || true)
rec=$(printf '%s\n' "$dis" | grep -c  'bh_force'             || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep'             || true)
if [ "$mul" -ge 1 ] && [ "$div" -ge 1 ] && [ "$rec" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __mulsi3=$mul  __divsi3=$div  bh_force_refs=$rec  rep/sep=$rs  (tree walk + gravity)"
else
  echo "    FAIL  __mulsi3=$mul  __divsi3=$div  bh_force_refs=$rec  rep/sep=$rs  (expected all >= 1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/bhut-jg.png) + assert"
  "$JGX" "$BUILD/bhut.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/bhut-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent)"
fi

# 5. MAME
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL — gitignored; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (Xvfb): snapshot + assert (build/bhut-mame.png)"
  SNAP="$BUILD/.bhut-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/bhut.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/bhut.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/bhut-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Barnes-Hut galaxy rendered on SNES; hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see per-emulator lines above"
fi
exit $rc
