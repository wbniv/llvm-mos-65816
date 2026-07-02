#!/usr/bin/env bash
# dev/cpu6502.sh — 6502/65C02 CPU Disassembler + Simulator (#102, Round 6 Cluster C).
# Simulates the 6502 "hello.c" assembly equivalent: sets color register to green
# (SNES_RGB(0,31,0)=0x03E0), stores sentinel 0x42, loops exercising all 8 ALU gate types.
# Display: Waldo 16×16 disasm listing (top) + schematic gate symbols (bottom).
# Codegen: 256-entry switch dispatch, uint16_t PC arithmetic, uint8_t flag bit-ops.
# Drive: dev/run.sh cpu6502. Outputs build/cpu6502-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh cpu6502   # build + gate + screenshot"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/cpu6502.c"
VENDOR="$ROOT/vendor/bsnes-jg"
EXPECT=0xAC8A   # cpu6502_gate_crc() — host-computed

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ]            || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle — confirm EXPECT matches.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/cpu6502-sim.c" -o "$BUILD/cpu6502-sim"
ACTUAL=$("$BUILD/cpu6502-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: cpu6502 gate_crc = $ACTUAL"
if [ "$ACTUAL" != "$EXPECT" ]; then
  echo "    FATAL: host CRC $ACTUAL != embedded EXPECT $EXPECT — update EXPECT in this script"; exit 1
fi

# 2. Build ROM (+mos-a16 — the codegen-stress variant).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/cpu6502.map" -o "$BUILD/cpu6502.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/cpu6502.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/cpu6502.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/cpu6502.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Codegen probe: assert 256-entry opcode switch compiled to a jump table.
#    On MOS 65816, a jump table appears as 'jmp (xxxx,x)' — the indexed indirect jump.
echo "==> opcode dispatch probe (expect jump table in disasm)"
"$TOOL/mos-clang" --config "$CFG" -fno-lto -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/cpu6502_sim.c" \
  -I"$ROOT/examples" -o "$BUILD/cpu6502_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/cpu6502_sim.o" 2>/dev/null || true)
jtbl=$(printf '%s\n' "$dis" | grep -cE 'jmp.*,x\)' 2>/dev/null || true)
reps=$(printf '%s\n' "$dis" | grep -cwE 'rep|sep'  2>/dev/null || true)
if [ "$jtbl" -ge 1 ] && [ "$reps" -ge 1 ]; then
  echo "    PASS  jmp_table=$jtbl  rep/sep=$reps"
else
  echo "    FAIL  jmp_table=$jtbl  rep/sep=$reps  (expected jmp_table>=1, rep/sep>=1)"; rc=1
fi

# 4. bsnes-jg.
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" \
      -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + assert (build/cpu6502-jg.png)"
  "$JGX" "$BUILD/cpu6502.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 1000 \
    "$BUILD/cpu6502-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (Xvfb): snapshot + assert (build/cpu6502-mame.png)"
  SNAP="$BUILD/.cpu6502-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" SHOT_AT=1000 \
    xvfb-run -a mame snes -cart "$BUILD/cpu6502.sfc" \
      -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/cpu6502.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 20 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/cpu6502-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — 6502/65C02 CPU Disassembler+Simulator on SNES; gate_crc=$EXPECT host==+mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc
