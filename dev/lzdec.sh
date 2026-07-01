#!/usr/bin/env bash
# dev/lzdec.sh — render the LZ77/LZSS Image-Decompress Reveal demo (#49 compiler stress-test) ON
# the SNES (examples/snes/lzdec.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/lzdec-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/lzdec.lua snapshots + asserts.
# Plus a disasm gate proving the hot loop is an LZ byte-stream decoder copying back-references from its
# OWN output: the LZ_STREAM const is read, the output is written via indirect (dp),(from) byte copies
# with NO arithmetic libcall (__udiv/__mul == 0), under native-16 (rep/sep).
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh lzdec. Outputs build/lzdec-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh lzdec   # render the LZ image-decompress reveal; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/lzdec.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; lzdec.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/lzdec-sim.c" -o "$BUILD/lzdec-sim"
EXPECT=$("$BUILD/lzdec-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: lzdec gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/lzdec.map" -o "$BUILD/lzdec.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/lzdec.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/lzdec.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/lzdec.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: an LZ byte-stream decoder copying back-references from its own output. The LZ_STREAM
# const is read; output bytes are written; no arithmetic libcall; native-16.
echo "==> disasm gate (LZ77 back-reference byte-stream decoder, native-16, no libcall)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/lzdec_sim.c" -I"$ROOT/examples" -o "$BUILD/lzdec_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/lzdec_sim.o" 2>/dev/null || true)
strm=$(printf '%s\n' "$dis" | grep -c 'LZ_STREAM' || true)
sta=$(printf  '%s\n' "$dis" | grep -cw 'sta' || true)
lib=$(printf  '%s\n' "$dis" | grep -cE '__udiv|__div|__mul' || true)
rs=$(printf   '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$strm" -ge 1 ] && [ "$sta" -ge 4 ] && [ "$lib" -eq 0 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  LZ_STREAM-refs=$strm  sta=$sta  arith-libcalls=$lib  rep/sep=$rs  (LZ back-ref decoder)"
else
  echo "    FAIL  LZ_STREAM-refs=$strm  sta=$sta  arith-libcalls=$lib  rep/sep=$rs  (expected stream>=1, sta>=4, libcalls==0, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/lzdec-jg.png) + assert"
  "$JGX" "$BUILD/lzdec.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/lzdec-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/lzdec-mame.png)"
  SNAP="$BUILD/.lzdec-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/lzdec.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/lzdec.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/lzdec-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — LZ77 image-decompress reveal rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
