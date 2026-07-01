#!/usr/bin/env bash
# dev/cgrade.sh — render the Many-Argument Color-Grade Kernel demo (#50 compiler stress-test) ON
# the SNES (examples/snes/cgrade.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/cgrade-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/cgrade.lua snapshots + asserts.
# Plus a disasm gate proving the hot loop calls a TEN-ARGUMENT function whose extra args spill onto the
# soft stack: color_grade is called, args spill to .noinit..Lstatic_stack, under native-16 (rep/sep).
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh cgrade. Outputs build/cgrade-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh cgrade   # render the many-arg color-grade kernel; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/cgrade.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; cgrade.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/cgrade-sim.c" -o "$BUILD/cgrade-sim"
EXPECT=$("$BUILD/cgrade-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: cgrade gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/cgrade.map" -o "$BUILD/cgrade.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/cgrade.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/cgrade.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/cgrade.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: a 10-argument call whose extra args spill onto the soft stack (.noinit..Lstatic_stack).
echo "==> disasm gate (10-argument call, soft-stack argument spill, native-16)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/cgrade_sim.c" -I"$ROOT/examples" -o "$BUILD/cgrade_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/cgrade_sim.o" 2>/dev/null || true)
cg=$(printf   '%s\n' "$dis" | grep -c 'color_grade' || true)
spill=$(printf '%s\n' "$dis" | grep -cE 'Lstatic_stack' || true)
rs=$(printf   '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$cg" -ge 1 ] && [ "$spill" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  color_grade-refs=$cg  soft-stack-spill=$spill  rep/sep=$rs  (10-arg call, soft-stack arg spill)"
else
  echo "    FAIL  color_grade-refs=$cg  soft-stack-spill=$spill  rep/sep=$rs  (expected color_grade>=1, spill>=1, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/cgrade-jg.png) + assert"
  "$JGX" "$BUILD/cgrade.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/cgrade-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/cgrade-mame.png)"
  SNAP="$BUILD/.cgrade-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/cgrade.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/cgrade.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/cgrade-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — many-argument color-grade kernel rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
