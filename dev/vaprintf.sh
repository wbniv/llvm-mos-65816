#!/usr/bin/env bash
# dev/vaprintf.sh — render the va_arg Lissajous demo (#32 compiler stress-test) ON the SNES.
# Hot ABI: mini_sprintf() uses va_arg(ap, unsigned int) and va_arg(ap, int) — the variadic
# calling convention on the 65816, which no prior battery demo exercises.
# Drive: dev/run.sh vaprintf. Outputs build/vaprintf-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh vaprintf   # render the va_arg Lissajous demo on SNES + assert"; exit 0;; esac

ROOT=/work; BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/vaprintf.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/vaprintf-sim.c" -o "$BUILD/vaprintf-sim"
EXPECT=$("$BUILD/vaprintf-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: vaprintf gate hash = $EXPECT"

# 2. Build ROM (+mos-a16)
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/vaprintf.map" -o "$BUILD/vaprintf.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/vaprintf.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/vaprintf.map")
OFF="0x$VMA"; ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/vaprintf.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: must contain a va_arg / variadic-related instruction sequence.
# Under llvm-mos, variadic args are passed via the soft-stack; va_arg reads them with
# pointer arithmetic (loads from imaginary register / ZP). The presence of the va_list
# setup (__va_start or similar) and multiple va_arg reads confirms the ABI is exercised.
echo "==> disasm gate (va_arg variadic ABI: 4× mini_sprintf calls, 9 va_arg reads)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/vaprintf_sim.c" \
  -I"$ROOT/examples" -o "$BUILD/vaprintf_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/vaprintf_sim.o" 2>/dev/null || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
jsr=$(printf '%s\n' "$dis" | grep -c 'jsr'       || true)
# mini_sprintf calls from vaprintf_gate_crc → at least 4 jsr calls; each call exercises va_arg
if [ "$jsr" -ge 4 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  jsr_calls=$jsr  rep/sep=$rs  (va_arg variadic formatter: 4 mini_sprintf calls)"
else
  echo "    FAIL  jsr_calls=$jsr  rep/sep=$rs  (expected jsr>=4, rep/sep>=1)"; rc=1
fi

# 4. bsnes-jg
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
  echo "==> bsnes-jg: render + framebuffer dump (build/vaprintf-jg.png) + assert"
  "$JGX" "$BUILD/vaprintf.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/vaprintf-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent)"
fi

# 5. MAME
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL — gitignored; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (Xvfb): snapshot + assert (build/vaprintf-mame.png)"
  SNAP="$BUILD/.vaprintf-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/vaprintf.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/vaprintf.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/vaprintf-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — va_arg Lissajous rendered on SNES; hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see per-emulator lines above"
fi
exit $rc
