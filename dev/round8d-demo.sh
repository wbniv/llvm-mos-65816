#!/usr/bin/env bash
set -euo pipefail

name="${1:-}"
case "$name" in
  vawidth|sretrec|arityfan|extload|ascast) ;;
  *) echo "Usage: dev/run.sh {vawidth|sretrec|arityfan|extload|ascast}"; exit 2 ;;
esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
VENDOR="$ROOT/vendor/bsnes-jg"
SRC="$ROOT/examples/snes/$name.c"
SLICE="$ROOT/examples/snes/corpus/${name}_sim.c"

. "$ROOT/dev/_emu.sh"
require_bios || exit $?
export SMOKE_SETTLE="${SMOKE_SETTLE:-1000}"
export SMOKE_SECONDS="${SMOKE_SECONDS:-20}"
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no MOS compiler at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK config missing: $CFG"; exit 1; }

cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/$name-sim.c" -o "$BUILD/$name-host"
ORACLE=$("$BUILD/$name-host")
EXPECT=$(printf '%s\n' "$ORACLE" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: $name gate hash = $EXPECT"

rc=0
MODES=(default a16 xy16)
if [ "$name" = ascast ]; then MODES=(a16); fi
for mode in "${MODES[@]}"; do
  case "$mode" in
    default) FEAT=() ;;
    a16) FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16) FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  IR=$($TOOL/mos-clang --target=mos -mcpu=mosw65816 "${FEAT[@]}" -Os -S -emit-llvm -o - "$SLICE" -I"$ROOT/examples" 2>/dev/null) || exit 1
  MIR=$($TOOL/mos-clang --target=mos -mcpu=mosw65816 "${FEAT[@]}" -Os -c -o /dev/null \
    -mllvm -print-before=legalizer "$SLICE" -I"$ROOT/examples" 2>&1) || exit 1
  ASM="$BUILD/${name}_${mode}.s"
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -Os -mllvm -verify-machineinstrs \
    -S -o "$ASM" "$SLICE" -I"$ROOT/examples"
  case "$name" in
    vawidth)
      START=$(printf '%s\n' "$MIR" | grep -c 'G_VASTART' || true)
      READS=$(printf '%s\n' "$MIR" | grep -cE 'G_(LOAD|ZEXTLOAD|SEXTLOAD)' || true)
      GATE=$((START + READS)); MIN=6; DETAIL="G_VASTART=$START argument-loads=$READS" ;;
    sretrec)
      SRET=$(printf '%s\n' "$IR" | grep -c 'sret(' || true)
      RECUR=$(printf '%s\n' "$IR" | grep -c '@sr_recur(' || true)
      GATE=$((SRET + RECUR)); MIN=4; DETAIL="sret=$SRET recursive-calls=$RECUR" ;;
    arityfan) GATE=$(printf '%s\n' "$IR" | grep -cE 'call .*%[0-9]+' || true); MIN=4; DETAIL="indirect-calls=$GATE" ;;
    extload)
      S=$(printf '%s\n' "$MIR" | grep -c 'G_SEXTLOAD' || true)
      Z=$(printf '%s\n' "$MIR" | grep -c 'G_ZEXTLOAD' || true)
      GATE=$((S + Z)); MIN=12; DETAIL="G_SEXTLOAD=$S G_ZEXTLOAD=$Z" ;;
    ascast) GATE=$(printf '%s\n' "$MIR" | grep -c 'G_ADDRSPACE_CAST' || true); MIN=2; DETAIL="G_ADDRSPACE_CAST=$GATE" ;;
  esac
  if [ "$GATE" -ge "$MIN" ] && { [ "$name" != extload ] || { [ "$S" -ge 6 ] && [ "$Z" -ge 6 ]; }; }; then
    echo "    PASS $mode: $DETAIL; machine verifier clean"
  else echo "    FAIL $mode: $DETAIL (minimum structure count $MIN)"; rc=1; fi
done

if [ "$name" != ascast ]; then
  if ! python3 "$ROOT/tools/a16_fuzz.py" check --src "$SLICE" --name "round8-$name" --expected "$EXPECT"; then rc=1; fi
fi

FEATURE=(-Xclang -target-feature -Xclang +mos-a16)
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${FEATURE[@]}" -Os -mllvm -verify-machineinstrs \
  -Wl,-Map="$BUILD/$name.map" -o "$BUILD/$name.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/$name.sfc" >/dev/null
read -r VMA SIZE < <(awk -v s=corpus_result '$NF==s {print $1, $(NF-1); exit}' "$BUILD/$name.map")
[ -n "${VMA:-}" ] || { echo "FATAL: corpus_result missing from $name map"; exit 1; }
echo "==> built $BUILD/$name.sfc (+mos-a16), corpus_result @ WRAM 0x$VMA"
run_assert "$BUILD/$name.sfc" "$BUILD/$name.map" corpus_result "$EXPECT" || rc=1

JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE=$(find "$VENDOR/objs" -name '*.a' -print -quit 2>/dev/null || true)
  if [ -n "$ARCHIVE" ]; then
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  OFF="0x$VMA"
  "$JGX" "$BUILD/$name.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 "$BUILD/$name-jg.png" || rc=1
else
  echo "FAIL: bsnes-jg harness or database is unavailable"; rc=1
fi

if [ "$rc" -eq 0 ]; then echo "RESULT: PASS — $name host/target and emulator gates agree at $EXPECT"
else echo "RESULT: FAIL — $name"; fi
exit "$rc"
