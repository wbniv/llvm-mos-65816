#!/usr/bin/env bash
# throwaway: full 5-way-on-bsnes-jg check for a demo (default==a16==xy16==host) + -verify.
# Usage: dev/run.sh _demo5 <slug>
set -euo pipefail
SLUG="${1:?usage: dev/run.sh _demo5 <slug>}"
ROOT=/work; BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/$SLUG.c"
VENDOR="$ROOT/vendor/bsnes-jg"
JGX="$BUILD/jgxcheck"

cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/$SLUG-sim.c" -o "$BUILD/$SLUG-sim"
EXPECT=$("$BUILD/$SLUG-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "host oracle = $EXPECT"

build_variant() {  # name flags...
  local name="$1"; shift
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "$@" -Os \
    -Wl,-Map="$BUILD/$SLUG-$name.map" -o "$BUILD/$SLUG-$name.sfc" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/$SLUG-$name.sfc" >/dev/null
  awk '$NF=="corpus_result"{print "0x"$1; exit}' "$BUILD/$SLUG-$name.map"
}

echo "== -verify-machineinstrs =="
for feat in +mos-a16 +mos-xy16; do
  if "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang $feat -Os \
       -mllvm -verify-machineinstrs -c "$ROOT/examples/snes/corpus/${SLUG}_sim.c" \
       -I"$ROOT/examples" -o "$BUILD/${SLUG}_verify.o" 2>"$BUILD/${SLUG}_verify.log"; then
    echo "  $feat: verify OK"
  else
    echo "  $feat: verify FAILED"; cat "$BUILD/${SLUG}_verify.log"; exit 1
  fi
done

echo "== build + bsnes-jg each variant =="
DVMA=$(build_variant default)
AVMA=$(build_variant a16 -Xclang -target-feature -Xclang +mos-a16)
XVMA=$(build_variant xy16 -Xclang -target-feature -Xclang +mos-xy16)
echo "  vmas: default=$DVMA a16=$AVMA xy16=$XVMA"

rc=0
"$JGX" "$BUILD/$SLUG-default.sfc" "$VENDOR/Database" "$DVMA" 2 "$EXPECT" 500 "$BUILD/$SLUG-d.png" || rc=1
"$JGX" "$BUILD/$SLUG-a16.sfc"     "$VENDOR/Database" "$AVMA" 2 "$EXPECT" 500 "$BUILD/$SLUG-a.png" || rc=1
"$JGX" "$BUILD/$SLUG-xy16.sfc"    "$VENDOR/Database" "$XVMA" 2 "$EXPECT" 500 "$BUILD/$SLUG-x.png" || rc=1
echo
[ "$rc" -eq 0 ] && echo "RESULT: PASS — host==default==a16==xy16==$EXPECT on bsnes-jg" || echo "RESULT: FAIL"
exit $rc
