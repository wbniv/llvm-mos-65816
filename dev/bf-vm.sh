#!/usr/bin/env bash
# dev/bf-vm.sh — render the Brainfuck Threaded-Code VM demo (#38 compiler stress-test) ON the
# SNES (examples/snes/bf-vm.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/bf-vm-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/bf-vm.lua snapshots + asserts.
# Plus a disasm gate proving the interpreter dispatch is a COMPUTED GOTO — an indirect jump
# (`jmp ($ind,x)`/`jmp ($ind)`), the labels-as-values threaded-code path. Control-flow only:
# there is deliberately no __mul/__udiv probe here.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh bf-vm. Outputs build/bf-vm-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh bf-vm   # render the Brainfuck threaded-code VM demo; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/bf-vm.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; bf_vm.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/bf-vm-sim.c" -o "$BUILD/bf-vm-sim"
EXPECT=$("$BUILD/bf-vm-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: Brainfuck VM gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/bf-vm.map" -o "$BUILD/bf-vm.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/bf-vm.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/bf-vm.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/bf-vm.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the interpreter loop must dispatch via a computed goto — an indirect jump
# (opcode $7C `jmp ($ind,x)` or $6C `jmp ($ind)`), NOT a switch/branch chain. Plus native-16.
echo "==> disasm gate (computed-goto threaded dispatch codegen)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/bf_vm_sim.c" -I"$ROOT/examples" -o "$BUILD/bf_vm_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/bf_vm_sim.o" 2>/dev/null || true)
ind=$(printf '%s\n' "$dis" | grep -cE 'jmp[[:space:]]+\('  || true)
rs=$(printf '%s\n'  "$dis" | grep -cwE 'rep|sep' || true)
if [ "$ind" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  indirect-jmp=$ind  rep/sep=$rs  (labels-as-values threaded dispatch, native-16)"
else
  echo "    FAIL  indirect-jmp=$ind  rep/sep=$rs (expected all >= 1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/bf-vm-jg.png) + assert"
  "$JGX" "$BUILD/bf-vm.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 400 "$BUILD/bf-vm-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/bf-vm-mame.png)"
  SNAP="$BUILD/.bf-vm-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/bf-vm.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/bf-vm.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/bf-vm-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Brainfuck threaded-code VM rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
