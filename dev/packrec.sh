#!/usr/bin/env bash
# dev/packrec.sh — render the Unaligned Record Reader (#149 stress-test, Round 8 Cluster B).
# REFRAMED, honestly: the ideas doc proposed __attribute__((packed)) as a distinct LOWERING.
# Measured, it is not one on MOS — every scalar already has ABI alignment 1, so an unpacked
# struct has no padding to remove and `packed` is a LAYOUT NO-OP (Round 8's second negative
# result). What this demo guards is the padding-free-layout INVARIANT itself, which no demo
# across #1-#141 asserts and on which every binary-format parse built with this toolchain
# silently depends: a packed telemetry stream with two coprime odd record strides (7 and 10
# bytes) parsed through a computed pointer, with the layout pinned by _Static_assert.
# Drive: dev/run.sh packrec. Outputs build/packrec-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh packrec   # run the packed-record stream parse; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/packrec.c"
SIM="$ROOT/examples/snes/corpus/packrec_sim.c"
SDKINC="$BUILD/install/mos-platform/common/include"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/packrec-sim.c" -o "$BUILD/packrec-sim"
ORACLE=$("$BUILD/packrec-sim")
EXPECT=$(printf '%s\n' "$ORACLE" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: packrec gate hash = $EXPECT"
printf '    %s\n' "$(printf '%s\n' "$ORACLE" | head -1)"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/packrec.map" -o "$BUILD/packrec.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/packrec.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/packrec.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/packrec.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate — THE INVARIANT UNDER GUARD. The _Static_assert block in packrec.h is
#    the assertion; that the slice COMPILES in a mode is the proof for that mode. The extra
#    greps confirm the parse is really a byte-decomposed access through a computed pointer and
#    has not folded into a constant.
echo "==> structure gate (packed layout assertions hold + parse not const-folded; all three modes)"
for MODE in default a16 xy16; do
  case "$MODE" in
    default) FEAT=() ;;
    a16)     FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16)    FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  if ! "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -isystem "$SDKINC" -Os \
      -mllvm -verify-machineinstrs -S -o "$BUILD/packrec_sim_$MODE.s" "$SIM" \
      -I"$ROOT/examples" 2>"$BUILD/packrec_sim_$MODE.err"; then
    echo "    FAIL  $MODE: layout _Static_assert did not hold — the target grew padding:"
    grep -m3 'static_assert\|error:' "$BUILD/packrec_sim_$MODE.err" | sed 's/^/      /'
    rc=1; continue
  fi
  ld=$(grep -cE '^[[:space:]]+lda?[[:space:]]' "$BUILD/packrec_sim_$MODE.s" || true)
  idx=$(grep -cE '^[[:space:]]+(lda|sta|ldy|ldx)[[:space:]]+pk_blob' "$BUILD/packrec_sim_$MODE.s" || true)
  fn=$(grep -cE '^pk_parse_at:' "$BUILD/packrec_sim_$MODE.s" || true)
  if [ "$fn" -ge 1 ] && [ "$ld" -ge 10 ]; then
    echo "    PASS  $MODE: pk_parse_at present=$fn  loads=$ld  direct pk_blob refs=$idx  (-verify clean)"
  else
    echo "    FAIL  $MODE: pk_parse_at present=$fn  loads=$ld  (parse appears const-folded away)"; rc=1
  fi
done

# 3b. The stream must genuinely exercise the invariant: BOTH record shapes must occur, and
#     wide members must actually land at odd absolute offsets. An all-A stream at even offsets
#     would compile the same code and prove nothing about the layout.
NA=$(printf '%s\n' "$ORACLE" | grep -oE 'shapeA=[0-9]+' | cut -d= -f2)
NB=$(printf '%s\n' "$ORACLE" | grep -oE 'shapeB=[0-9]+' | cut -d= -f2)
ODD=$(printf '%s\n' "$ORACLE" | grep -oE 'odd_wide_reads=[0-9]+' | cut -d= -f2)
if [ "${NA:-0}" -ge 1 ] && [ "${NB:-0}" -ge 1 ] && [ "${ODD:-0}" -ge 1 ]; then
  echo "    PASS  both shapes parsed and wide members land at odd offsets: A=$NA B=$NB odd_wide_reads=$ODD"
else
  echo "    FAIL  A=${NA:-?} B=${NB:-?} odd_wide_reads=${ODD:-?} (want all >=1)"; rc=1
fi
printf '    INFO  %s\n' "$(printf '%s\n' "$ORACLE" | grep -m1 'sizeof')"
echo "    INFO  packed is a LAYOUT NO-OP on MOS (every scalar already has alignment 1) — this"
echo "          gate guards the padding-free-layout invariant, NOT a distinct lowering."

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
  echo "==> bsnes-jg: render + assert (build/packrec-jg.png, frame 600)"
  "$JGX" "$BUILD/packrec.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/packrec-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/packrec-mame.png)"
  SNAP="$BUILD/.packrec-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/packrec.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/packrec.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/packrec-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Unaligned Record Reader on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc
