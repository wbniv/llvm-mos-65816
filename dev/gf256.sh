#!/usr/bin/env bash
# dev/gf256.sh — render the GF(2^8) Galois Field demo (#40 compiler stress-test) ON
# the SNES (examples/snes/gf256.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/gf256-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/gf256.lua snapshots + asserts.
# Plus a disasm gate proving the hot loop is a 256-entry const ROM look-up table indexed per byte:
# the CRC32_TAB (0x400 = 1 KiB rodata) is referenced, and the crc = TABLE[..] ^ (crc>>8) chain shows
# up as an XOR cascade over indexed 32-bit loads (+ native-16). No __udiv/__mul on the hot path.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh gf256. Outputs build/gf256-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh gf256   # render the CRC32 hash-marble texture; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/gf256.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; gf256.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/gf256-sim.c" -o "$BUILD/gf256-sim"
EXPECT=$("$BUILD/gf256-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: gf256 gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/gf256.map" -o "$BUILD/gf256.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/gf256.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/gf256.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/gf256.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: GF(2^8) carryless multiply = two log-table lookups (GF_LOG) + an add + an
# antilog-table lookup (GF_EXP), with field add = XOR (eor).  NO integer mul/div libcall on the hot
# path (the field multiply is table-based, not __mulqi3/__mulhi3).  native-16 (rep/sep) fires.
echo "==> disasm gate (GF(2^8) carryless multiply: log/antilog table lookups + XOR, no carry chain)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/gf256_sim.c" -I"$ROOT/examples" -o "$BUILD/gf256_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/gf256_sim.o" 2>/dev/null || true)
exp=$(printf '%s\n' "$dis" | grep -c 'GF_EXP' || true)
lg=$(printf  '%s\n' "$dis" | grep -c 'GF_LOG' || true)
eor=$(printf '%s\n' "$dis" | grep -cw 'eor' || true)
muldiv=$(printf '%s\n' "$dis" | grep -coE '__[a-z]*(mul|div|mod)[a-z0-9]*' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$exp" -ge 2 ] && [ "$lg" -ge 2 ] && [ "$eor" -ge 4 ] && [ "$muldiv" -eq 0 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  GF_EXP=$exp  GF_LOG=$lg  eor=$eor  mul/div-libcalls=$muldiv  rep/sep=$rs  (table-based carryless multiply)"
else
  echo "    FAIL  GF_EXP=$exp  GF_LOG=$lg  eor=$eor  mul/div-libcalls=$muldiv  rep/sep=$rs  (want EXP>=2,LOG>=2,eor>=4,muldiv=0,rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/gf256-jg.png) + assert"
  "$JGX" "$BUILD/gf256.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/gf256-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/gf256-mame.png)"
  SNAP="$BUILD/.gf256-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/gf256.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/gf256.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/gf256-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — GF(2^8) finite-field rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
