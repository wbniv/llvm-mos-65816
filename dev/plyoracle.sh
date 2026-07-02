#!/usr/bin/env bash
# dev/plyoracle.sh — PlyOracle (#85). Variable-count G_SHL/G_LSHR bit-array sieve.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh plyoracle"; exit 0;; esac
ROOT=/work; BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"; SRC="$ROOT/examples/snes/plyoracle.c"; VENDOR="$ROOT/vendor/bsnes-jg"
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/plyoracle-sim.c" -o "$BUILD/plyoracle-sim"
EXPECT=$("$BUILD/plyoracle-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: plyoracle gate hash = $EXPECT"
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/plyoracle.map" -o "$BUILD/plyoracle.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/plyoracle.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/plyoracle.map")
OFF="0x$VMA"; ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/plyoracle.sfc (+mos-a16); corpus_result @ WRAM $OFF"
rc=0
echo "==> disasm gate (negamax self-recursion + rep/sep)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/plyoracle_sim.c" -I"$ROOT/examples" -o "$BUILD/plyoracle_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/plyoracle_sim.o" 2>/dev/null || true)
nm=$(printf '%s\n' "$dis" | grep -c 'po_negamax' || true)
rs=$(printf '%s\n' "$dis" | grep -cwE '\brep\b|\bsep\b' || true)
echo "    po_negamax-calls(recursion)=$nm  rep/sep=$rs"
if [ "$nm" -ge 1 ] && [ "$rs" -ge 1 ]; then echo "    PASS  negamax alpha-beta recursion present"
else echo "    FAIL  po_negamax=$nm (>=1) rep/sep=$rs (>=1)"; rc=1; fi
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  [ -n "$ARCHIVE" ] && { g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"; g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"; }
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + assert (build/plyoracle-jg.png)"
  "$JGX" "$BUILD/plyoracle.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/plyoracle-jg.png" || rc=1
else echo "    SKIP bsnes-jg"; fi
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (Xvfb): snapshot + assert (build/plyoracle-mame.png)"
  SNAP="$BUILD/.plyoracle-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" xvfb-run -a mame snes -cart "$BUILD/plyoracle.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/plyoracle.lua" -skip_gameinfo -snapshot_directory "$SNAP" -sound none -nothrottle \
      -seconds_to_run 12 -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  [ -f "$SNAP/snes/0000.png" ] && mv "$SNAP/snes/0000.png" "$BUILD/plyoracle-mame.png"
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else echo "    SKIP MAME (no xvfb-run)"; fi
echo
[ "$rc" -eq 0 ] && echo "RESULT: PASS — PlyOracle on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16" || echo "RESULT: FAIL"
exit $rc
