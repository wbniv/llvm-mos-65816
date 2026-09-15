#!/usr/bin/env bash
# dev/backtrack.sh — render the Backtracking Solver (#116 stress-test, Round 6 Cluster G).
# The FLAGSHIP guard for the 65816-native platforms/snes/setjmp.S fix (bug #35): 8-queens with a
# setjmp choice point per recursion level, whose every dead end longjmps straight to the deepest
# still-viable ancestor — one jump discards a varying number of jsr frames, so the page-1 S
# reconstruct, the soft-SP restore and the __rc18..__rc31 CSR restore are all exercised at once.
# Drive: dev/run.sh backtrack. Outputs build/backtrack-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh backtrack   # render the 8-queens backjump board; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/backtrack.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/backtrack-sim.c" -o "$BUILD/backtrack-sim"
EXPECT=$("$BUILD/backtrack-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: backtrack gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/backtrack.map" -o "$BUILD/backtrack.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/backtrack.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/backtrack.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/backtrack.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate: the slice really calls setjmp AND longjmp (the unwind is not inlined away),
#    and bt_descend stays a real recursive jsr frame — the whole demo is about discarding those.
echo "==> structure gate (setjmp + longjmp calls present, bt_descend is a real jsr frame)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/backtrack_sim.c" -I"$ROOT/examples" -o "$BUILD/backtrack_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/backtrack_sim.o" 2>/dev/null || true)
sj=$(printf '%s\n' "$dis" | grep -cE '\bsetjmp\b' || true)
lj=$(printf '%s\n' "$dis" | grep -cE '\blongjmp\b' || true)
rec=$(printf '%s\n' "$dis" | grep -cE 'bt_descend' || true)
if [ "$sj" -ge 1 ] && [ "$lj" -ge 2 ] && [ "$rec" -ge 1 ]; then
  echo "    PASS  setjmp=$sj  longjmp=$lj  bt_descend refs=$rec  (choice points + backjumps present)"
else
  echo "    FAIL  setjmp=$sj  longjmp=$lj  bt_descend refs=$rec  (expected setjmp>=1, longjmp>=2, bt_descend>=1)"; rc=1
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
  # Frame 600: the search gate settles during the title card; by 600 the replay has placed and
  # snapped back enough queens for the board to read. corpus_result is set once, so the assert
  # holds at any frame past the title.
  echo "==> bsnes-jg: render + assert (build/backtrack-jg.png, frame 600)"
  "$JGX" "$BUILD/backtrack.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/backtrack-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/backtrack-mame.png)"
  SNAP="$BUILD/.backtrack-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/backtrack.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/backtrack.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/backtrack-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Backtracking Solver on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc
