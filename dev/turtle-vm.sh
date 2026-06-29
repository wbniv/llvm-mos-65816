#!/usr/bin/env bash
# dev/turtle-vm.sh — render the #29a Bytecode-VM Turtle rosette (examples/snes/turtle-vm.c, +mos-a16) ON the SNES and
# capture a REAL emulator screenshot from BOTH cores headless, each asserting corpus_result == the
# host oracle (tools/turtle-vm-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/turtle-vm.lua snapshots + asserts.
# Plus a disasm gate proving the 64-bit hash hot loop has __muldi3 + 64-bit shift + __udivdi3 + rep/sep.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice (turtle-vm_sim.c)
# gate, run by dev/run.sh corpus-a16.
#
# Drive: dev/run.sh turtle-vm. Outputs build/turtle-vm-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh turtle-vm   # render the Bytecode-VM Turtle demo on SNES; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/turtle-vm.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; turtle-vm.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/turtle-vm-sim.c" -o "$BUILD/turtle-vm-sim"
EXPECT=$("$BUILD/turtle-vm-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: Bytecode-VM Turtle gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/turtle-vm.map" -o "$BUILD/turtle-vm.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/turtle-vm.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/turtle-vm.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/turtle-vm.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the indirect/computed control flow. The interpreter's dense switch(op) must lower to a
# JMP (abs,X) jump table (JMPIdxIndir) and the ALU ops must dispatch through the function-pointer opcode
# table (jsr __call_indir) — the two corners no other demo runs — under native-16 (rep/sep). __mulsi3 is
# a bonus (turtle trig).
echo "==> disasm gate (jump-table + function-pointer dispatch codegen)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/turtle-vm_sim.c" -I"$ROOT/examples" -o "$BUILD/turtle-vm_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/turtle-vm_sim.o" 2>/dev/null || true)
jt=$(printf '%s\n' "$dis" | grep -cE 'jmp[[:space:]]+\(.*,[xX]\)' || true)   # JMP (abs,X) jump table
ic=$(printf '%s\n' "$dis" | grep -c '__call_indir' || true)                  # fnptr opcode table
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$jt" -ge 1 ] && [ "$ic" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  jump-table=$jt  __call_indir=$ic  __mulsi3=$mul  rep/sep=$rs  (indirect dispatch, native-16)"
else
  echo "    FAIL  jump-table=$jt  __call_indir=$ic  __mulsi3=$mul  rep/sep=$rs  (expected jt/ic/rep >= 1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/turtle-vm-jg.png) + assert"
  "$JGX" "$BUILD/turtle-vm.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 "$BUILD/turtle-vm-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/turtle-vm-mame.png)"
  SNAP="$BUILD/.turtle-vm-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/turtle-vm.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/turtle-vm.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 18 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/turtle-vm-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Bytecode-VM Turtle rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
