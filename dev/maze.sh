#!/usr/bin/env bash
# dev/maze.sh — render the Maze generate+solve demo (#18 compiler stress-test) ON the SNES
# (examples/snes/maze.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/maze-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/maze.lua snapshots + asserts (skipped without the SPC700 IPL).
# Plus a disasm gate proving the carve recursion survived (a JSR back to maze_divide) and the
# heap/A* math is native-16 (rep/sep). The full 5-way differential (host==default==+mos-a16==
# +mos-xy16) is the corpus slice gate (examples/snes/corpus/maze_sim.c).
#
# Drive: dev/run.sh maze.  Outputs build/maze-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh maze   # render the maze gen+solve demo on SNES; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/maze.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; maze.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/maze-sim.c" -o "$BUILD/maze-sim"
EXPECT=$("$BUILD/maze-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: maze generate+solve gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/maze.map" -o "$BUILD/maze.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/maze.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/maze.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/maze.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the carve recursion must survive (a JSR whose target is maze_divide itself) and
# the heap/A* math must be native-16 (rep/sep). This demo deliberately has NO 32-bit libcalls — it
# stresses recursion + branchy heap/array code, a different profile from the multiply/divide demos.
echo "==> disasm gate (recursion self-call + native-16 codegen)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/maze_sim.c" -I"$ROOT/examples" -o "$BUILD/maze_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/maze_sim.o" 2>/dev/null || true)
rec=$(printf '%s\n' "$dis" | grep -cE 'R_MOS_ADDR16[[:space:]]+\.text\.maze_divide$' || true)
rs=$(printf '%s\n'  "$dis" | grep -cwE 'rep|sep' || true)
if [ "$rec" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  recursion(maze_divide self-call)=$rec  rep/sep=$rs  (genuine recursion + native-16)"
else
  echo "    FAIL  recursion=$rec  rep/sep=$rs  (expected both >= 1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/maze-jg.png) + assert"
  "$JGX" "$BUILD/maze.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 400 "$BUILD/maze-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert. Needs the SPC700 IPL; skip cleanly
# when it is absent (the deterministic bsnes-jg leg + the browser carry the demo bar).
if command -v xvfb-run >/dev/null 2>&1 && [ -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/maze-mame.png)"
  SNAP="$BUILD/.maze-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/maze.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/maze.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/maze-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run or no SPC700 IPL — bsnes-jg + browser carry the bar)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — maze gen+solve rendered on SNES; bsnes-jg (+ MAME if present) + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
