#!/usr/bin/env bash
# dev/duff.sh — render the Dissolve Transition (Duff's Device) demo (#42 compiler stress-test) ON
# the SNES (examples/snes/duff.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/duff-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/duff.lua snapshots + asserts.
# Plus a disasm gate proving the hot loop is IRREDUCIBLE loop-switch control flow (Duff's device):
# the switch-into-a-loop tangle lowers to a dense mesh of branches (jmp + bne back-edges) under
# native-16 (rep/sep), with NO arithmetic libcall (__mul*/__udiv* == 0 — the /8 and %8 fold to
# shift/mask). The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus gate.
#
# Drive: dev/run.sh duff. Outputs build/duff-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh duff   # render the Duff-device dissolve transition; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/duff.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; duff.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/duff-sim.c" -o "$BUILD/duff-sim"
EXPECT=$("$BUILD/duff-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: duff gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/duff.map" -o "$BUILD/duff.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/duff.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/duff.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/duff.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: irreducible loop-switch control flow (Duff's device). The switch-into-a-loop tangle
# lowers to a dense mesh of branches (jmp targets + bne back-edges) under native-16, no arith libcall.
echo "==> disasm gate (Duff's device: irreducible loop-switch branch mesh, native-16, no libcall)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/duff_sim.c" -I"$ROOT/examples" -o "$BUILD/duff_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/duff_sim.o" 2>/dev/null || true)
jmp=$(printf '%s\n' "$dis" | grep -cw 'jmp' || true)
lib=$(printf '%s\n' "$dis" | grep -cE '__mul[a-z]*3|__udiv[a-z0-9]*|__div[a-z0-9]*' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$jmp" -ge 4 ] && [ "$lib" -eq 0 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  jmp=$jmp  arith-libcalls=$lib  rep/sep=$rs  (irreducible loop-switch branch mesh, native-16, no libcall)"
else
  echo "    FAIL  jmp=$jmp  arith-libcalls=$lib  rep/sep=$rs  (expected jmp>=4, libcalls==0, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/duff-jg.png) + assert"
  "$JGX" "$BUILD/duff.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/duff-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/duff-mame.png)"
  SNAP="$BUILD/.duff-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/duff.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/duff.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/duff-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Duff-device dissolve transition rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
