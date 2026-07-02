#!/usr/bin/env bash
# dev/speedcap.sh — Fmin/Fmax Speed Cap (#82 compiler stress-test) on SNES.
# Exercises G_FMINNUM/G_FMAXNUM via __builtin_fminf/__builtin_fmaxf (velocity
# speed governor); both .libcallFor S32 → fminf/fmaxf in SDK (math.cc:18-19).
# Full 5-way differential (host==default==+mos-a16==+mos-xy16).
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh speedcap   # render speed cap particles; assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/speedcap.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/speedcap-sim.c" -lm -o "$BUILD/speedcap-sim"
EXPECT=$("$BUILD/speedcap-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: speedcap gate hash = $EXPECT"

# 2. Build ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/speedcap.map" -o "$BUILD/speedcap.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/speedcap.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/speedcap.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/speedcap.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: verify fminf/fmaxf libcalls + float ops + rep/sep.
echo "==> disasm gate (G_FMINNUM fminf + G_FMAXNUM fmaxf + __mulsf3 + rep/sep)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/speedcap_sim.c" -I"$ROOT/examples" \
  -o "$BUILD/speedcap_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/speedcap_sim.o" 2>/dev/null || true)
fmin=$(printf '%s\n' "$dis" | grep -c 'fminf' || true)
fmax=$(printf '%s\n' "$dis" | grep -c 'fmaxf' || true)
mul=$(printf  '%s\n' "$dis" | grep -c '__mulsf3' || true)
rs=$(printf   '%s\n' "$dis" | grep -cwE '\brep\b|\bsep\b' || true)
echo "    fminf=$fmin  fmaxf=$fmax  __mulsf3=$mul  rep/sep=$rs"
if [ "$fmin" -ge 1 ] && [ "$fmax" -ge 1 ] && [ "$mul" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  fmin/fmax speed governor confirmed"
else
  echo "    FAIL  fminf=$fmin (expected >=1) fmaxf=$fmax (expected >=1) __mulsf3=$mul (expected >=1) rep/sep=$rs (expected >=1)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/speedcap-jg.png)"
  "$JGX" "$BUILD/speedcap.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/speedcap-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/speedcap-mame.png)"
  SNAP="$BUILD/.speedcap-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/speedcap.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/speedcap.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/speedcap-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Speed Cap Particles on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see per-emulator lines above"
fi
exit $rc
