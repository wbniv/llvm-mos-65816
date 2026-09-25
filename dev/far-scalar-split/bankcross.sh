#!/usr/bin/env bash
# dev/far-scalar-split/bankcross.sh -- bank-seam semantics of a single M=0 16-bit far access.
#
# Builds dev/far-scalar-split/bankcross.c (hand-written 65816 in inline asm; see its header) and runs
# it on bsnes-jg (host, build/jgxcheck) and MAME (dev/container.sh). PASS = every M=0 form
# (lda/sta long, lda [dp], lda/sta [dp],y) at $7EFFFF carries its second byte into $7F0000, i.e.
# behaves exactly like today's byte-split `af A` / `af A+1` (whose A+1 the linker computes as a
# 24-bit sum). Referenced by docs/investigations/2026-09-25-far-scalar-split-measurement.md §5.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: dev/far-scalar-split/bankcross.sh [-h|--help]

Env: ROOT (repo root), BUILD (default $ROOT/build), NO_MAME=1 skips the MAME leg.
EOF
  exit 0
}
case "${1:-}" in -h|--help) usage ;; esac

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BUILD="${BUILD:-$ROOT/build}"
TOOL="$BUILD/llvm-mos-install/bin"
OUT="$BUILD/far-scalar-split"; mkdir -p "$OUT"
ROM="$OUT/bankcross.sfc"; MAP="$OUT/bankcross.map"

"$TOOL/mos-clang" --config "$BUILD/install/bin/mos-snes.cfg" -mcpu=mosw65816 -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$ROOT/dev/far-scalar-split/bankcross.c"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null

# symbol -> expected (carry-into-next-bank semantics); see bankcross.c header for the decoding.
CHECKS=("res_a 0x5AA55AA5" "res_b 0xC3125AA5" "res_c 0x5AA5C367")
rc=0
echo "==> bsnes-jg (host)"
for c in "${CHECKS[@]}"; do
  set -- $c
  off=$(awk -v s="$1" '$NF==s {print $1; exit}' "$MAP")
  "$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$off" 4 "$2" 60 2>&1 | grep SMOKE || rc=1
done

if [ "${NO_MAME:-}" = "1" ]; then
  echo "==> MAME: SKIP (NO_MAME=1)"
else
  echo "==> MAME (container)"
  rel="${ROM#"$ROOT"/}"; relmap="${MAP#"$ROOT"/}"
  "$ROOT/dev/container.sh" -- bash -c 'set -euo pipefail
    source /work/dev/_emu.sh; require_bios
    r=0
    for c in "res_a 0x5AA55AA5" "res_b 0xC3125AA5" "res_c 0x5AA5C367"; do
      set -- $c; run_assert "/work/'"$rel"'" "/work/'"$relmap"'" "$1" "$2" || r=1
    done
    exit $r' || rc=1
fi
[ $rc -eq 0 ] && echo "RESULT: PASS -- M=0 far 16-bit accesses carry into the next bank (== byte-split)" \
             || echo "RESULT: FAIL"
exit $rc
