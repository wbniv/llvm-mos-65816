#!/usr/bin/env bash
# dev/measure-compare-surface.sh — Phase 0 audit for the native s16 comparison
# follow-ups plan (docs/plans/2026-06-21-321-native-s16-comparison-followups.md).
#
# Emits the full predicate × operand-shape × {value,branch} matrix of 16-bit
# comparisons, compiles each +mos-a16 -Os (host-side, no emulator), and classifies
# every function:
#   NATIVE   = uses the 16-bit `rep; lda; cmp` path (no `cpx`)
#   BYTEWISE = falls to the 8-bit `cpx; cmp` chain
#   DIAMOND  = the result-as-VALUE was materialised with a bcc/bcs select-diamond
#   BRANCHLS = materialised with an adc/rol carry-tail (the §3 candidate target)
#
# Read-only: writes only to a tempdir; touches no vendor/ or build/ state. Override
# the toolchain to run from a feature worktree:
#   CLANG=.../mos-clang OBJDUMP=.../llvm-objdump dev/measure-compare-surface.sh
set -euo pipefail

usage() { echo "Usage: dev/measure-compare-surface.sh   # audit the +mos-a16 16-bit compare surface (native vs byte-wise)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLANG="${CLANG:-$ROOT/build/llvm-mos-install/bin/mos-clang}"
OBJDUMP="${OBJDUMP:-$ROOT/build/llvm-mos-install/bin/llvm-objdump}"
[ -x "$CLANG" ] || { echo "FATAL: no toolchain at $CLANG (run: dev/run.sh toolchain, or set CLANG=)"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SRC="$TMP/cmpsurface.c"

# Predicate specs: suffix | C-operator | operand C-type (signed vs unsigned)
PREDS=(
  "eq|==|uint16_t"  "ne|!=|uint16_t"
  "ult|<|uint16_t"  "ule|<=|uint16_t"  "ugt|>|uint16_t"  "uge|>=|uint16_t"
  "slt|<|int16_t"   "sle|<=|int16_t"   "sgt|>|int16_t"    "sge|>=|int16_t"
)

{
  echo '#include <stdint.h>'
  echo 'volatile uint16_t g1=0x1111,g2=0x2222; volatile uint16_t res; volatile uint16_t sink;'
  for spec in "${PREDS[@]}"; do
    IFS='|' read -r sfx op ty <<<"$spec"
    uty="uint16_t"; [ "$ty" = int16_t ] && uty="uint16_t"
    K="0x1234"; [ "$ty" = int16_t ] && K="0x1234"
    # value form, operand shapes: RR (both reg/param), RI (reg vs imm),
    #   MM (mem vs mem), RM (reg vs mem), CMP (computed LHS vs imm)
    echo "$uty ${sfx}_rr_v($ty x,$ty y){ return (x $op y); }"
    echo "$uty ${sfx}_ri_v($ty x){ return (x $op ($ty)$K); }"
    echo "void  ${sfx}_mm_v(void){ res = (($ty)g1 $op ($ty)g2); }"
    echo "$uty ${sfx}_rm_v($ty x){ return (x $op ($ty)g1); }"
    echo "$uty ${sfx}_cmp_v($ty x,$ty y){ return (($ty)(x+y) $op ($ty)$K); }"
    # branch form (contrast: the fused-terminator path)
    echo "$uty ${sfx}_rr_b($ty x,$ty y){ if (x $op y) return 7; return sink; }"
    echo "$uty ${sfx}_ri_b($ty x){ if (x $op ($ty)$K) return 7; return sink; }"
  done
} > "$SRC"

OBJ="$TMP/cmpsurface.o"
"$CLANG" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os -c -o "$OBJ" "$SRC"
DIS="$("$OBJDUMP" -d --mcpu=mosw65816 "$OBJ")"
SIZES="$("$OBJDUMP" --section-headers "$OBJ")"

classify() { # <fn>
  local fn="$1"
  local body; body="$(echo "$DIS" | awk "/<$fn>:/{f=1;next} /^[0-9a-f]+ <[A-Za-z]/{f=0} f")"
  [ -z "$body" ] && { echo "MISSING"; return; }
  local cls="NATIVE"
  echo "$body" | grep -qE '\bcpx\b|\bcpy\b' && cls="BYTEWISE"
  local mat=""
  if echo "$body" | grep -qE '\bbcc\b|\bbcs\b' && echo "$body" | grep -qE 'lda\s+#\$?0\b|ldx\s+#\$?0\b'; then mat="+DIAMOND"; fi
  if echo "$body" | grep -qE '\b(adc|rol)\b'; then mat="+BRANCHLS"; fi
  echo "$cls$mat"
}
bytes() { echo "$SIZES" | awk -v f=".text.$1" '$2==f{print strtonum("0x"$3)}'; }

printf "%-11s | %-22s | %-22s | %-22s | %-22s | %-22s | %-14s\n" "pred" "RR-value" "RI-value" "MM-value" "RM-value" "CMP-value" "RR/RI-branch"
echo "------------+------------------------+------------------------+------------------------+------------------------+------------------------+----------------"
for spec in "${PREDS[@]}"; do
  IFS='|' read -r sfx op ty <<<"$spec"
  printf "%-11s | %-13s %6s | %-13s %6s | %-13s %6s | %-13s %6s | %-13s %6s | %-6s %-6s\n" "$sfx ($op,$ty)" \
    "$(classify ${sfx}_rr_v)" "$(bytes ${sfx}_rr_v)B" \
    "$(classify ${sfx}_ri_v)" "$(bytes ${sfx}_ri_v)B" \
    "$(classify ${sfx}_mm_v)" "$(bytes ${sfx}_mm_v)B" \
    "$(classify ${sfx}_rm_v)" "$(bytes ${sfx}_rm_v)B" \
    "$(classify ${sfx}_cmp_v)" "$(bytes ${sfx}_cmp_v)B" \
    "$(classify ${sfx}_rr_b)" "$(classify ${sfx}_ri_b)"
done
echo ""
echo "Legend: NATIVE=rep/lda/cmp · BYTEWISE=cpx/cmp · +DIAMOND=bcc/bcs select-tail · +BRANCHLS=adc/rol carry-tail"
echo "Phase-0 expectation: only register-resident EQ value cells are BYTEWISE; every ordering value cell is NATIVE+DIAMOND (the §3 target)."
