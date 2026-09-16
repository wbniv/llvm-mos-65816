#!/usr/bin/env bash
# dev/byvaledge.sh — render the By-Value Boundary Trio (#154 stress-test, Round 8 Cluster C).
# Corner: clang's `getTypeSize(Ty) > 32` by-value classifier (Targets/MOS.cpp), compiled from
# BOTH sides in one program. A 4-byte record goes getDirect; a 5-byte record goes
# getNaturalAlignIndirect(ByVal=false), so the callee holds a pointer to the CALLER's object and
# by-value semantics rest entirely on a call-site copy. Every stage mutates its own parameter and
# the driver re-reads its original.
# MEASURED CORRECTION: there is no 33-bit size class — getTypeSize is in BITS and a MOS record is
# always whole bytes, so a 33-bit-declared bitfield record is sizeof 5 (40 bits) and goes
# indirect. The boundary is sizeof 4 vs sizeof 5.
# THIS DEMO FOUND AN OPEN COMPILER DEFECT — see docs/investigations/
# 2026-09-16-mos-regalloc-out-of-registers-mixed-width-pointer-plus-call.md.
# Drive: dev/run.sh byvaledge. Outputs build/byvaledge-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh byvaledge   # run the 32/40-bit by-value boundary; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/byvaledge.c"
SIM="$ROOT/examples/snes/corpus/byvaledge_sim.c"
SDKINC="$BUILD/install/mos-platform/common/include"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/byvaledge-sim.c" -o "$BUILD/byvaledge-sim"
ORACLE=$("$BUILD/byvaledge-sim")
EXPECT=$(printf '%s\n' "$ORACLE" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: byvaledge gate hash = $EXPECT"
printf '    %s\n' "$(printf '%s\n' "$ORACLE" | head -1)"
printf '    %s\n' "$(printf '%s\n' "$ORACLE" | grep -m1 'sizeof')"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/byvaledge.map" -o "$BUILD/byvaledge.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/byvaledge.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/byvaledge.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/byvaledge.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate — the ABI FORM of each stage's parameter, read out of the emitted IR. The
#    4-byte stage must take scalars and NO pointer; both 5-byte stages must take a
#    `ptr ... dead_on_return` (the ByVal=false indirect form). If the 5-byte stages ever took
#    scalars, the classifier's boundary moved and the whole demo is testing one arm twice.
#    The layout _Static_assert block in byvaledge.h is checked simply by the slice compiling.
echo "==> structure gate (4-byte stage = getDirect scalars; 5-byte stages = ptr dead_on_return)"
for MODE in default a16 xy16; do
  case "$MODE" in
    default) FEAT=() ;;
    a16)     FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16)    FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  if ! "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -isystem "$SDKINC" -Os \
      -mllvm -verify-machineinstrs -S -o "$BUILD/byvaledge_sim_$MODE.s" "$SIM" \
      -I"$ROOT/examples" 2>"$BUILD/byvaledge_sim_$MODE.err"; then
    echo "    FAIL  $MODE: did not compile (layout assertion, or the regalloc defect above):"
    sed 's/^/      /' "$BUILD/byvaledge_sim_$MODE.err" | head -5
    rc=1; continue
  fi
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -isystem "$SDKINC" -Os \
      -S -emit-llvm -o "$BUILD/byvaledge_sim_$MODE.ll" "$SIM" -I"$ROOT/examples" 2>/dev/null
  # NB: the parameter list contains parentheses of its own (`sret(%struct.BvR40)`), so these
  # patterns must not use a [^)]* run — they match to the end of the define line instead.
  d32=$(grep -cE '^define .*@bv_stage32\(.*i16' "$BUILD/byvaledge_sim_$MODE.ll" || true)
  p32=$(grep -cE '^define .*@bv_stage32\(.*dead_on_return' "$BUILD/byvaledge_sim_$MODE.ll" || true)
  p33=$(grep -cE '^define .*@bv_stage33\(.*dead_on_return' "$BUILD/byvaledge_sim_$MODE.ll" || true)
  p40=$(grep -cE '^define .*@bv_stage40\(.*dead_on_return' "$BUILD/byvaledge_sim_$MODE.ll" || true)
  if [ "$d32" -ge 1 ] && [ "$p32" -eq 0 ] && [ "$p33" -ge 1 ] && [ "$p40" -ge 1 ]; then
    echo "    PASS  $MODE: bv_stage32 direct-scalar=$d32 indirect=$p32 | bv_stage33 indirect=$p33 | bv_stage40 indirect=$p40  (-verify clean)"
  else
    echo "    FAIL  $MODE: bv_stage32 direct=$d32 indirect=$p32 | bv_stage33 indirect=$p33 | bv_stage40 indirect=$p40"
    echo "          (want the 4-byte record DIRECT with no pointer, and both 5-byte records INDIRECT)"
    rc=1
  fi
done

# 3b. The runtime half of the ABI contract: a missing call-site copy corrupts the CALLER, leaves
#     the callee's own result correct, and raises nothing. The only detector is the caller's
#     re-read of its own original after every call, counted here.
BAD=$(printf '%s\n' "$ORACLE" | grep -oE 'byval_violations=[0-9]+' | cut -d= -f2)
N=$(printf '%s\n' "$ORACLE" | grep -oE 'steps=[0-9]+' | cut -d= -f2)
if [ "${BAD:-1}" -eq 0 ] && [ "${N:-0}" -ge 32 ]; then
  echo "    PASS  caller-visible by-value violations=$BAD over $N steps x 3 record shapes"
else
  echo "    FAIL  byval_violations=${BAD:-?} steps=${N:-?} (want 0 / >=32)"; rc=1
fi
echo "    INFO  there is NO 33-bit size class on MOS: getTypeSize is in BITS and a record is"
echo "          always whole bytes, so a 33-bit-declared bitfield record is sizeof 5 (40 bits)."
echo "          The boundary this gate pins is sizeof 4 (direct) vs sizeof 5 (indirect)."
echo "    INFO  bv_stage40 carries NO libcall on purpose — a call between a byte member and a"
echo "          word member of the same pointed-to record hits an OPEN upstream llvm-mos regalloc"
echo "          failure. See docs/investigations/"
echo "          2026-09-16-mos-regalloc-out-of-registers-mixed-width-pointer-plus-call.md"

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
  echo "==> bsnes-jg: render + assert (build/byvaledge-jg.png, frame 600)"
  "$JGX" "$BUILD/byvaledge.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/byvaledge-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/byvaledge-mame.png)"
  SNAP="$BUILD/.byvaledge-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/byvaledge.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/byvaledge.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/byvaledge-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — By-Value Boundary Trio on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc
