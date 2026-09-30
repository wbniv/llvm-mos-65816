#!/usr/bin/env bash
# Run llc-sizes.sh for every (configuration, level, mode) of a matrix.
#
# usage: size-matrix.sh OUTDIR IRROOT CONFIGS [LEVELS] [MODES]
#   OUTDIR   receives CONFIG.LEVEL.MODE.tsv
#   IRROOT   holds LEVEL/*.MODE.ll (gen-ir.sh output)
#   CONFIGS  file of "name|llc|flags" lines (# comments allowed)
#   LEVELS   default "Os Oz O2 O3" (O3 runs llc -O3, the rest llc -O2)
#   MODES    default "default a16 a16xy16"
# Mode flags come from the IR (clang emitted the target features).
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
OUT=$1; IR=$2; CONF=$3; LEVELS=${4:-Os Oz O2 O3}; MODES=${5:-default a16 a16xy16}
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"
L=$(mktemp); trap 'rm -f "$L"' EXIT
for lv in $LEVELS; do
  n=2; [ "$lv" = O3 ] && n=3
  for m in $MODES; do
    ls "$IR/$lv"/*."$m".ll | awk -v n=$n '{print $0 "\t" n}' > "$L"
    grep -v '^#' "$CONF" | grep -v '^$' | while IFS='|' read -r name llc flags; do
      t=$OUT/$name.$lv.$m.tsv
      [ -s "$t" ] && continue
      # shellcheck disable=SC2086
      "$HERE/llc-sizes.sh" "$llc" "$t" "$L" $flags
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $name $lv $m done"
    done
  done
done
