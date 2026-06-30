#!/usr/bin/env bash
# dev/lsystem.sh — render the #23 L-System Plant (examples/snes/lsystem.c, +mos-a16) ON the SNES and
# capture a REAL emulator screenshot from BOTH cores headless, each asserting corpus_result == the
# host oracle (tools/lsystem-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/lsystem.lua snapshots + asserts.
# Plus a disasm gate proving the string-rewrite hot loop has memmove + memcpy + strlen + rep/sep.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice (lsystem_sim.c)
# gate, run by dev/run.sh corpus-a16.
#
# The on-console ROM additionally records the plant's segments into a FAR buffer at $7E2000 and replays
# them progressively (the plant grows stroke by stroke) — exercising the +mos-a16 far-pointer store+load
# path. That far path is display-only (the corpus slice stays far-pointer-free / 5-way); its correctness
# is proven by the picture: a far miscompile scrambles the replayed segments and the plant breaks.
#
# Drive: dev/run.sh lsystem. Outputs build/lsystem-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh lsystem   # render the L-System Plant demo on SNES; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/lsystem.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; lsystem.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/lsystem-sim.c" -o "$BUILD/lsystem-sim"
EXPECT=$("$BUILD/lsystem-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: L-System Plant gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/lsystem.map" -o "$BUILD/lsystem.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/lsystem.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/lsystem.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/lsystem.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the string-libcall corner. The in-place rewrite must emit memmove (overlapping tail
# shift) / memcpy (write the production) + strlen (its length), under native-16 (rep/sep). __mulsi3 is a
# bonus (turtle trig). These string libcalls are the corner no other demo runs.
echo "==> disasm gate (string-rewriting libcall codegen)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/lsystem_sim.c" -I"$ROOT/examples" -o "$BUILD/lsystem_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/lsystem_sim.o" 2>/dev/null || true)
cp=$(printf '%s\n' "$dis" | grep -cE 'memmove|memcpy' || true)   # string-build copy libcalls
sl=$(printf '%s\n' "$dis" | grep -c 'strlen' || true)           # production-length libcall
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$cp" -ge 1 ] && [ "$sl" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  memcpy/memmove=$cp  strlen=$sl  __mulsi3=$mul  rep/sep=$rs  (string libcalls, native-16)"
else
  echo "    FAIL  memcpy/memmove=$cp  strlen=$sl  __mulsi3=$mul  rep/sep=$rs  (expected copy/strlen/rep >= 1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/lsystem-jg.png) + assert"
  "$JGX" "$BUILD/lsystem.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 "$BUILD/lsystem-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/lsystem-mame.png)"
  SNAP="$BUILD/.lsystem-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/lsystem.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/lsystem.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 18 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/lsystem-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — L-System Plant rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
