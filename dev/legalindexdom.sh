#!/usr/bin/env bash
# dev/legalindexdom.sh — regression gate for the MOS legalizer absolute-indexed-addressing
# domination fix (patch 0002, MOSLegalizerInfo::tryAbsoluteIndexedAddressing). Asserts the
# fold-while-walk repro compiles -verify-machineinstrs CLEAN in default-8-bit, +mos-a16 AND
# +mos-xy16 (it ABORTED with "Virtual register defs don't dominate all uses" before the fix).
# Host-side compile only (no emulator/SDK). Drive: dev/run.sh legalindexdom.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh legalindexdom   # -verify regression gate for the indexed-addr domination fix"; exit 0;; esac

ROOT=/work
TOOL="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/legalindexdom.c"
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }

rc=0
for spec in "default:" "+mos-a16:-Xclang -target-feature -Xclang +mos-a16" "+mos-xy16:-Xclang -target-feature -Xclang +mos-xy16"; do
  name="${spec%%:*}"; feat="${spec#*:}"
  out=$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 $feat -Os -mllvm -verify-machineinstrs \
        -c "$SRC" -o /dev/null 2>&1) && ok=1 || ok=0
  if [ "$ok" = 1 ] && ! printf '%s\n' "$out" | grep -qi "dominate"; then
    echo "    PASS  $name  (-verify clean)"
  else
    echo "    FAIL  $name  $(printf '%s\n' "$out" | grep -iE "dominate|Bad machine|Found" | head -1)"; rc=1
  fi
done

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — indexed-addr domination fix live; repro -verify clean in default/+mos-a16/+mos-xy16"
else
  echo "RESULT: FAIL — the legalizer domination regression is present (rebuild the toolchain with the fixed 0002)"
fi
exit $rc
