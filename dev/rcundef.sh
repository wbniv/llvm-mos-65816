#!/usr/bin/env bash
# dev/rcundef.sh — positive MachineVerifier gate for undef register-lane handling.
# Every listed source must verify under both 16-bit feature modes at the optimization
# levels that exercise coalescing, identity-copy rewriting, and REP/SEP X reloads.
# The gate needs only the compiler and repository sources.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh rcundef  # positive undef-lane MachineVerifier gate"; exit 0;; esac
ROOT=/work; B="$ROOT/build"
TOOL="$B/llvm-mos-install/bin"
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain"; exit 1; }

declare -A OPTS=(
  ["$ROOT/examples/65816/rcundef.c"]="-O0 -O1 -Os"
  ["$ROOT/examples/65816/rcundef2.c"]="-O0 -O1 -O2 -O3 -Os -Oz"
  ["$ROOT/examples/snes/corpus/newton_sim.c"]="-O0 -O1 -O2 -O3 -Os -Oz"
  ["$ROOT/examples/snes/corpus/trimerge_sim.c"]="-O1 -Os"
)
rc=0
for src in "$ROOT/examples/65816/rcundef.c" \
           "$ROOT/examples/65816/rcundef2.c" \
           "$ROOT/examples/snes/corpus/newton_sim.c" \
           "$ROOT/examples/snes/corpus/trimerge_sim.c"; do
  [ -f "$src" ] || { echo "    FAIL (missing) $(basename "$src")"; rc=1; continue; }
  for spec in "a16:-Xclang -target-feature -Xclang +mos-a16" \
              "xy16:-Xclang -target-feature -Xclang +mos-xy16"; do
    name="${spec%%:*}"; feat="${spec#*:}"
    for opt in ${OPTS[$src]}; do
      log=$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 $feat "$opt" \
              -mllvm -verify-machineinstrs -c "$src" -o /dev/null 2>&1) && ok=1 || ok=0
      if [ "$ok" = 1 ] && ! echo "$log" | grep -qi 'Bad machine code\|undefined physical register'; then
        echo "    $(basename "$src") $name $opt  -verify clean"
      else
        echo "    $(basename "$src") $name $opt  -verify FAIL"
        echo "$log" | sed -n '1,12s/^/        /p'
        rc=1
      fi
    done
  done
done
echo
[ "$rc" = 0 ] && echo "RESULT: PASS — all undef-lane witnesses verify clean under a16 + xy16" \
             || echo "RESULT: FAIL — an undef-lane MachineVerifier witness regressed"
exit $rc
