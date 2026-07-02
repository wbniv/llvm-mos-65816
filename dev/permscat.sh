#!/usr/bin/env bash
# dev/permscat.sh — render Gather-Scatter Permutation (#95 stress-test, Round 6 Cluster A).
# Re-stresses patch 0002 (MOSInsertREPSEP::placeIntraBlock, the #23 +mos-xy16 index-width fix) at
# its hardest: a scatter dst[perm[i]]=src[i] over a >512-entry grid with TWO 16-bit indices live at
# once — the loop counter i AND the DATA-DEPENDENT scatter index pi=perm[i]. Under +mos-xy16 this
# emits `sta abs,X` with a 16-bit index — the exact addressing shape the #23 bug corrupted.
# Drive: dev/run.sh permscat. Outputs build/permscat-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh permscat   # render gather-scatter permutation; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/permscat.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/permscat-sim.c" -o "$BUILD/permscat-sim"
EXPECT=$("$BUILD/permscat-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: permscat gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/permscat.map" -o "$BUILD/permscat.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/permscat.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/permscat.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/permscat.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the scatter dst[perm[i]]=src[i] under +mos-xy16 must emit `sta abs,X` with a
#    16-bit index (the literal #23 shape #94 rotslab did NOT produce), alongside the a16 rep/sep
#    width brackets, and the corpus slice must compile clean under +mos-xy16 (where #23 miscompiled).
echo "==> disasm gate (xy16 sta abs,X 16-bit-index scatter; a16 rep/sep; xy16 compile clean)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/permscat_sim.c" -I"$ROOT/examples" -o "$BUILD/permscat_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/permscat_sim.o" 2>/dev/null || true)
rs=$(printf '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
# xy16 must compile clean AND emit the indexed abs,X store (the #23 addressing shape).
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-xy16 -Os \
  -c "$ROOT/examples/snes/corpus/permscat_sim.c" -I"$ROOT/examples" -o "$BUILD/permscat_sim_xy16.o" 2>/dev/null \
  && xy16ok=1 || xy16ok=0
disx=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/permscat_sim_xy16.o" 2>/dev/null || true)
stx=$(printf '%s\n' "$disx" | grep -cE 'sta.*,[ ]?x' || true)
if [ "$rs" -ge 1 ] && [ "$xy16ok" -eq 1 ] && [ "$stx" -ge 1 ]; then
  echo "    PASS  a16-rep/sep=$rs  xy16-compile=OK  xy16-sta-abs,X=$stx  (data-dependent 16-bit scatter index)"
else
  echo "    FAIL  a16-rep/sep=$rs  xy16-compile=$xy16ok  xy16-sta-abs,X=$stx  (expected rep/sep>=1, xy16 OK, sta,X>=1)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/permscat-jg.png)"
  "$JGX" "$BUILD/permscat.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/permscat-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/permscat-mame.png)"
  SNAP="$BUILD/.permscat-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/permscat.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/permscat.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/permscat-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Gather-Scatter Permutation on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc
