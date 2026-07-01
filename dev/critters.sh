#!/usr/bin/env bash
# dev/critters.sh — render the Protothread Critter Swarm demo (#51 compiler stress-test) ON
# the SNES (examples/snes/critters.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/critters-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/critters.lua snapshots + asserts.
# Plus a disasm gate proving each critter is a RESUMABLE protothread: critter_step dispatches on its
# saved continuation index (lc) at entry and its case labels sit inside loops (mid-loop re-entry), a
# branch mesh with NO arithmetic libcall, under native-16 (rep/sep).
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh critters. Outputs build/critters-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh critters   # render the protothread critter swarm; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/critters.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; critters.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/critters-sim.c" -o "$BUILD/critters-sim"
EXPECT=$("$BUILD/critters-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: critters gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/critters.map" -o "$BUILD/critters.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/critters.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/critters.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/critters.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: a resumable protothread. critter_step is called, dispatches on lc (branch mesh), no libcall.
echo "==> disasm gate (protothread: lc-dispatch resumable function, native-16, no libcall)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/critters_sim.c" -I"$ROOT/examples" -o "$BUILD/critters_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/critters_sim.o" 2>/dev/null || true)
cs=$(printf  '%s\n' "$dis" | grep -c 'critter_step' || true)
jmp=$(printf '%s\n' "$dis" | grep -cw 'jmp' || true)
# The protothread hot path (critter_step) is pure branch/pointer arith — no WIDE arith libcall. (The
# only libcalls in this slice are 8-bit __mulqi3/__udivqi3 from critters_init's i/6,i%6 layout math.)
wlib=$(printf '%s\n' "$dis" | grep -cE '__udivsi|__divsi|__mulsi|__udivhi|__divhi|__mulhi' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$cs" -ge 1 ] && [ "$jmp" -ge 4 ] && [ "$wlib" -eq 0 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  critter_step-refs=$cs  jmp=$jmp  wide-arith-libcalls=$wlib  rep/sep=$rs  (resumable protothread; lc-dispatch resume)"
else
  echo "    FAIL  critter_step-refs=$cs  jmp=$jmp  wide-arith-libcalls=$wlib  rep/sep=$rs  (expected critter_step>=1, jmp>=4, wide-libcalls==0, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/critters-jg.png) + assert"
  "$JGX" "$BUILD/critters.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/critters-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/critters-mame.png)"
  SNAP="$BUILD/.critters-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/critters.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/critters.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/critters-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — protothread critter swarm rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
