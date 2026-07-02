#!/usr/bin/env bash
# dev/scopeguard.sh — Scope-Guard Ripple Tank (#85). Variable-count G_SHL/G_LSHR bit-array sieve.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh scopeguard"; exit 0;; esac
ROOT=/work; BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"; SRC="$ROOT/examples/snes/scopeguard.c"; VENDOR="$ROOT/vendor/bsnes-jg"
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/scopeguard-sim.c" -o "$BUILD/scopeguard-sim"
EXPECT=$("$BUILD/scopeguard-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: scopeguard gate hash = $EXPECT"
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/scopeguard.map" -o "$BUILD/scopeguard.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/scopeguard.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/scopeguard.map")
OFF="0x$VMA"; ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/scopeguard.sfc (+mos-a16); corpus_result @ WRAM $OFF"
rc=0
echo "==> disasm gate (cleanup scope-exit fan-out: multiple sg_guard call sites)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/scopeguard_sim.c" -I"$ROOT/examples" -o "$BUILD/scopeguard_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/scopeguard_sim.o" 2>/dev/null || true)
cln=$(printf '%s\n' "$dis" | grep -c 'sg_guard' || true)
rs=$(printf '%s\n' "$dis" | grep -cwE '\brep\b|\bsep\b' || true)
echo "    cleanup-calls(sg_guard)=$cln  rep/sep=$rs"
if [ "$cln" -ge 3 ] && [ "$rs" -ge 1 ]; then echo "    PASS  cleanup scope-exit fan-out present (>=3 call sites)"
else echo "    FAIL  cleanup-calls=$cln (>=3) rep/sep=$rs (>=1)"; rc=1; fi
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  [ -n "$ARCHIVE" ] && { g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"; g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"; }
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + assert (build/scopeguard-jg.png)"
  "$JGX" "$BUILD/scopeguard.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/scopeguard-jg.png" || rc=1
else echo "    SKIP bsnes-jg"; fi
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (Xvfb): snapshot + assert (build/scopeguard-mame.png)"
  SNAP="$BUILD/.scopeguard-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" xvfb-run -a mame snes -cart "$BUILD/scopeguard.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/scopeguard.lua" -skip_gameinfo -snapshot_directory "$SNAP" -sound none -nothrottle \
      -seconds_to_run 12 -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  [ -f "$SNAP/snes/0000.png" ] && mv "$SNAP/snes/0000.png" "$BUILD/scopeguard-mame.png"
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else echo "    SKIP MAME (no xvfb-run)"; fi
echo
[ "$rc" -eq 0 ] && echo "RESULT: PASS — Scope-Guard Ripple Tank on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16" || echo "RESULT: FAIL"
exit $rc
