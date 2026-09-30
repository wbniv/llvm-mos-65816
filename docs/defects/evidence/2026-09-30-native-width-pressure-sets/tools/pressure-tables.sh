#!/usr/bin/env bash
# Extract MOS register pressure tables from llvm-tblgen -gen-register-info
# (the MOSGenRegisterInfoTargetDesc.inc part of its split output).
#
# usage: pressure-tables.sh TBLGEN SRCDIR OUT.txt
#   TBLGEN  llvm-tblgen under /home/will/llvm-mos-65816 (runs in the dev container)
#   SRCDIR  llvm-project checkout under /home/will/llvm-mos-65816 (MOS.td is read
#           from SRCDIR/llvm/lib/Target/MOS, includes from SRCDIR/llvm/include)
#   OUT     text file under /home/will/llvm-mos-65816 with PressureNameTable and
#           PressureLimitTable as emitted by TableGen; OUT.full holds the whole
#           pressure section (set count through getRegUnitPressureSets)
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
[ $# -eq 3 ] || { echo "need TBLGEN SRCDIR OUT" >&2; exit 2; }
ROOT=/home/will/llvm-mos-65816
TG=/work/$(realpath --relative-to=$ROOT "$1")
SRC=/work/$(realpath --relative-to=$ROOT "$2")
OUT=$(realpath -m "$3"); C_OUT=/work/${OUT#$ROOT/}
cd "$ROOT"
dev/container.sh -- sh -c '
set -eu; ulimit -c 0
TG=$1; SRC=$2; OUT=$3; T=$(mktemp -d)
"$TG" -gen-register-info -I "$SRC/llvm/lib/Target/MOS" -I "$SRC/llvm/include" -I "$SRC/llvm/lib/Target" \
  "$SRC/llvm/lib/Target/MOS/MOS.td" -o "$T/r.inc"
awk "/Get the number of dimensions of register pressure/ {p=1} /Register to minimal register class mapping/ {p=0} p" "$T/rTargetDesc.inc" > "$OUT.full"
awk "/PressureNameTable\\[\\] = \\{/,/^  \\};/" "$T/rTargetDesc.inc" > "$OUT"
awk "/PressureLimitTable\\[\\] = \\{/,/^  \\};/" "$T/rTargetDesc.inc" >> "$OUT"
rm -rf "$T"
' _ "$TG" "$SRC" "$C_OUT"
