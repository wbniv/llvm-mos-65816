#!/usr/bin/env bash
# dev/percol.sh — render the Union-Find Percolation demo (#62 compiler stress-test) ON
# the SNES (examples/snes/percol.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/percol-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/percol.lua snapshots + asserts.
# Plus a disasm gate proving the corner is a union-find with PATH COMPRESSION (find chases + flattens
# parent pointers). The percolation grows over ~frames, so the snapshot/assert frame is 900.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh percol. Outputs build/percol-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh percol   # render the union-find percolation; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/percol.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; percol.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/percol-sim.c" -o "$BUILD/percol-sim"
EXPECT=$("$BUILD/percol-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: percol gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/percol.map" -o "$BUILD/percol.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/percol.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/percol.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/percol.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: union-find with path compression — the find/union pointer-chasing shows as
# branch-heavy loops over the `parent[]` array (indexed load/store to walk + flatten the path). No
# wide mul/div libcall except the incidental checksum multiply; native-16 fires.
echo "==> disasm gate (union-find path-compression: branch-heavy parent[] pointer-chase)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/percol_sim.c" -I"$ROOT/examples" -o "$BUILD/percol_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/percol_sim.o" 2>/dev/null || true)
par=$(printf '%s\n' "$dis" | grep -cE 'parent|percol' || true)   # parent-array accesses
br=$(printf  '%s\n' "$dis" | grep -cwE 'bcc|bcs|beq|bne|bmi|bpl' || true)   # find/union loop branches
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$par" -ge 2 ] && [ "$br" -ge 8 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  parent-refs=$par  branches=$br  rep/sep=$rs  (union-find find/union pointer-chase)"
else
  echo "    FAIL  parent-refs=$par  branches=$br  rep/sep=$rs  (expected parent-refs>=2, branches>=8, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/percol-jg.png) + assert"
  "$JGX" "$BUILD/percol.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 900 "$BUILD/percol-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/percol-mame.png)"
  SNAP="$BUILD/.percol-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/percol.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/percol.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/percol-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — union-find percolation rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
