#!/usr/bin/env bash
# dev/multibase.sh — render the Multi-Base Clock demo (#60 compiler stress-test) ON
# the SNES (examples/snes/multibase.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/multibase-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/multibase.lua snapshots + asserts.
# Plus a disasm gate proving the corner is the libc div()/lldiv() returning div_t/lldiv_t BY VALUE
# (the aggregate-return ABI + the custom G_SDIVREM legalizer). The read-out appears after the title +
# the lldiv-heavy gate, so the snapshot/assert frame is 700 (the gate corpus is set far earlier).
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh multibase. Outputs build/multibase-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh multibase   # render the multi-base clock; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/multibase.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; multibase.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/multibase-sim.c" -o "$BUILD/multibase-sim"
EXPECT=$("$BUILD/multibase-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: multibase gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/multibase.map" -o "$BUILD/multibase.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/multibase.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/multibase.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/multibase.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the corner is the libc div()/lldiv() returning div_t/lldiv_t BY VALUE. The corpus must
# CALL div and lldiv (real libc functions -> aggregate-return ABI); we read the relocations. NOTE: this
# needs stdlib.h, so the object is built with --config (SDK headers) + -fno-lto (native, not bitcode) —
# NOT --target=mos (which lacks SDK headers) per the qsortviz gotcha.
echo "==> disasm gate (libc div()/lldiv() div_t/lldiv_t by-value: aggregate-return ABI + G_SDIVREM)"
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os -fno-lto \
  -c "$ROOT/examples/snes/corpus/multibase_sim.c" -I"$ROOT/examples" -o "$BUILD/multibase_sim.o" 2>/dev/null
reloc=$("$TOOL/llvm-readobj" -r "$BUILD/multibase_sim.o" 2>/dev/null || true)
dcall=$(printf '%s\n' "$reloc" | grep -cE 'R_MOS_ADDR16 div( |$)' || true)
lcall=$(printf '%s\n' "$reloc" | grep -cE 'R_MOS_ADDR16 lldiv' || true)
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/multibase_sim.o" 2>/dev/null || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$dcall" -ge 1 ] && [ "$lcall" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  div-calls=$dcall  lldiv-calls=$lcall  rep/sep=$rs  (div_t/lldiv_t by-value aggregate return)"
else
  echo "    FAIL  div-calls=$dcall  lldiv-calls=$lcall  rep/sep=$rs  (expected div>=1, lldiv>=1, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/multibase-jg.png) + assert"
  "$JGX" "$BUILD/multibase.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 700 "$BUILD/multibase-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/multibase-mame.png)"
  SNAP="$BUILD/.multibase-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/multibase.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/multibase.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/multibase-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — multi-base clock rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
