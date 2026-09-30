#!/usr/bin/env bash
set -euo pipefail
usage() {
  cat <<'EOF'
usage: host-oracle.sh ROOT OUTDIR [NAME[:MACRO=VALUE] ...]

Host oracle for the o2-large runtime harnesses (harness/<name>_run.c, default: dither mvscrl
packrec). Builds each harness -- the unchanged demo translation unit plus harness_hook.h -- with
the host cc and prints "<spec> 0xNNNN", the fold the SNES build must write to corpus_result.
A spec's optional MACRO=VALUE (for example dither:DITHER_RUN_FRAMES=24) is passed as -D, as
runtime-clocks-large.py passes it to clang.

The host build maps SNES MMIO onto a 64 KiB host array (host_mmio.h, force-included; it defines
the SDK's _SNES_REG8/_SNES_REG16 before snes_mmio.h and sets HARNESS_HOST). Two snesgfx headers
and the SDK's snes_ppu_reset_blank() form MMIO pointers directly, "(volatile uint8_t *)(uintptr_t)X" (X a
parenthesised expression, a name or a p->member chain);
the tool copies examples/ and the SDK headers into OUTDIR and rewrites only that cast to
HARNESS_MMIO_PTR(X), which the shim maps onto the same array. Nothing else in the program changes. Register writes land in the
array and DMA does not run, which leaves WRAM exactly as on the console (the uploads only read it).

ROOT is the repository root (for examples/ and the installed SDK headers).
EOF
}
case "${1:-}" in -h|--help) usage; exit 0 ;; esac
[ $# -ge 2 ] || { usage >&2; exit 2; }
ROOT=$(cd "$1" && pwd); OUT=$2; shift 2
NAMES=("$@"); [ ${#NAMES[@]} -gt 0 ] || NAMES=(dither mvscrl packrec)
HERE=$(cd "$(dirname "$0")/.." && pwd)
SDKINC="$ROOT/build/install/mos-platform/snes/include"
[ -d "$SDKINC" ] || { echo "FATAL: no SDK headers at $SDKINC" >&2; exit 1; }

ulimit -c 0
mkdir -p "$OUT/src/examples"
rm -rf "$OUT/src/examples/snes" "$OUT/src/examples/65816" "$OUT/sdk"
cp -r "$ROOT/examples/snes" "$ROOT/examples/65816" "$OUT/src/examples/"
cp -r "$SDKINC" "$OUT/sdk"
grep -rl '(volatile uint8_t \*)(uintptr_t)' "$OUT/src/examples/snes/snesgfx" "$OUT/sdk" |
  xargs -r sed -i -e 's/(volatile uint8_t \*)(uintptr_t)(/HARNESS_MMIO_PTR(/g' \
    -e 's/(volatile uint8_t \*)(uintptr_t)\([A-Za-z_][A-Za-z0-9_]*\(->[A-Za-z_][A-Za-z0-9_]*\)*\)/HARNESS_MMIO_PTR(\1)/g'
left=$(grep -rn '(volatile uint8_t \*)(uintptr_t)' "$OUT/src/examples/snes/snesgfx" "$OUT/sdk" || true)
[ -z "$left" ] || { echo "FATAL: unrewritten MMIO casts:"; echo "$left"; exit 1; } >&2
cat > "$OUT/host_mmio.h" <<'EOF'
#define _SNES_MMIO_H_
#include <stdint.h>
#define HARNESS_HOST 1
volatile uint8_t harness_mmio[0x10000];
#define _SNES_REG8(addr)  (harness_mmio[(uint16_t)(addr)])
#define _SNES_REG16(addr) (*(volatile uint16_t *)&harness_mmio[(uint16_t)(addr)])
#define HARNESS_MMIO_PTR(addr) (&harness_mmio[(uint16_t)(addr)])
EOF
for spec in "${NAMES[@]}"; do
  n=${spec%%:*}; defs=()
  [ "$spec" = "$n" ] || defs=(-D "${spec#*:}")
  exe="$OUT/$(printf '%s' "$spec" | tr ':=' '__')"
  cc -O2 -std=gnu11 -w -include "$OUT/host_mmio.h" -I "$OUT/src" -I "$HERE/harness" \
     -isystem "$OUT/sdk" "${defs[@]}" "$HERE/harness/${n}_run.c" -o "$exe"
  rc=0; r=$(timeout 120 "$exe") || rc=$?
  [ "$rc" -eq 0 ] && [[ "$r" =~ ^0x[0-9A-F]{4}$ ]] || { echo "FATAL: $spec host run rc=$rc out='$r'" >&2; exit 1; }
  echo "$spec $r"
done
