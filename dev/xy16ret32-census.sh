#!/usr/bin/env bash
# dev/xy16ret32-census.sh — #321 xy16 calling-convention, B1 opportunity census for the
# "i32 return in A16:X16 under +mos-xy16" lever (the A/X-return note's "high word in X" intent).
#
# Measures the OPPORTUNITY before building any backend change (the frame-ABI census method:
# the census IS the measurement). Per the resolved CC decisions, return placement is emergent
# from CC_MOS byte-splitting: an i32 return today goes A:X (low word) + RC2:RC3 (high word).
# The lever would instead ride A16 (low word) : X16 (high word), saving the RC2:RC3 high-word
# stores/loads — but it requires the return boundary to stay M=16/X=16 (a typed hole in the
# REP/SEP pass's "8-bit at every boundary" correctness invariant: requiredWidth/requiredXWidth
# isReturn -> MW_M8/XW_X8) plus a coordinated CC_MOS/RetCC + lowerReturn/lowerCall change. So
# it is only worth building if realistic code actually RETURNS i32 across calls.
#
# This counts, per group, on per-TU `-Os -emit-llvm -S` IR (int is 16-bit on this target, so
# i32 == long / int32_t / unsigned long):
#   N_i32ret      = function definitions returning i32   (^define ... i32 @)
#   N_i32callsite = call/invoke sites returning i32      (the places the lever would fire)
#
# Two groups: REALISTIC (corpus + kernels) is the VERDICT; C-TORTURE (the in-scope execute
# set) is where `long`-heavy arithmetic would surface any opportunity at all. Short-circuit:
# N_i32callsite == 0 on REALISTIC ⇒ shelve the lever (record the NULL), exactly as the
# frame-ABI A0 census (0/13) short-circuited the DP-window build.
#
# Host-side (no Docker). Drive directly: dev/xy16ret32-census.sh
# Plan: docs/plans/2026-06-18-321-m2-xy16-calling-convention-verify-formalize-me.md (Phase B1).
set -euo pipefail

if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
  echo "Usage: dev/xy16ret32-census.sh   # count i32-returning fns + i32 call sites (corpus+kernels [verdict] + c-torture)"
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$ROOT/build/llvm-mos-install/bin"
CLANG="${CLANG:-$T/mos-clang}"
[ -x "$CLANG" ] || { echo "FATAL: no from-source toolchain at $CLANG (run: dev/run.sh toolchain)" >&2; exit 1; }
XY16=(-Xclang -target-feature -Xclang +mos-xy16)

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Emit per-TU -Os IR and count i32 return defs + i32 call sites. Pointers are opaque `ptr` in
# modern LLVM IR, so a bare `i32` return/result is genuinely a 32-bit integer, not a pointer.
count_file() {  # $1 = src ; prints "<ndef> <ncall>" (0 0 on compile failure)
  local ir
  ir="$("$CLANG" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -emit-llvm -S -o - "$1" 2>/dev/null || true)"
  [ -n "$ir" ] || { echo "0 0"; return; }
  local d c
  d=$(printf '%s\n' "$ir" | grep -cE '^define[^@]* i32 @' || true)
  c=$(printf '%s\n' "$ir" | grep -cE '(call|invoke) i32 [@%]' || true)
  echo "$d $c"
}

REAL_DEF=0; REAL_CALL=0
echo "== REALISTIC (corpus + kernels) — the verdict =="
printf '%-28s %10s %12s\n' "file" "N_i32ret" "N_i32callsite"
printf '%.0s-' $(seq 1 54); echo
for src in "$ROOT"/examples/snes/corpus/*.c "$ROOT"/examples/65816/k_*.c; do
  [ -f "$src" ] || continue
  read -r d c < <(count_file "$src")
  REAL_DEF=$((REAL_DEF + d)); REAL_CALL=$((REAL_CALL + c))
  [ "$d" -gt 0 ] || [ "$c" -gt 0 ] && printf '%-28s %10s %12s\n' "$(basename "$src")" "$d" "$c"
done
printf '%.0s-' $(seq 1 54); echo
echo "  REALISTIC totals: N_i32ret=$REAL_DEF  N_i32callsite=$REAL_CALL"
echo

# C-TORTURE: the in-scope execute set (long-heavy arithmetic — where i32 returns appear if
# anywhere). Aggregate; list only files that actually carry an i32 return or i32 call site.
TORT_DEF=0; TORT_CALL=0; TORT_FILES=0; TORT_HIT=0
INSCOPE="$ROOT/examples/65816/torture/inscope.tsv"
SRCDIR="$ROOT/vendor/c-torture/execute"
echo "== C-TORTURE (in-scope execute set) — opportunity scan =="
if [ -f "$INSCOPE" ] && [ -d "$SRCDIR" ]; then
  while IFS= read -r name; do
    case "$name" in ''|\#*) continue;; esac
    src="$SRCDIR/$name"
    [ -f "$src" ] || continue
    TORT_FILES=$((TORT_FILES + 1))
    read -r d c < <(count_file "$src")
    TORT_DEF=$((TORT_DEF + d)); TORT_CALL=$((TORT_CALL + c))
    if [ "$d" -gt 0 ] || [ "$c" -gt 0 ]; then
      TORT_HIT=$((TORT_HIT + 1))
      printf '  %-26s N_i32ret=%-4s N_i32callsite=%s\n' "$name" "$d" "$c"
    fi
  done < "$INSCOPE"
  echo "  ----"
  echo "  C-TORTURE totals over $TORT_FILES files: N_i32ret=$TORT_DEF  N_i32callsite=$TORT_CALL  ($TORT_HIT files carry any i32 return/call)"
else
  echo "  SKIP — c-torture not fetched (vendor/c-torture) or no inscope.tsv (run dev/fetch-torture.sh + tools/torture_filter.py)"
fi
echo

echo "=============================================================================="
echo "VERDICT: REALISTIC N_i32callsite=$REAL_CALL ; C-TORTURE N_i32callsite=$TORT_CALL"
if [ "$REAL_CALL" -eq 0 ]; then
  cat <<TXT
  NULL on realistic code — no corpus/kernel function returns i32 across a call, so the
  i32-return-in-A16:X16 lever would optimize traffic that does not exist (the same 0/realistic
  signature as the frame-ABI A0 census, same root cause: llvm-mos keeps wide values
  register-resident and consumes wide arithmetic inline, not across return boundaries). The
  lever costs an ABI-wide change (a typed hole in the REP/SEP "8-bit at every boundary"
  correctness invariant + coordinated CC_MOS/RetCC + lowerReturn/lowerCall) for, at most, the
  C-TORTURE-only opportunity above. SHELVE with evidence; do not build the backend change.
TXT
fi
