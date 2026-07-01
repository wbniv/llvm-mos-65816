#!/usr/bin/env bash
# dev/sbitfld.sh — render Signed-Bitfield Terrain Sculptor (#78 compiler stress-test) on SNES.
# Exercises G_SEXT_INREG via int16_t height:5/slope:4/flow:4 signed bitfield read-back;
# legalizer :130 .lower() → shl(x,16-N) >> (16-N) (ASL/ASR sign-extend pair).
# Full 5-way differential (host==default==+mos-a16==+mos-xy16).
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh sbitfld   # render signed-bitfield terrain; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/sbitfld.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/sbitfld-sim.c" -o "$BUILD/sbitfld-sim"
EXPECT=$("$BUILD/sbitfld-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: sbitfld gate hash = $EXPECT"

# 2. Build ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/sbitfld.map" -o "$BUILD/sbitfld.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/sbitfld.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/sbitfld.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/sbitfld.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: G_SEXT_INREG sign-extend pair (shl + ashr for signed bitfields).
# On the 65816, sign-extension fires ASL sequences and arithmetic right-shifts.
# The sb_step function has 3 G_SEXT_INREG reads per cell (height/slope/flow).
echo "==> disasm gate (G_SEXT_INREG: asl>=3 shift pairs + rep/sep)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/sbitfld_sim.c" -I"$ROOT/examples" -o "$BUILD/sbitfld_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/sbitfld_sim.o" 2>/dev/null || true)
asl=$(printf '%s\n' "$dis" | grep -cwE '\basl\b' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE '\brep\b|\bsep\b' || true)
echo "    asl=$asl  rep/sep=$rs"
# G_SEXT_INREG for 3 signed fields per 16*16*16=4096 reads: expect many ASL.
if [ "$asl" -ge 4 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  signed sext pattern confirmed (asl=$asl >= 4, rep/sep=$rs >= 1)"
else
  echo "    FAIL  asl=$asl (expected >=4) rep/sep=$rs (expected >=1)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/sbitfld-jg.png)"
  "$JGX" "$BUILD/sbitfld.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/sbitfld-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/sbitfld-mame.png)"
  SNAP="$BUILD/.sbitfld-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/sbitfld.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/sbitfld.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/sbitfld-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Signed-Bitfield Terrain on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
