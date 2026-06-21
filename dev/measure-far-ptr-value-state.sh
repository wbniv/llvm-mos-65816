#!/usr/bin/env bash
# measure-far-ptr-value-state.sh — characterize how complete the far-pointer (addrspace 2)
# VALUE TYPE is today, separating what WORKS from what is MISSING-but-desirable.
#
# Compiles the committed evidence fixtures in examples/65816/far-value-evidence/ (the single
# source of truth — inspectable sample programs) BOTH default (8-bit) and +mos-a16, since the
# far value machinery (4xs8->s32 merge) is +mos-a16-gated. Host-side; no vendor edits.
# Several fixtures intentionally fail to compile — that failure IS the measurement.
#
# Full write-up + verbatim errors + the MVT::i24 analysis: that directory's README.md.
set -euo pipefail
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { sed -n '2,12p' "$0"; exit 0; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLANG="${CLANG:-$ROOT/build/llvm-mos-install/bin/mos-clang}"
DIR="$ROOT/examples/65816/far-value-evidence"
BASE=( "$CLANG" --target=mos -mcpu=mosw65816 -Os -std=c23 -mllvm -verify-machineinstrs )
A16=( -Xclang -target-feature -Xclang +mos-a16 )
bold(){ printf '\e[1m%s\e[0m\n' "$*"; }

classify() { # compiles $1; prints OK / no-legalize / verify-FAIL / SEGFAULT / sizeof / ERR
  local e; e=$(mktemp)
  if "$@" 2>"$e"; then echo OK
  elif grep -q Segmentation "$e"; then echo SEGFAULT
  elif grep -q 'machine code errors' "$e"; then echo verify-FAIL
  elif grep -q 'unable to legalize' "$e"; then echo no-legalize
  elif grep -qE "'[0-9]+ == 4'" "$e"; then grep -oE "'[0-9]+ == 4'" "$e" | head -1
  else echo ERR; fi
  rm -f "$e"
}

bold "═══ far-pointer (addrspace 2) value-type completeness ═══"
echo "toolchain: $CLANG"
echo "fixtures : $DIR  (see its README.md for the full write-up)"
echo
printf '  %-24s %-16s %s\n' "fixture" "default" "+mos-a16"
printf '  %-24s %-16s %s\n' "-------" "-------" "--------"
for f in "$DIR"/*.c; do
  [ -e "$f" ] || { echo "  (no fixtures found)"; break; }
  d=$(classify "${BASE[@]}" -c "$f" -o /dev/null)
  a=$(classify "${BASE[@]}" "${A16[@]}" -c "$f" -o /dev/null)
  printf '  %-24s %-16s %s\n' "$(basename "$f")" "$d" "$a"
done
echo
bold "Reading: a COMPLETE address mechanism (t*/m1 OK) but an INCOMPLETE value type"
echo "(s* store/load/aggregate fail, z1 sizeof==2, c* narrowing casts fail). m1 proves a 24-bit"
echo "value already flows MVT-free (byte-narrowed) — so packed-24 needs no MVT::i24. Completing"
echo "the far-pointer value type is the desirable M1 work; the new spaces are deferred."
