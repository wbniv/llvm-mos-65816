#!/usr/bin/env bash
# Replay the extracted regression's checks against one frozen toolset.
# usage: regression.sh TOOL_DIRECTORY TEST_FILE
# Each check prints its command and exit status; the script itself exits 0.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
tools=$1; test=$2
echo "llc sha256: $(sha256sum "$tools/llc" | cut -c1-64)"
echo "opt sha256: $(sha256sum "$tools/opt" | cut -c1-64)"
echo "test sha256: $(sha256sum "$test" | cut -c1-64)"
check() {
  local name=$1; shift
  echo "== $name"
  echo "COMMAND: $*"
  set +e
  local out rc
  out=$("$@" 2>&1); rc=$?
  { grep -m 4 -i -E 'error|unknown' <<<"$out" || true; } | cut -c1-200
  set -e
  echo "EXIT: $rc"
}
filecheck() { "$tools/FileCheck" "$test" "$@"; }
llc_to() { local prefix=$1; shift; "$tools/llc" -mtriple=mos "$@" < "$test" | filecheck --check-prefix="$prefix"; }
check "default indexed forms" llc_to CHECK -mcpu=mosw65816 -verify-machineinstrs
check "xy16 indexed forms" llc_to CHECK -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs
check "recovery disabled" llc_to DISABLED -mcpu=mosw65816 -mos-recover-near-nowrap=false -verify-machineinstrs
check "recovered IR flags" llc_to IR -mcpu=mosw65816 -stop-after=mos-near-nowrap-recovery
check "6502 exclusion" llc_to PLAIN -mcpu=mos6502 -stop-after=mos-near-nowrap-recovery
check "opt startup" "$tools/opt" -passes=verify -disable-output "$test"
