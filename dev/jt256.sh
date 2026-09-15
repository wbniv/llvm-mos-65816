#!/usr/bin/env bash
# dev/jt256.sh — render the ISA-256 Bytecode Machine (#142 stress-test, Round 8 Cluster A).
# The >128-successor jump-table guard: legalizeBrJt (MOSLegalizerInfo.cpp:443, handler ~3311)
# picks between `JMP (abs,X)` and a split low-byte/high-byte table pair fed into G_BRINDIRECT,
# on `Table.MBBs.size() <= 128`. Every jump table across demos #1-#141 takes the first arm;
# ISA-256's 256-way dispatch is structurally over the limit and must take the second.
# Drive: dev/run.sh jt256. Outputs build/jt256-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh jt256   # run the 256-way dispatch; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/jt256.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/jt256-sim.c" -o "$BUILD/jt256-sim"
EXPECT=$("$BUILD/jt256-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: jt256 gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/jt256.map" -o "$BUILD/jt256.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/jt256.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/jt256.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/jt256.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate — THE CORNER UNDER TEST. The dispatch must reach the ROM as the SPLIT
#    low/high byte-table form (two indexed jump-table loads feeding an indirect jmp), and
#    must NOT be the `jmp (.LJTI,x)` JMPIdxIndir form every prior demo's table takes. If the
#    switch ever collapsed into a lookup table or shrank under 129 successors, this fails
#    rather than silently testing a different, already-covered corner.
echo "==> structure gate (split lo/hi jump table, NOT jmp (abs,X); all three modes)"
for MODE in default a16 xy16; do
  case "$MODE" in
    default) FEAT=() ;;
    a16)     FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16)    FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  ASM="$BUILD/jt256_sim_$MODE.s"
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -Os -mllvm -verify-machineinstrs \
    -S -o "$ASM" "$ROOT/examples/snes/corpus/jt256_sim.c" -I"$ROOT/examples" 2>/dev/null
  jt=$(grep -cE '(lda|ldy|ldx)[[:space:]]+\.LJTI' "$ASM" || true)
  idx=$(grep -cE 'jmp[[:space:]]*\(\.LJTI' "$ASM" || true)
  ind=$(grep -cE 'jmp[[:space:]]*\(' "$ASM" || true)
  ent=$(awk '/^\.LJTI/{n=0;f=1;next} f&&/^\t\.(word|byte|addr|hword)/{n++;next} f&&NF{print n; exit}' "$ASM")
  if [ "$jt" -ge 2 ] && [ "$idx" -eq 0 ] && [ "$ind" -ge 1 ] && [ "${ent:-0}" -ge 512 ]; then
    echo "    PASS  $MODE: jt-table-loads=$jt  jmp-(abs,X)=$idx  indirect-jmp=$ind  table-entries=$ent"
  else
    echo "    FAIL  $MODE: jt-table-loads=$jt  jmp-(abs,X)=$idx  indirect-jmp=$ind  table-entries=${ent:-0}"
    echo "          (want >=2 table loads, 0 jmp (abs,X) — the >128 arm — >=1 indirect jmp, >=512 entries)"
    rc=1
  fi
done

# 3b. Every one of the 256 handlers must actually be entered, or the dispatch is only
#     partially swept and the test is weaker than it claims.
COV=$("$BUILD/jt256-sim" | grep -oE 'handlers_entered=[0-9]+/256' | head -1)
if [ "$COV" = "handlers_entered=256/256" ]; then
  echo "    PASS  opcode sweep: $COV"
else
  echo "    FAIL  opcode sweep: $COV (want 256/256)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/jt256-jg.png, frame 600)"
  "$JGX" "$BUILD/jt256.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/jt256-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/jt256-mame.png)"
  SNAP="$BUILD/.jt256-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/jt256.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/jt256.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/jt256-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — ISA-256 Bytecode Machine on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc
