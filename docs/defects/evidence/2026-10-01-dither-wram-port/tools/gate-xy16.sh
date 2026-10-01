#!/usr/bin/env bash
# gate-xy16.sh — build examples/snes/dither.c at -LEVEL with +mos-a16,+mos-xy16 (the SDK driver, as
# reproduce.sh gate does for default and a16) and run the bsnes-jg gate (corpus_result == 0x80C4).
set -euo pipefail
case "${1:-}" in -h|--help|"") echo "usage: gate-xy16.sh OUT LEVEL   (LEVEL: O2 or O3); exit status = jgxcheck's"; exit 0 ;; esac
OUT=$1; L=$2
ROOT=$(cd "$(dirname "$0")/../../../../.." && pwd)
TOOL=$ROOT/build/llvm-mos-install/bin; CFG=$ROOT/build/install/bin/mos-snes.cfg
D=$OUT/$L-xy16; mkdir -p "$D"; cd "$D"
set +e
( ulimit -c 0; ulimit -v 2000000; timeout 600 "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 \
    -Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16 -"$L" \
    -I "$ROOT/examples/65816" -I "$ROOT/examples/snes" -I "$ROOT/build" "$ROOT/examples/snes/dither.c" \
    -o rom.sfc -Wl,-Map=rom.map )
rc=$?
set -e
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) build rc=$rc clang-23 $(sha256sum "$TOOL/clang-23" | cut -c1-16)"
[ "$rc" -eq 0 ] || exit 3
off=0x$("$TOOL/llvm-objdump" -t rom.sfc.elf | awk '$NF=="corpus_result"{print $1; exit}' | sed 's/^0*//')
hs=$("$TOOL/llvm-objdump" -t rom.sfc.elf | awk '$NF=="__heap_start"{print $1; exit}')
echo "corpus_result $off  __heap_start 0x$hs  headroom to __stack: $(( 0x2000 - 0x$hs )) B"
set +e
( ulimit -c 0; timeout 300 "$ROOT/build/jgxcheck" rom.sfc "$ROOT/vendor/bsnes-jg/Database" "$off" 2 0x80C4 600 ) 2>&1 | grep -E 'SMOKE|error'
rc=${PIPESTATUS[0]}
set -e
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) gate rc=$rc"
exit "$rc"
