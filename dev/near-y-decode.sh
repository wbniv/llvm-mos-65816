#!/usr/bin/env bash
# Check byte-exact near decoding with indices above 255 in each width mode.
# Run inside the development container: dev/container.sh -- bash dev/near-y-decode.sh.
set -euo pipefail
ROOT=/work
TOOL="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin"
OUT="${NEAR_Y_BUILD:-$ROOT/build/near-y-decode}"
SRC="$ROOT/examples/65816/near-y-decode.c"
mkdir -p "$OUT"
cc -O2 -DHOST_TEST "$SRC" -o "$OUT/host"
"$OUT/host"
for fixture in near-y-decode near-index-wrap; do
  SRC="$ROOT/examples/65816/$fixture.c"
  for mode in default a16 xy16; do
    features=()
    if [[ "$mode" != default ]]; then
      features+=(-Xclang -target-feature -Xclang +mos-a16)
    fi
    if [[ "$mode" == xy16 ]]; then
      features+=(-Xclang -target-feature -Xclang +mos-xy16)
    fi
    for lto in lto nonlto; do
      flags=()
      if [[ "$lto" == nonlto ]]; then flags+=(-fno-lto); fi
      stem="$OUT/$fixture-$mode-$lto"
      "$TOOL/clang" --config "$ROOT/build/install/bin/mos-snes.cfg" \
        -mcpu=mosw65816 -Oz "${features[@]}" "${flags[@]}" \
        -mllvm -verify-machineinstrs -Wl,-mllvm,-verify-machineinstrs \
        -Wl,-Map="$stem.map" "$SRC" -o "$stem.sfc"
      python3 "$ROOT/tools/snes-checksum.py" "$stem.sfc"
      addr=$(awk '$NF == "corpus_result" { print $1; exit }' "$stem.map")
      test -n "$addr"
      "$ROOT/build/jgxcheck" "$stem.sfc" "$ROOT/vendor/bsnes-jg/Database" \
        "0x$addr" 2 0x5CF0 180
    done
  done
done
echo 'RESULT: PASS — near decoder and bank wrapping, three width modes, with and without LTO'
