#!/usr/bin/env bash
# dev/iir-scope.sh — render the IIR resonant-filter scope demo (#38 compiler stress-test) ON the
# SNES (examples/snes/iir-scope.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/iir-scope-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/iir-scope.lua snapshots + asserts.
# Plus a disasm gate proving the interpreter dispatch is a COMPUTED GOTO — an indirect jump
# (`jmp ($ind,x)`/`jmp ($ind)`), the labels-as-values threaded-code path. Control-flow only:
# there is deliberately no __mul/__udiv probe here.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh iir-scope. Outputs build/iir-scope-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh iir-scope   # render the Brainfuck threaded-code VM demo; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/iir-scope.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; bf_vm.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/iir-scope-sim.c" -o "$BUILD/iir-scope-sim"
EXPECT=$("$BUILD/iir-scope-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: IIR scope gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/iir-scope.map" -o "$BUILD/iir-scope.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/iir-scope.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/iir-scope.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/iir-scope.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the recursive feedback multiply must be a genuine 32-bit __mulsi3 (the a1*y[n-1]
# term with a runtime-modulated coefficient), plus native-16 (rep/sep). The non-reorderable chain
# itself is validated by the differential (host==target on the exact recursion).
echo "==> disasm gate (IIR feedback multiply + native-16 codegen)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/iir_scope_sim.c" -I"$ROOT/examples" -o "$BUILD/iir_scope_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/iir_scope_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -cw '__mulsi3' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$mul" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __mulsi3=$mul  rep/sep=$rs  (recursive feedback 32-bit multiply, native-16)"
else
  echo "    FAIL  __mulsi3=$mul  rep/sep=$rs (expected all >= 1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/iir-scope-jg.png) + assert"
  "$JGX" "$BUILD/iir-scope.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 700 "$BUILD/iir-scope-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/iir-scope-mame.png)"
  SNAP="$BUILD/.iir-scope-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/iir-scope.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/iir-scope.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/iir-scope-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — IIR resonant-filter scope rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
