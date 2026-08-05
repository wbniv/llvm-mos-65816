#!/usr/bin/env bash
# Round 7 #126: per-function default/a16 width boundaries in one link.
set -euo pipefail
ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/mixedwidth.c"
VENDOR="$ROOT/vendor/bsnes-jg"

cc -O2 "$ROOT/tools/mixedwidth-sim.c" -o "$BUILD/mixedwidth-sim"
EXPECT=$("$BUILD/mixedwidth-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | head -1)
echo "==> host oracle: mixedwidth gate hash = $EXPECT"

A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16)
for mode in default a16 xy16; do
  feat=()
  [ "$mode" = a16 ] && feat=("${A16[@]}")
  [ "$mode" = xy16 ] && feat=("${XY16[@]}")
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" -Os \
    -mllvm -verify-machineinstrs -Wl,-Map="$BUILD/mixedwidth-$mode.map" \
    -o "$BUILD/mixedwidth-$mode.sfc" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/mixedwidth-$mode.sfc" >/dev/null
done

echo "==> per-function feature/disassembly gate"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Os -S -emit-llvm \
  "$ROOT/examples/65816/mixedwidth-probe.c" -o "$BUILD/mixedwidth.ll"
grep -q '"target-features"="+mos-a16"' "$BUILD/mixedwidth.ll"
grep -q '"target-features"="-mos-a16,-mos-xy16"' "$BUILD/mixedwidth.ll"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Os -mllvm -verify-machineinstrs -c \
  "$ROOT/examples/65816/mixedwidth-probe.c" -o "$BUILD/mixedwidth-probe.o"
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/mixedwidth-probe.o")
native=$(printf '%s\n' "$dis" | awk '/<mw_native>:/{p=1} p{print} p && /rts/{exit}')
byte=$(printf '%s\n' "$dis" | awk '/<mw_byte>:/{p=1} p{print} p && /rts/{exit}')
printf '%s\n' "$native" | grep -q $'\trep\t#$20'
printf '%s\n' "$native" | grep -q $'\tsep\t#$20'
if printf '%s\n' "$byte" | grep -Eq $'\t(rep|sep)\t'; then
  echo "FAIL: forced-default mw_byte contains a width transition"
  exit 1
fi
echo "    PASS: native function brackets M16; forced-default function remains A8"

rc=0
JGX="$BUILD/jgxcheck"
for mode in default a16 xy16; do
  VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/mixedwidth-$mode.map")
  "$JGX" "$BUILD/mixedwidth-$mode.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" 300 \
    "$BUILD/mixedwidth-$mode-jg.png" || rc=1
done
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Split-Personality Link; host == default == a16 == xy16 == $EXPECT"
else
  echo "RESULT: FAIL — per-function width boundary changed the computed value"
fi
exit "$rc"
