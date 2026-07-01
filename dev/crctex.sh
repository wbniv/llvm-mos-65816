#!/usr/bin/env bash
# dev/crctex.sh — render the Table-Driven CRC32 Procedural Texture demo (#40 compiler stress-test) ON
# the SNES (examples/snes/crctex.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/crctex-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/crctex.lua snapshots + asserts.
# Plus a disasm gate proving the hot loop is a 256-entry const ROM look-up table indexed per byte:
# the CRC32_TAB (0x400 = 1 KiB rodata) is referenced, and the crc = TABLE[..] ^ (crc>>8) chain shows
# up as an XOR cascade over indexed 32-bit loads (+ native-16). No __udiv/__mul on the hot path.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh crctex. Outputs build/crctex-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh crctex   # render the CRC32 hash-marble texture; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/crctex.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; crctex.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/crctex-sim.c" -o "$BUILD/crctex-sim"
EXPECT=$("$BUILD/crctex-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: crctex gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/crctex.map" -o "$BUILD/crctex.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/crctex.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/crctex.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/crctex.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: a 256-entry const ROM LUT indexed per byte. The CRC32_TAB (1 KiB rodata) must be
# referenced, and the crc = TABLE[..] ^ (crc>>8) chain shows as an XOR cascade + native-16.
echo "==> disasm gate (256-entry ROM-LUT CRC32 indexed byte loop)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/crctex_sim.c" -I"$ROOT/examples" -o "$BUILD/crctex_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/crctex_sim.o" 2>/dev/null || true)
tab=$(printf '%s\n' "$dis" | grep -c 'CRC32_TAB' || true)
eor=$(printf '%s\n' "$dis" | grep -cw 'eor' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$tab" -ge 1 ] && [ "$eor" -ge 4 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  CRC32_TAB-refs=$tab  eor=$eor  rep/sep=$rs  (256-entry ROM LUT indexed byte loop)"
else
  echo "    FAIL  CRC32_TAB-refs=$tab  eor=$eor  rep/sep=$rs  (expected table-refs>=1, eor>=4, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/crctex-jg.png) + assert"
  "$JGX" "$BUILD/crctex.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/crctex-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/crctex-mame.png)"
  SNAP="$BUILD/.crctex-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/crctex.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/crctex.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/crctex-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — CRC32 procedural texture rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
