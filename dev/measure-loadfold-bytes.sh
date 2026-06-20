#!/usr/bin/env bash
# dev/measure-loadfold-bytes.sh — Phase-2 byte-diff for
#   docs/plans/2026-06-20-321-unify-loadfold-gate-aa-volatile.md
#
# Compiles each fixture with a BEFORE and an AFTER mos-clang and compares total .text
# bytes (sum of .text* sections in the unlinked .o). Answers both Phase-2 questions:
#   * regression guard: the existing fold tests must be byte-identical or SMALLER (>=0);
#   * recovery: the Phase-1 fixtures should SHRINK (negative delta = bytes recovered).
# Host-side, compile-only (no emulator). Per-file deltas + per-mode totals.
set -euo pipefail
usage(){ cat <<'U'; exit 0
Usage: BEFORE=<baseline mos-clang> AFTER=<patched mos-clang> dev/measure-loadfold-bytes.sh
Env: BEFORE, AFTER (required), OBJDUMP (default: AFTER's sibling llvm-objdump),
     CTORTURE_DIR, EXAMPLES
U
}
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage
BEFORE="${BEFORE:?baseline mos-clang}"; AFTER="${AFTER:?patched mos-clang}"
OBJDUMP="${OBJDUMP:-$(dirname "$AFTER")/llvm-objdump}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLES="${EXAMPLES:-$HERE/examples/65816}"
CTORTURE_DIR="${CTORTURE_DIR:-$HERE/vendor/c-torture/execute}"
COMMON=(--target=mos -mcpu=mosw65816 -Wno-everything -c)
A16=(-Xclang -target-feature -Xclang +mos-a16)
DEFS=(-Dmain=torture_test_main -Dabort=__torture_abort -Dexit=__torture_exit)
TMP="$(mktemp -d)"

textbytes(){ # .o -> total bytes across .text* sections
  "$OBJDUMP" -h "$1" 2>/dev/null | awk '$2 ~ /^\.text/ {s += strtonum("0x"$3)} END{printf "%d", s+0}'
}
row(){ # label mode opt file
  local label="$1" mode="$2" opt="$3" f="$4"
  [ -f "$f" ] || return 0
  local fl=("${COMMON[@]}" "$opt"); [ "$mode" = a16 ] && fl+=("${A16[@]}")
  [ "$label" = torture ] && fl+=("${DEFS[@]}")
  "$BEFORE" "${fl[@]}" "$f" -o "$TMP/b.o" 2>/dev/null || return 0
  "$AFTER"  "${fl[@]}" "$f" -o "$TMP/a.o" 2>/dev/null || return 0
  local b a d; b=$(textbytes "$TMP/b.o"); a=$(textbytes "$TMP/a.o"); d=$((a-b))
  printf '%s\t%s\t%s\t%d\t%d\t%+d\n' "$mode" "$opt" "$(basename "$f")" "$b" "$a" "$d"
}

OUT="$TMP/bytes.tsv"; : > "$OUT"
# whole a16 corpus (a16 -Os, a16 -O1, default -Os) + c-torture Phase-1 fixtures.
for f in "$EXAMPLES"/a16*.c; do
  row a16-tests a16     -Os "$f"; row a16-tests a16 -O1 "$f"; row a16-tests default -Os "$f"
done >> "$OUT"
for nm in 990128-1 packed-1 pr43236 pr85529-1 zero-struct-1 20010604-1 postmod-1 pr38819 20120808-1 pr57281; do
  row torture a16 -Os "$CTORTURE_DIR/$nm.c"; row torture default -Os "$CTORTURE_DIR/$nm.c"
done >> "$OUT"

echo "=== per-file deltas (mode opt file  before after  delta) — nonzero only ==="
awk -F'\t' '$6!="+0"{printf "%-8s %-4s %-26s %6d -> %6d  %s\n",$1,$2,$3,$4,$5,$6}' "$OUT" | sort -t'(' -k1 || true
echo
echo "=== totals ==="
awk -F'\t' '{tb+=$4; ta+=$5; n++; if($6+0<0)win++; if($6+0>0)reg++}
  END{printf "files=%d  total .text: %d -> %d  net delta=%+d bytes\n", n, tb, ta, ta-tb;
      printf "shrunk (recovered): %d files   GREW (regressed): %d files\n", win, reg}' "$OUT"
echo
echo "=== any REGRESSIONS (after > before) — MUST be empty ==="
awk -F'\t' '$6+0>0{printf "  REGRESS %s %s %s  %+d\n",$1,$2,$3,$6}' "$OUT" || echo "  (none)"
cp "$OUT" "$HERE/build/loadfold-bytes-$(date -u +%Y%m%dT%H%M%SZ).tsv" 2>/dev/null || true
