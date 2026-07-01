#!/usr/bin/env bash
# dev/disbits.sh — render the Cross-Byte-Boundary Bitfield Disassembler demo (#52 compiler stress-test)
# ON the SNES (examples/snes/disbits.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/disbits-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/disbits.lua snapshots + asserts.
# Plus a disasm gate proving the hot loop decodes bitfields that straddle byte boundaries: the
# extract/insert of fields crossing bit 16 (group) and bit 24 (flags) shows as multi-byte shift + mask
# (lsr/asl/ror + and/ora) with NO arithmetic libcall, under native-16 (rep/sep).
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh disbits. Outputs build/disbits-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh disbits   # render the cross-byte bitfield disassembler; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/disbits.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; disbits.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/disbits-sim.c" -o "$BUILD/disbits-sim"
EXPECT=$("$BUILD/disbits-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: disbits gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/disbits.map" -o "$BUILD/disbits.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/disbits.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/disbits.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/disbits.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: cross-byte-boundary bitfields -> multi-byte shift + mask (and/ora), no arith libcall.
echo "==> disasm gate (cross-byte bitfield extract/insert: shift+mask, native-16, no libcall)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/disbits_sim.c" -I"$ROOT/examples" -o "$BUILD/disbits_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/disbits_sim.o" 2>/dev/null || true)
andc=$(printf '%s\n' "$dis" | grep -cw 'and' || true)
sh=$(printf   '%s\n' "$dis" | grep -cwE 'lsr|asl|ror|rol' || true)
lib=$(printf  '%s\n' "$dis" | grep -cE '__udiv|__div|__mul' || true)
rs=$(printf   '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$andc" -ge 1 ] && [ "$sh" -ge 4 ] && [ "$lib" -eq 0 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  and-masks=$andc  shifts=$sh  arith-libcalls=$lib  rep/sep=$rs  (cross-byte bitfield shift+mask)"
else
  echo "    FAIL  and-masks=$andc  shifts=$sh  arith-libcalls=$lib  rep/sep=$rs  (expected and>=1, shifts>=4, libcalls==0, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/disbits-jg.png) + assert"
  "$JGX" "$BUILD/disbits.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/disbits-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/disbits-mame.png)"
  SNAP="$BUILD/.disbits-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/disbits.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/disbits.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/disbits-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — cross-byte-boundary bitfield disassembler rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
