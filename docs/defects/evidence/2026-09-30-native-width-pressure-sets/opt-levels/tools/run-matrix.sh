#!/usr/bin/env bash
# Run the optimization-level size/hash matrix: one sizes-level.sh (or
# mode-hashes-level.sh) run per job line, at most JOBS at a time.
#
# usage: run-matrix.sh JOBFILE OUTDIR
#   JOBFILE  lines "KIND NAME LLC INPUTS OLEVEL LLCFLAGS MODES..." where KIND is
#            sizes or hashes, LLC is relative to /home/will/llvm-mos-65816,
#            INPUTS is a container path, LLCFLAGS is "-" for none.
#   OUTDIR   under /home/will/llvm-mos-65816; receives NAME.tsv and NAME.log
# Env: JOBS  parallel container runs (default 4; the OOM rule caps it at 4)
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
[ $# -eq 2 ] || { echo "need JOBFILE OUTDIR" >&2; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"
JOBFILE=$(realpath "$1"); OUT=$(realpath -m "$2"); mkdir -p "$OUT"
cd /home/will/llvm-mos-65816
run_one() {
  set -euo pipefail
  local kind=$1 name=$2 llc=$3 inputs=$4 ol=$5 fl=$6; shift 6
  [ "$fl" = - ] && fl=
  local tool=sizes-level.sh; [ "$kind" = hashes ] && tool=mode-hashes-level.sh
  local rc=0
  INPUTS=$inputs OLEVEL=$ol LLCFLAGS=$fl bash "$HERE/$tool" "$llc" "$OUT/$name.tsv" "$@" \
    > "$OUT/$name.log" 2>&1 || rc=$?
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $name rc=$rc" | tee -a "$OUT/$name.log"
}
export -f run_one; export HERE OUT
grep -v '^\s*#' "$JOBFILE" | grep -v '^\s*$' | xargs -P "${JOBS:-4}" -L 1 bash -c 'run_one "$@"' _
