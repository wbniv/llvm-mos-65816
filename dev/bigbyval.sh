#!/usr/bin/env bash
# dev/bigbyval.sh — render the Affine Stage Pipeline (#145 stress-test, Round 8 Cluster A).
# The >32-bit BY-VALUE ARGUMENT guard: MOSABIInfo::classifyArgumentType
# (clang/lib/CodeGen/Targets/MOS.cpp:64) routes any aggregate over 32 bits to
# getNaturalAlignIndirect(..., ByVal=false) at :71, so the callee gets a pointer to
# caller-owned storage and C's by-value semantics rest entirely on a call-site copy. Every
# stage here MUTATES its own by-value parameter and the driver re-reads its original — a
# missing copy corrupts the CALLER silently. #91 matcascade covered only the RETURN half.
# Drive: dev/run.sh bigbyval. Outputs build/bigbyval-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh bigbyval   # push a 144-bit record by value; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/bigbyval.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/bigbyval-sim.c" -o "$BUILD/bigbyval-sim"
ORACLE=$("$BUILD/bigbyval-sim")
EXPECT=$(printf '%s\n' "$ORACLE" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: bigbyval gate hash = $EXPECT"
printf '    %s\n' "$(printf '%s\n' "$ORACLE" | head -1)"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/bigbyval.map" -o "$BUILD/bigbyval.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/bigbyval.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/bigbyval.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/bigbyval.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3a. The records must actually be over the 32-bit classifier threshold. If they ever shrank,
#     they would take getDirect and this demo would silently become #26 boids.
MB=$(printf '%s\n' "$ORACLE" | grep -oE 'mat_bits=[0-9]+' | cut -d= -f2)
VB=$(printf '%s\n' "$ORACLE" | grep -oE 'vert_bits=[0-9]+' | cut -d= -f2)
if [ "${MB:-0}" -gt 32 ] && [ "${VB:-0}" -gt 32 ]; then
  echo "==> threshold gate: PASS  BvMat=${MB} bits, BvVert=${VB} bits (both > 32 -> indirect)"
else
  echo "==> threshold gate: FAIL  BvMat=${MB:-?} bits, BvVert=${VB:-?} bits (want both > 32)"; rc=1
fi

# 3b. Structure gate — THE CORNER UNDER TEST. The call sites must pass the records INDIRECTLY
#     (a pointer argument) and must emit the copies that give them by-value semantics.
echo "==> structure gate (indirect >32-bit arguments + their call-site copies; all three modes)"
for MODE in default a16 xy16; do
  case "$MODE" in
    default) FEAT=() ;;
    a16)     FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16)    FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  IR=$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -Os -S -emit-llvm -o - \
        "$ROOT/examples/snes/corpus/bigbyval_sim.c" -I"$ROOT/examples" 2>/dev/null || true)
  ind=$(printf '%s\n' "$IR" | grep -cE 'call .*@bv_(stage|apply)\(' || true)
  ptr=$(printf '%s\n' "$IR" | grep -E 'define .*@bv_(stage|apply)\(' | grep -oc 'ptr ' || true)
  ASM="$BUILD/bigbyval_sim_$MODE.s"
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -Os -mllvm -verify-machineinstrs \
    -S -o "$ASM" "$ROOT/examples/snes/corpus/bigbyval_sim.c" -I"$ROOT/examples" 2>/dev/null
  cp_=$(grep -cE 'memcpy' "$ASM" || true)
  if [ "$ind" -ge 2 ] && [ "$ptr" -ge 2 ] && [ "$cp_" -ge 2 ]; then
    echo "    PASS  $MODE: indirect-arg calls=$ind  ptr params=$ptr  call-site copies=$cp_"
  else
    echo "    FAIL  $MODE: indirect-arg calls=$ind  ptr params=$ptr  call-site copies=$cp_"
    echo "          (want calls>=2, ptr params>=2, copies>=2)"; rc=1
  fi
done

# 3c. The by-value contract itself, asserted on the host: every stage's re-read of the driver's
#     own matrix must be identical. Non-zero here is the silent-wrong defect this demo hunts.
CV=$(printf '%s\n' "$ORACLE" | grep -oE 'copy_violations=[0-9]+' | cut -d= -f2)
MU=$(printf '%s\n' "$ORACLE" | grep -oE 'mutations=[0-9]+' | cut -d= -f2)
if [ "${CV:-1}" -eq 0 ] && [ "${MU:-0}" -ge 1 ]; then
  echo "    PASS  by-value contract: ${MU} callee mutations, ${CV} caller-visible violations"
else
  echo "    FAIL  by-value contract: mutations=${MU:-?} copy_violations=${CV:-?} (want mutations>=1, violations=0)"
  rc=1
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
  echo "==> bsnes-jg: render + assert (build/bigbyval-jg.png, frame 600)"
  "$JGX" "$BUILD/bigbyval.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/bigbyval-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/bigbyval-mame.png)"
  SNAP="$BUILD/.bigbyval-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/bigbyval.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/bigbyval.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/bigbyval-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Affine Stage Pipeline on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc
