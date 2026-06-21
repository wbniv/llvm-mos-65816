#!/usr/bin/env bash
# measure-far-ptr-value-state.sh — characterize how complete the far-pointer (addrspace 2)
# VALUE TYPE is today, separating what WORKS from what is MISSING-but-desirable.
#
# Context: the #320 far-pointer slice lowers far *accesses* (load/store/deref/arith/calls),
# but a far pointer is only a complete C type if you can also STORE it in memory (globals,
# arrays, struct fields), pass/return it, and take sizeof. This probe maps that surface so
# the gap is measured, not assumed. Companion to dev/measure-five-space-census.sh.
#
# Runs every probe BOTH default (8-bit) and +mos-a16 (the regime far code targets), since the
# far value machinery (4xs8->s32 merge) is +mos-a16-gated. Host-side; no vendor edits.
set -euo pipefail
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { sed -n '2,14p' "$0"; exit 0; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLANG="${CLANG:-$ROOT/build/llvm-mos-install/bin/mos-clang}"
BASE=( "$CLANG" --target=mos -mcpu=mosw65816 -Os -std=c23 -mllvm -verify-machineinstrs )
A16=( -Xclang -target-feature -Xclang +mos-a16 )
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
bold(){ printf '\e[1m%s\e[0m\n' "$*"; }

# probe NAME CODE  -> prints "<default>  |  <a16>"
probe() {
  local name="$1" code="$2" o8 oa
  printf '#define AS(n) __attribute__((address_space(n)))\n%s\n' "$code" > "$TMP/p.c"
  o8=$(run "${BASE[@]}");           : # default
  oa=$(run "${BASE[@]}" "${A16[@]}")
  printf '  %-30s  default: %-22s  +mos-a16: %s\n' "$name" "$o8" "$oa"
}
run() { if "$@" -c "$TMP/p.c" -o /dev/null 2>"$TMP/p.e"; then echo "OK"
        elif grep -q Segmentation "$TMP/p.e"; then echo "SEGFAULT"
        elif grep -q 'machine code errors' "$TMP/p.e"; then echo "verify-FAIL"
        elif grep -q 'unable to legalize' "$TMP/p.e"; then echo "no-legalize"
        else echo "ERR"; fi; }

bold "═══ far-pointer (addrspace 2) value-type completeness ═══"
echo "toolchain: $CLANG"
echo
bold "WORKS today — transient use (cast an address -> far -> deref):"
probe "deref constant far addr"    'char r(void){ return *(volatile char AS(2)*)0x7E1234; }'
probe "near->far cast + deref"     'char g(char *p){ return *(char AS(2)*)p; }'
echo
bold "MISSING but desirable — far pointer as a STORED value:"
probe "store far ptr -> global"    'char AS(2)*G; void s(char AS(2)*p){ G=p; }'
probe "load  far ptr <- global"    'char AS(2)*G; char d(void){ return *G; }'
probe "array of far ptrs"          'char AS(2)*T[4]; char r(int i){ return *T[i]; }'
probe "struct w/ far ptr field"    'struct E{char AS(2)*p;char t;}; char d(struct E*e){return *e->p;}'
echo
bold "MISSING but desirable — narrowing / cross-space casts:"
probe "far->near cast + deref"     'char g(char AS(2)*p){ return *(char*)p; }'
probe "dp->near cast + deref"      'char g(char AS(1)*p){ return *(char*)p; }'
echo
bold "Front-end size (mode-independent):"
printf '#define AS(n) __attribute__((address_space(n)))\n_Static_assert(sizeof(char AS(2)*)==4,"");\n' > "$TMP/s.c"
if "${BASE[@]}" -c "$TMP/s.c" -o /dev/null 2>"$TMP/s.e"; then echo "  sizeof(far*) == 4  ✓"
else echo "  sizeof(far*) $(grep -oE "'[0-9]+ == 4'" "$TMP/s.e" | head -1) ✗  (clang getPointerWidthV lacks case 2: return 32)"; fi
echo
bold "Reading: far pointers are a COMPLETE address mechanism but an INCOMPLETE value type."
echo "Storing/loading/aggregating a far pointer, and sizeof, are real missing capabilities"
echo "(desirable M1 far-pointer completion) — NOT reasons the model is a dead end. The p2-value"
echo "CC half (pass/return) lives in 0004 (wt/320-far-cc); the in-memory + sizeof half is open."
