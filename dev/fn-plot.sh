#!/usr/bin/env bash
# dev/fn-plot.sh — render the fn-plot recursive-descent function plotter (#24) on the SNES
# (examples/snes/fn-plot.c, +mos-a16) and assert corpus_result == host oracle on both emulators.
# Plus a disasm gate proving soft-float libcalls + recursive calls + rep/sep are present.
# Drive: dev/run.sh fn-plot
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh fn-plot   # render the fn-plot demo on SNES; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ]            || { echo "FATAL: SDK not built (run: dev/run.sh build)"; exit 1; }

# §1. Host oracle: compile fn_plot.h on the host and get the golden gate hash.
cc -O2 -std=c99 -I "$ROOT/examples/65816" "$ROOT/tools/fn-plot-sim.c" -o "$BUILD/fn-plot-sim"
EXPECT=$("$BUILD/fn-plot-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: fn-plot gate hash = $EXPECT"

# §2. Build the SNES ROM (+mos-a16) and locate corpus_result in the map.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/fn-plot.map" -o "$BUILD/fn-plot.sfc" \
  "$ROOT/examples/snes/fn-plot.c"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/fn-plot.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/fn-plot.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/fn-plot.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# §3. Disasm gate: the corpus slice must contain soft-float libcalls + rep/sep.
# __mulsf3: x*x in every expression.
# __divsf3: x/(x*x+1.0) in expression 2 (compiled even though gate uses expr 0).
# rep/sep:  native-16 mode brackets under +mos-a16.
echo "==> disasm gate (soft-float libcalls + recursive calls + native-16)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/fn_plot_sim.c" \
  -I"$ROOT/examples" -o "$BUILD/fn_plot_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/fn_plot_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis"  | grep -c '__mulsf3'   || true)
div=$(printf '%s\n' "$dis"  | grep -c '__divsf3'   || true)
fsi=$(printf '%s\n' "$dis"  | grep -c '__fixsfsi'  || true)
rs=$(printf  '%s\n' "$dis"  | grep -cwE 'rep|sep'  || true)
if [ "$mul" -ge 2 ] && [ "$div" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __mulsf3=$mul  __divsf3=$div  __fixsfsi=$fsi  rep/sep=$rs"
else
  echo "    FAIL  __mulsf3=$mul (exp>=2)  __divsf3=$div (exp>=1)  rep/sep=$rs (exp>=1)"; rc=1
fi

# §4. bsnes-jg: render + assert.
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
  echo "==> bsnes-jg: render + framebuffer dump (build/fn-plot-jg.png) + assert"
  "$JGX" "$BUILD/fn-plot.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/fn-plot-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent)"
fi

# §5. MAME under Xvfb: snapshot + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (Xvfb): snapshot + assert (build/fn-plot-mame.png)"
  SNAP="$BUILD/.fn-plot-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/fn-plot.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/fn-plot.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/fn-plot-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — fn-plot rendered on SNES; corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see per-emulator lines above"
fi
exit $rc
