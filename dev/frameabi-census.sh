#!/usr/bin/env bash
# dev/frameabi-census.sh — #321 frame-ABI study, A0 fail-fast eligibility census.
#
# Tests the A0 cost model empirically BEFORE building the (a) DP-window / (b)
# stack-relative codegen: does ANY function net a win from moving locals out of
# the soft static stack? Per function (+mos-a16 -Os), count from `llvm-objdump
# -dr` relocations:
#
#   Nspill = accesses to .noinit..Lstatic_stack  (spilled/frame locals — the WIN:
#            currently 4-byte long (R_MOS_ADDR24) -> 2-byte DP under a DP-window)
#   Nrc    = R_MOS_ADDR8 __rc* accesses          (imaginary registers — the TAX:
#            2-byte DP -> 3-byte abs, since D!=0 breaks DP __rc addressing)
#
# Generous-to-(a) byte model: gain = SAVE*Nspill - TAX*Nrc - OVERHEAD
#   SAVE=2 (4B long spill -> 2B DP), TAX=1 (2B DP -> 3B abs), OVERHEAD=8
#   (one-time tsc;sbc;tcs;phd;tcd ... pld prologue/epilogue). Profitable iff >0.
#
# Two groups: REALISTIC (corpus + kernels) and SYNTHETIC STRESS (frameabi_heavy.c,
# shapes built to maximize spill / minimize __rc). The realistic group is the
# verdict; the stress group maps the (narrow, atypical) winning boundary.
#
# Host-side (no Docker). Drive directly: dev/frameabi-census.sh
# docs/plans/2026-06-20-321-frame-abi-build-all-three-and-measure.md (A0).
set -euo pipefail

if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
  echo "Usage: dev/frameabi-census.sh   # per-function DP-window profitability census (corpus+kernels + synthetic stress)"
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$ROOT/build/llvm-mos-install/bin"
CLANG="${CLANG:-$T/mos-clang}"
OBJDUMP="${OBJDUMP:-$T/llvm-objdump}"
[ -x "$CLANG" ] || { echo "FATAL: no from-source toolchain at $CLANG (run: dev/run.sh toolchain)" >&2; exit 1; }
A16=(-Xclang -target-feature -Xclang +mos-a16)
SAVE=2; TAX=1; OVERHEAD=8

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
GROUP_PROFIT=0; GROUP_TOTAL=0

census_group() {  # $1 = label; $2.. = source files
  local label="$1"; shift
  GROUP_PROFIT=0; GROUP_TOTAL=0
  echo "== $label =="
  printf '%-22s %7s %5s %7s  %s\n' "function" "Nspill" "Nrc" "gain" "verdict (gain=${SAVE}*spill-${TAX}*rc-${OVERHEAD})"
  printf '%.0s-' $(seq 1 78); echo
  local src name out fn s r g v
  for src in "$@"; do
    [ -f "$src" ] || continue
    name="$(basename "$src")"
    if ! "$CLANG" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$tmp/c.o" "$src" 2>/dev/null; then
      printf '%-22s %7s %5s %7s  %s\n' "$name" "-" "-" "-" "COMPILE-FAIL (xfail: regalloc-out-of-registers)"
      continue
    fi
    out="$("$OBJDUMP" -dr --mcpu=mosw65816 "$tmp/c.o" | awk -v pfx="$name:" '
      /^[0-9a-f]+ <.*>:/ { fn=$0; sub(/^[0-9a-f]+ </,"",fn); sub(/>:$/,"",fn); seen[fn]=1; next }
      /R_MOS_ADDR8[[:space:]]+__rc/ { rc[fn]++; next }
      /static_stack/                { sp[fn]++; next }
      END { for (f in seen) printf "%s\t%d\t%d\n", pfx f, sp[f]+0, rc[f]+0 }' | sort)"
    while IFS=$'\t' read -r fn s r; do
      [ -n "$fn" ] || continue
      g=$(( SAVE*s - TAX*r - OVERHEAD ))
      GROUP_TOTAL=$((GROUP_TOTAL+1))
      if [ "$g" -gt 0 ]; then v="PROFITABLE ***"; GROUP_PROFIT=$((GROUP_PROFIT+1)); else v="loses"; fi
      printf '%-22s %7s %5s %7s  %s\n' "$fn" "$s" "$r" "$g" "$v"
    done <<< "$out"
  done
  printf '%.0s-' $(seq 1 78); echo
  echo "  $label: $GROUP_PROFIT / $GROUP_TOTAL profitable"
  echo
}

census_group "REALISTIC (corpus + kernels) — the verdict" \
  "$ROOT"/examples/snes/corpus/*.c "$ROOT"/examples/65816/k_*.c
real_profit=$GROUP_PROFIT; real_total=$GROUP_TOTAL

census_group "SYNTHETIC STRESS (frameabi_heavy.c) — winning-boundary map" \
  "$ROOT/examples/65816/frameabi_heavy.c"

echo "=============================================================================="
echo "VERDICT: realistic code $real_profit / $real_total profitable."
if [ "$real_profit" -eq 0 ]; then
  cat <<'TXT'
  NULL — no realistic function nets a win. Locals are register-resident in __rc
  (Nspill~0; local arrays/buffers go through a pointer in __rc, not the static
  stack), so there is essentially no frame/spill traffic for ANY frame ABI to
  optimize. The soft static stack wins by default. Only the SYNTHETIC stress
  shapes profit — volatile locals / constant-index array shuffles with minimal
  arithmetic — a pattern realistic compute does not produce.
TXT
fi
