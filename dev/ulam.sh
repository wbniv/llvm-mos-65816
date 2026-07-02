#!/usr/bin/env bash
# dev/ulam.sh — Ulam Prime Sieve (#85). Variable-count G_SHL/G_LSHR bit-array sieve.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh ulam"; exit 0;; esac
ROOT=/work; BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"; SRC="$ROOT/examples/snes/ulam.c"; VENDOR="$ROOT/vendor/bsnes-jg"
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/ulam-sim.c" -o "$BUILD/ulam-sim"
EXPECT=$("$BUILD/ulam-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: ulam gate hash = $EXPECT"
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/ulam.map" -o "$BUILD/ulam.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/ulam.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/ulam.map")
OFF="0x$VMA"; ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/ulam.sfc (+mos-a16); corpus_result @ WRAM $OFF"
rc=0
echo "==> disasm gate (variable-count shift helpers + rep/sep)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/ulam_sim.c" -I"$ROOT/examples" -o "$BUILD/ulam_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/ulam_sim.o" 2>/dev/null || true)
sh=$(printf '%s\n' "$dis" | grep -cE '__ashlhi3|__lshrhi3|__ashlqi3|__lshrqi3|Shift|asl|lsr' || true)
rs=$(printf '%s\n' "$dis" | grep -cwE '\brep\b|\bsep\b' || true)
echo "    shift-ops=$sh  rep/sep=$rs"
if [ "$sh" -ge 1 ] && [ "$rs" -ge 1 ]; then echo "    PASS  variable-count bit-array shifts present"
else echo "    FAIL  shift-ops=$sh (>=1) rep/sep=$rs (>=1)"; rc=1; fi
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  [ -n "$ARCHIVE" ] && { g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"; g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"; }
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + assert (build/ulam-jg.png)"
  "$JGX" "$BUILD/ulam.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/ulam-jg.png" || rc=1
else echo "    SKIP bsnes-jg"; fi
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (Xvfb): snapshot + assert (build/ulam-mame.png)"
  SNAP="$BUILD/.ulam-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" xvfb-run -a mame snes -cart "$BUILD/ulam.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/ulam.lua" -skip_gameinfo -snapshot_directory "$SNAP" -sound none -nothrottle \
      -seconds_to_run 12 -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  [ -f "$SNAP/snes/0000.png" ] && mv "$SNAP/snes/0000.png" "$BUILD/ulam-mame.png"
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else echo "    SKIP MAME (no xvfb-run)"; fi
echo
[ "$rc" -eq 0 ] && echo "RESULT: PASS — Ulam Prime Sieve on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16" || echo "RESULT: FAIL"
exit $rc
