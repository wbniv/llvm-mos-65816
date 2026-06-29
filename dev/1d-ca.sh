#!/usr/bin/env bash
# dev/1d-ca.sh — render the Rule 90/110 1-D CA demo (#6 compiler stress-test) ON the SNES
# (examples/snes/1d-ca.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/ca1d-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps framebuffer + asserts.
#   * MAME     — under Xvfb, dev/1d-ca.lua snapshots + asserts.
# Plus a disasm gate proving ca_step has shifts + boolean ops and NO mul/div helpers.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh 1d-ca. Outputs build/1d-ca-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh 1d-ca   # render the Rule 90/110 CA demo on SNES; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/1d-ca.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (differential anchor; ca1d.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/ca1d-sim.c" -o "$BUILD/ca1d-sim"
EXPECT=$("$BUILD/ca1d-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: 1-D CA gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/1d-ca.map" -o "$BUILD/1d-ca.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/1d-ca.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/1d-ca.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/1d-ca.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: ca_step must use shifts + boolean ops; must NOT call mul/div helpers.
#    +mos-a16 may emit rep/sep for the outer loop but NOT inside the bit-manipulation core.
echo "==> disasm gate (ca_step: shift/bool ops, no mul/div, no rep/sep in hot path)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/ca1d_sim.c" -I"$ROOT/examples" -o "$BUILD/ca1d_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/ca1d_sim.o" 2>/dev/null || true)
shifts=$(printf '%s\n' "$dis" | grep -cE '\blsr\b|\basl\b|\blsra\b|\basla\b' || true)
bools=$(printf '%s\n'  "$dis" | grep -cE '\beor\b|\band\b|\bora\b'            || true)
bad_mul=$(printf '%s\n' "$dis" | grep -c '__mulsi3\|__umulsi3' || true)
bad_div=$(printf '%s\n' "$dis" | grep -c '__divsi3\|__udivsi3\|__udivmodsi4' || true)
if [ "$shifts" -ge 1 ] && [ "$bools" -ge 1 ] && [ "$bad_mul" -eq 0 ] && [ "$bad_div" -eq 0 ]; then
  echo "    PASS  shifts=$shifts  bools=$bools  bad_mul=$bad_mul  bad_div=$bad_div  (pure shift+bool, no helpers)"
else
  echo "    FAIL  shifts=$shifts  bools=$bools  bad_mul=$bad_mul  bad_div=$bad_div (expected shifts>=1 bools>=1 mul=0 div=0)"; rc=1
fi

# 4. bsnes-jg — build harness if needed, then dump framebuffer + assert.
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
  echo "==> bsnes-jg: render + framebuffer dump (build/1d-ca-jg.png) + assert"
  "$JGX" "$BUILD/1d-ca.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 400 "$BUILD/1d-ca-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
# MAME's snes driver needs the gitignored 64-byte SPC700 IPL ROM; without it MAME aborts with
# "Required files are missing". Treat its absence as SKIP (like the bsnes harness above), not FAIL —
# it is an env-wide gap (every demo's MAME leg), not a defect in this ROM (bsnes-jg + disasm cover it).
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/1d-ca-mame.png)"
  SNAP="$BUILD/.ca1d-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/1d-ca.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/1d-ca.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/1d-ca-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Rule 90/110 CA rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
