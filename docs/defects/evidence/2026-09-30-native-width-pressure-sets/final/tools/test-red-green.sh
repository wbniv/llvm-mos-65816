#!/usr/bin/env bash
# Run the two regression tests' RUN lines against several frozen llc binaries.
#
# usage: test-red-green.sh FILECHECK LLC...
#   FILECHECK  FileCheck binary; LLC  llc binaries (label = path)
# For each llc prints one line per RUN configuration: PASS or FAIL (the
# FileCheck exit status of `llc ... < test | FileCheck test --check-prefix=P`).
# Every llc runs under ulimit -c 0, ulimit -v 2000000 and timeout 120.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
FC=$1; shift
T="$(cd "$(dirname "$0")/../tests" && pwd)"
D=$T/native-width-default-pressure.ll; G=$T/native-width-pressure-opt-level.ll
sha256sum "$D" "$G"
one() { # LLC TEST PREFIX STDERR(0|1) ARGS... -> PASS/FAIL, as the test's RUN line
  local llc=$1 t=$2 p=$3 e=$4; shift 4
  if ( ulimit -c 0; ulimit -v 2000000
       if [ "$e" = 1 ]; then timeout 120 "$llc" "$@" < "$t" -o /dev/null 2>&1
       else timeout 120 "$llc" "$@" < "$t"; fi | timeout 120 "$FC" "$t" --check-prefix="$p" >/dev/null 2>&1 ); then
    echo PASS; else echo FAIL; fi
}
for L in "$@"; do
  echo "== $L $(sha256sum "$L" | cut -c1-16)"
  echo "  default mos6502   : $(one "$L" "$D" MOS6502 0 -mtriple=mos -mcpu=mos6502 -verify-machineinstrs)"
  echo "  default mosw65816 : $(one "$L" "$D" W65816 0 -mtriple=mos -mcpu=mosw65816 -verify-machineinstrs)"
  echo "  +mos-a16 -O2 sets : $(one "$L" "$G" SETS 1 -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -O2 -debug-only=machine-scheduler)"
  echo "  +mos-a16 -O3 none : $(one "$L" "$G" NOSETS 1 -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -O3 -debug-only=machine-scheduler)"
done
