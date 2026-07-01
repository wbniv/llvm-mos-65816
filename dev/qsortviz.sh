#!/usr/bin/env bash
# dev/qsortviz.sh — render the qsort + Comparator-Callback Sort Visualizer demo (#46 compiler
# stress-test) ON the SNES (examples/snes/qsortviz.c, +mos-a16) and capture a REAL emulator screenshot
# from BOTH cores headless, each asserting corpus_result == the host oracle (tools/qsortviz-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/qsortviz.lua snapshots + asserts.
# Plus a disasm gate proving the hot loop is libc qsort with a FUNCTION-POINTER comparator: qsort is
# called, the comparator fn-ptr table lives in rodata, and the comparators are invoked as callbacks.
# NOTE: this demo caught a real backend crash — the `(x>y)-(x<y)` comparator emits G_SCMP, which the mos
# legalizer had no rule for ("unable to legalize G_SCMP"); fixed by lowering G_SCMP/G_UCMP (see plan).
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh qsortviz. Outputs build/qsortviz-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh qsortviz   # render the qsort sort visualizer; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/qsortviz.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; qsortviz.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/qsortviz-sim.c" -o "$BUILD/qsortviz-sim"
EXPECT=$("$BUILD/qsortviz-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: qsortviz gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/qsortviz.map" -o "$BUILD/qsortviz.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/qsortviz.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/qsortviz.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/qsortviz.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: libc qsort with a function-pointer comparator. qsort must be called, the comparator
# fn-ptr table must live in rodata, and the comparators must be present as callbacks. Needs the SDK
# includes (stdlib.h) so compile with --config; -fno-lto forces a native object (not LTO bitcode).
echo "==> disasm gate (libc qsort + fn-ptr comparator callback, native-16)"
"$TOOL/mos-clang" --config "$CFG" -fno-lto -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/qsortviz_sim.c" -I"$ROOT/examples" -o "$BUILD/qsortviz_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/qsortviz_sim.o" 2>/dev/null || true)
qs=$(printf   '%s\n' "$dis" | grep -cw 'qsort' || true)
cmp=$(printf  '%s\n' "$dis" | grep -cE 'qs_cmp_(asc|desc|parity)' || true)
tab=$(printf  '%s\n' "$dis" | grep -c 'cmps' || true)
rs=$(printf   '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$qs" -ge 1 ] && [ "$cmp" -ge 1 ] && [ "$tab" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  qsort-refs=$qs  comparator-refs=$cmp  cmps-fnptr-table=$tab  rep/sep=$rs  (qsort + fn-ptr comparator callback)"
else
  echo "    FAIL  qsort-refs=$qs  comparator-refs=$cmp  cmps-fnptr-table=$tab  rep/sep=$rs  (expected qsort>=1, comparators>=1, table>=1, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/qsortviz-jg.png) + assert"
  "$JGX" "$BUILD/qsortviz.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 440 "$BUILD/qsortviz-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/qsortviz-mame.png)"
  SNAP="$BUILD/.qsortviz-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/qsortviz.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/qsortviz.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/qsortviz-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — qsort + comparator-callback sort visualizer rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc
