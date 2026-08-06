#!/usr/bin/env bash
# dev/xy16inplace.sh — differential regression gate for the iterative in-place memmove/memcpy over a
# 16-bit-indexed buffer (the #23 L-system shape). This was a REAL +mos-xy16 miscompile (CAP=1700
# xy16=0x1CC6 vs 0x90AA), fixed in MOSInsertREPSEP::placeIntraBlock (commit e643329): a `sep #$10`
# between `ldx __rcN` and `lda buf,X16` zeroed X's high byte, so the indexed load read buf[i&0xFF].
# This gate LOCKS THE FIX IN: default==+mos-a16==+mos-xy16, for CAP=1700 (16-bit indices, the
# bug) AND CAP=200 (8-bit indices). Any regression hard-FAILs. Drive: dev/run.sh xy16inplace.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh xy16inplace  # 5-way differential gate, in-place memmove over a 16-bit-indexed buffer"; exit 0;; esac
ROOT=/work; B="$ROOT/build"
TOOL="$B/llvm-mos-install/bin"; CFG="$B/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/65816/xy16-inplace-memmove-repro.c"
DB="$ROOT/vendor/bsnes-jg/Database"; JGX="$B/jgxcheck"
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain"; exit 1; }
[ -x "$JGX" ] && [ -d "$DB" ] || { echo "    SKIP bsnes-jg (harness absent)"; exit 0; }
rc=0
for CAP in 1700 200; do
  ref=""
  for spec in "default:" "a16:-Xclang -target-feature -Xclang +mos-a16" "xy16:-Xclang -target-feature -Xclang +mos-xy16"; do
    name="${spec%%:*}"; feat="${spec#*:}"
    # shellcheck disable=SC2086 # intentional feature-flag bundle
    "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 $feat -DCAP=$CAP -Os \
      -Wl,-Map="$B/xy16inplace.map" -o "$B/xy16inplace.sfc" "$SRC" 2>/dev/null
    VMA=$(awk '$NF=="corpus_result"{print $1;exit}' "$B/xy16inplace.map")
    # Discover the default build's value, then make every leg pass that value
    # through jgxcheck's real assertion path. The old code discarded stderr and
    # compared three "????" strings, allowing a total emulator failure to PASS.
    if [ -z "$ref" ]; then
      probe=$("$JGX" "$B/xy16inplace.sfc" "$DB" "0x$VMA" 2 0x0000 600 \
        "$B/xy16inplace-$CAP-$name.png" 2>&1 || true)
      ref=$(printf '%s\n' "$probe" | grep -oE 'got=0x[0-9A-Fa-f]+' | head -1 | cut -d= -f2 || true)
      if [ -z "$ref" ]; then
        echo "    CAP=$CAP $name: bsnes-jg produced no readable result"
        rc=1
        continue
      fi
    fi
    if jgout=$("$JGX" "$B/xy16inplace.sfc" "$DB" "0x$VMA" 2 "$ref" 600 \
      "$B/xy16inplace-$CAP-$name.png" 2>&1); then
      got=$(printf '%s\n' "$jgout" | grep -oE 'got=0x[0-9A-Fa-f]+' | head -1 | cut -d= -f2 || true)
      jgline=$(printf '%s\n' "$jgout" | grep -m1 'frames, bsnes-jg' || true)
      if [ "$got" = "$ref" ] && [ -n "$jgline" ]; then
        echo "    CAP=$CAP $name = $got"
        echo "    $jgline"
      else
        echo "    CAP=$CAP $name: malformed bsnes-jg PASS output"
        rc=1
      fi
    else
      echo "    CAP=$CAP $name: bsnes-jg assertion failed"
      printf '%s\n' "$jgout" | tail -3 | sed 's/^/      | /'
      rc=1
    fi
  done
done
# -verify must be clean under xy16 (the shape that triggered the original -verify worries)
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-xy16 -DCAP=1700 -Os \
  -mllvm -verify-machineinstrs -c "$SRC" -o /dev/null 2>"$B/xy16inplace.verr" && vok=1 || vok=0
if [ "$vok" = 1 ] && ! grep -qi 'machine code error\|dominate' "$B/xy16inplace.verr"; then echo "    -verify xy16 clean"; else echo "    -verify xy16 FAIL"; rc=1; fi
echo
[ "$rc" = 0 ] && echo "RESULT: PASS — in-place memmove/memcpy over a 16-bit-indexed buffer: default==a16==xy16 on bsnes-jg (CAP 1700 & 200), -verify clean" || echo "RESULT: FAIL"
exit $rc
