#!/usr/bin/env bash
# dev/xy16inplace.sh — differential regression gate for the iterative in-place memmove/memcpy over a
# 16-bit-indexed buffer (the #23 L-system shape). Reported 2026-06-29 as a +mos-xy16 miscompile; proven
# NOT reproducible on the full patch stack (the 16-bit index uses the dedicated G_*_ABS_IDX16 path).
# This gate LOCKS THAT IN: host==default==+mos-a16==+mos-xy16, for CAP=1700 (16-bit indices) AND CAP=200
# (8-bit indices, the trunc/B1 path). Any future regression hard-FAILs. Drive: dev/run.sh xy16inplace.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh xy16inplace  # 5-way differential gate, in-place memmove over a 16-bit-indexed buffer"; exit 0;; esac
ROOT=/work; B="$ROOT/build"
TOOL="$B/llvm-mos-install/bin"; CFG="$B/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/65816/xy16inplace.c"
DB="$ROOT/vendor/bsnes-jg/Database"; JGX="$B/jgxcheck"
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain"; exit 1; }
[ -x "$JGX" ] && [ -d "$DB" ] || { echo "    SKIP bsnes-jg (harness absent)"; exit 0; }
rc=0
for CAP in 1700 200; do
  ref=""
  for spec in "default:" "a16:-Xclang -target-feature -Xclang +mos-a16" "xy16:-Xclang -target-feature -Xclang +mos-xy16"; do
    name="${spec%%:*}"; feat="${spec#*:}"
    "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 $feat -DCAP=$CAP -Os \
      -Wl,-Map="$B/xy16inplace.map" -o "$B/xy16inplace.sfc" "$SRC" 2>/dev/null
    VMA=$(awk '$NF=="corpus_result"{print $1;exit}' "$B/xy16inplace.map")
    got=$("$JGX" "$B/xy16inplace.sfc" "$DB" "0x$VMA" 2 0x0000 600 "$B/xy16inplace-$name.png" 2>/dev/null | grep -oE 'got=0x[0-9A-Fa-f]+' | head -1 | cut -d= -f2 || echo "????")
    [ -z "$ref" ] && ref="$got"
    if [ "$got" = "$ref" ]; then echo "    CAP=$CAP $name = $got"; else echo "    CAP=$CAP $name = $got  != ref $ref  MISMATCH"; rc=1; fi
  done
done
# -verify must be clean under xy16 (the shape that triggered the original -verify worries)
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-xy16 -DCAP=1700 -Os \
  -mllvm -verify-machineinstrs -c "$SRC" -o /dev/null 2>"$B/xy16inplace.verr" && vok=1 || vok=0
if [ "$vok" = 1 ] && ! grep -qi 'machine code error\|dominate' "$B/xy16inplace.verr"; then echo "    -verify xy16 clean"; else echo "    -verify xy16 FAIL"; rc=1; fi
echo
[ "$rc" = 0 ] && echo "RESULT: PASS — in-place memmove/memcpy over a 16-bit-indexed buffer: host==default==a16==xy16 (CAP 1700 & 200), -verify clean" || echo "RESULT: FAIL"
exit $rc
