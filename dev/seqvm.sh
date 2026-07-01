#!/usr/bin/env bash
# dev/seqvm.sh — render the Sparse-Switch Step-Sequencer VM demo (#37 compiler stress-test) ON the
# SNES (examples/snes/seqvm.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/seqvm-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/seqvm.lua snapshots + asserts.
# Plus a disasm gate proving the opcode dispatch is a SPARSE-SWITCH COMPARISON TREE: a cascade of
# immediate compares (>= 8) with NO indexed-indirect jump (jmp (...) == 0) — distinct from #29a's
# dense jump table and #38's computed goto. Control-flow only: no __mul/__udiv probe.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh seqvm. Outputs build/seqvm-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh seqvm   # render the sparse-switch step-sequencer VM; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/seqvm.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; seqvm.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/seqvm-sim.c" -o "$BUILD/seqvm-sim"
EXPECT=$("$BUILD/seqvm-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: seqvm gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/seqvm.map" -o "$BUILD/seqvm.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/seqvm.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/seqvm.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/seqvm.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the sparse switch must lower to a comparison tree — many immediate compares and
# NO indexed-indirect jump (that would be a jump table / computed goto).
echo "==> disasm gate (sparse-switch comparison tree)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/seqvm_sim.c" -I"$ROOT/examples" -o "$BUILD/seqvm_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/seqvm_sim.o" 2>/dev/null || true)
cmp=$(printf '%s\n' "$dis" | grep -cE '\bcmp\b|\bcpx\b|\bcpy\b' || true)
jind=$(printf '%s\n' "$dis" | grep -cE '\bjmp\b[[:space:]]*\(' || true)   # indexed-indirect jmp => table
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$cmp" -ge 8 ] && [ "$jind" -eq 0 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  compares=$cmp  indirect-jmp=$jind  rep/sep=$rs  (comparison tree, not a jump table)"
else
  echo "    FAIL  compares=$cmp  indirect-jmp=$jind  rep/sep=$rs  (expected compares>=8, indirect-jmp=0, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/seqvm-jg.png) + assert"
  "$JGX" "$BUILD/seqvm.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/seqvm-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/seqvm-mame.png)"
  SNAP="$BUILD/.seqvm-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/seqvm.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/seqvm.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/seqvm-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — sparse-switch step-sequencer VM rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
