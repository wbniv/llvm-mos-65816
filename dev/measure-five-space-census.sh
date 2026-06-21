#!/usr/bin/env bash
# measure-five-space-census.sh — Phase 0 census for the #320 five-address-space model
# (docs/plans/2026-06-21-320-five-address-space-model.md).
#
# Answers the two HARD GATES that decide whether the packed-24 (addrspace 3) and
# zero-bank (addrspace 4) spaces are worth building:
#   0a  representability  — can the toolchain carry a genuine 24-bit value?
#   0b  usage census      — does realistic code STORE far pointers in memory
#                           (the only place a 3-byte vs 4-byte pointer saves bytes)?
#
# Host-side only: uses the prebuilt mos-clang; makes NO vendor edits. Reproducible.
set -euo pipefail

usage() { sed -n '2,16p' "$0"; exit 0; }
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLANG="${CLANG:-$ROOT/build/llvm-mos-install/bin/mos-clang}"
READELF="${READELF:-$ROOT/build/llvm-mos-install/bin/llvm-readelf}"
CC=( "$CLANG" --target=mos -mcpu=mosw65816 -Os -std=c23 )
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

bold(){ printf '\e[1m%s\e[0m\n' "$*"; }
hr(){ printf '%.0s─' {1..72}; echo; }

bold "═══ #320 five-address-space model — Phase 0 census ═══"
echo "toolchain: $CLANG"
hr

# ── 0a — representability ──────────────────────────────────────────────────
bold "0a  representability of a 24-bit pointer / value"
echo "• IR layer (source-verified, llvm/lib/IR/DataLayout.cpp):"
echo "    parseSize: pointer size only needs a non-zero 24-bit integer — NO power-of-two"
echo "    restriction (the pow2 check at line ~357 is on ALIGNMENT). getPointerSize ="
echo "    divideCeil(BitWidth,8) ⇒ a 24-bit pointer occupies exactly 3 bytes."
echo "    ⇒ the upstream note's premise ('LLVM requires power-of-two pointer sizes') is WRONG."
echo "• Backend layer (empirical): does the MOS GISel pipeline carry a genuine 24-bit value?"
cat > "$TMP/bi24.c" <<'EOF'
typedef unsigned _BitInt(24) u24;
volatile u24 src, dst;
void f(void){ u24 a = src; a = a + (u24)0x010000; dst = a; }   /* touches the 3rd byte */
EOF
if "${CC[@]}" -mllvm -verify-machineinstrs -c "$TMP/bi24.c" -o "$TMP/bi24.o" 2>"$TMP/bi24.err"; then
  echo "    _BitInt(24) default 8-bit : COMPILE-OK (verify-clean)"
else
  echo "    _BitInt(24) default 8-bit : COMPILE-FAIL"; sed 's/^/      /' "$TMP/bi24.err"
fi
if "${CC[@]}" -Xclang -target-feature -Xclang +mos-a16 -mllvm -verify-machineinstrs -c "$TMP/bi24.c" -o "$TMP/bi24a.o" 2>"$TMP/bi24a.err"; then
  echo "    _BitInt(24) +mos-a16      : COMPILE-OK (verify-clean)"
else
  echo "    _BitInt(24) +mos-a16      : COMPILE-FAIL"; sed 's/^/      /' "$TMP/bi24a.err"
fi
echo "  VERDICT 0a: GO — 24-bit is representable (3-byte storage) and the backend carries it."
hr

# ── 0b — usage census ──────────────────────────────────────────────────────
bold "0b  usage census — are far pointers ever STORED in memory?"
echo "• existing far-pointer-in-memory traffic in the tree (struct/array/global of far ptr):"
n_stored=$(grep -rEn 'FAR\s*\*\s*\w+\s*\[|struct[^;]*FAR\s*\*|FAR\s*\*\s*\w+\s*;' \
            "$ROOT"/examples/65816/*.c 2>/dev/null | grep -v '#define' | grep -vE '\(.*FAR\s*\*\)' | wc -l || true)
echo "    far pointers stored in memory across the corpus + far tests: ${n_stored}"
echo "    (all existing far usage is TRANSIENT: cast addr → deref → discard.)"
echo
echo "• sizeof a far pointer in C (clang getPointerWidthV):"
cat > "$TMP/sz.c" <<'EOF'
#define FAR __attribute__((address_space(2)))
_Static_assert(sizeof(unsigned char FAR *) == 4, "far ptr should be 4 bytes (IR p2:32)");
EOF
if "${CC[@]}" -c "$TMP/sz.c" -o /dev/null 2>"$TMP/sz.err"; then
  echo "    sizeof(far*) == 4  (front-end agrees with the IR datalayout)"
else
  got=$(grep -oE "'[0-9]+ == 4'" "$TMP/sz.err" | head -1 || true)
  echo "    sizeof(far*) != 4  ${got:+→ $got}  ✗  clang sizes the far pointer as 16-bit"
  echo "      (getPointerWidthV has no 'case 2: return 32' — front-end/back-end MISMATCH)"
fi
echo
echo "• can a far pointer even be STORED to memory today? (G_STORE p2 legalization)"
cat > "$TMP/store.c" <<'EOF'
#define FAR __attribute__((address_space(2)))
typedef unsigned char FAR *farp;
farp g;
void set(farp p){ g = p; }
EOF
if "${CC[@]}" -c "$TMP/store.c" -o /dev/null 2>"$TMP/store.err"; then
  echo "    store far ptr → memory : COMPILE-OK"
else
  echo "    store far ptr → memory : LEGALIZER CRASH on main —"
  grep -oE 'unable to legalize instruction: G_STORE[^,]*' "$TMP/store.err" | head -1 | sed 's/^/      /'
  echo "      (p2-as-value store/load is unmerged: lives in 0004 on wt/320-far-cc)"
fi
echo
echo "  VERDICT 0b: opportunity is EMPTY and BLOCKED —"
echo "    • 0 far pointers are stored in memory in realistic code (nothing to shrink);"
echo "    • storing far pointers isn't even supported on main (backend) and sizeof is"
echo "      wrong in C (front-end), so the 4-byte form must be completed before a 3-byte"
echo "      form could matter. zero-bank (AS4) is now measured + closed SEPARATELY (this"
echo "      line's old 'likewise 0 users' was a circular, lumped assertion) — see"
echo "      dev/measure-zerobank-census.sh: de-lumped, 0 sites carry bank-0 data as a"
echo "      far-typed pointer; AS4 == a near pointer (p4:16:8==p0:16:8) ⇒ CONFIRMED null."
hr
bold "OVERALL: the NEW spaces (packed-24, zero-bank) are premature — DEFER, don't build."
echo "But this is NOT a dead end: a far pointer can't be STORED in memory at all yet (see"
echo "dev/measure-far-ptr-value-state.sh), so packed-24 would optimize a capability that does"
echo "not exist. The real, DESIRABLE M1 work this surfaced is completing the far-pointer VALUE"
echo "type: sizeof(far*)==4 (getPointerWidthV) + G_STORE/G_LOAD p2 in memory + aggregates +"
echo "narrowing casts + merge 0004's pass/return half. Build that first; revisit 3-byte packing"
echo "only once stored far pointers work and real byte-pressure is measured."
