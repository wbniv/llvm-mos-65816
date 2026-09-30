#!/usr/bin/env bash
# Object bytes (.text+.data+.rodata) of one llc over a set of IR files.
#
# usage: llc-sizes.sh LLC OUT.tsv LIST [LLC_FLAGS...]
#   LLC      llc binary
#   OUT.tsv  receives "ir-path<TAB>bytes" per input ("fail" when llc fails)
#   LIST     file of IR paths, one per line; an optional second column
#            (TAB-separated) gives the llc -O level for that input (default 2)
# Runs JOBS (default 4) llc at a time, each under ulimit -c 0, ulimit -v 2000000 and
# timeout 300. llvm-size comes from build/llvm-mos-install.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
LLC=$(realpath "$1"); OUT=$2; LIST=$3; shift 3
SIZE=/home/will/llvm-mos-65816/build/llvm-mos-install/bin/llvm-size
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
export LLC SIZE W
one() {
  ir=$1; lvl=${2:-2}; shift 2 || shift $#
  o=$W/$(echo "$ir" | md5sum | cut -c1-16).o
  if ( ulimit -c 0; ulimit -v 2000000; timeout 300 "$LLC" -O"$lvl" "$@" -filetype=obj "$ir" -o "$o" 2>/dev/null ); then
    printf '%s\t%s\n' "$ir" "$("$SIZE" -A "$o" | awk '/^\.text|^\.data|^\.rodata/ {s+=$2} END {print s+0}')"
  else
    printf '%s\tfail\n' "$ir"
  fi
  rm -f "$o"
}
export -f one
awk -F'\t' '{print $1 "\t" ($2==""?2:$2)}' "$LIST" |
  xargs -P"${JOBS:-4}" -d '\n' -I{} bash -c 'IFS=$'"'"'\t'"'"' read -r a b <<<"{}"; one "$a" "$b" "$@"' _ "$@" |
  sort > "$OUT"
