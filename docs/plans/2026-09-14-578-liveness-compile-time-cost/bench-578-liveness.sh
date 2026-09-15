#!/usr/bin/env bash
# Runs INSIDE the privileged container. Measures retired user instructions and user CPU
# seconds for llc-prefix vs llc-postfix over the corpus IR, interleaved A/B.
# Layout (mounted at /b): /b/bench/llc-prefix, /b/bench/llc-postfix, /b/ir/*.ll
# Output: /b/bench/results.csv  (file,binary,rep,instructions,user_sec,rc)
set -euo pipefail
B=/b/bench
IR=/b/ir
OUT=$B/results.csv
N_CORPUS=${N_CORPUS:-3}
N_LARGE=${N_LARGE:-10}
LARGE="k_trig16x.a16 k_trig16x.a8 k_trig16.a16 k_trig16.a8 a16cmpaudit.a16 a16cmpaudit.a8"
echo "file,binary,rep,instructions,task_clock_ms,rc" > "$OUT"

measure() { # file binary rep
  local f="$1" bin="$2" rep="$3" tmp
  tmp=$(mktemp)
  local rc=0
  perf stat -e instructions:u,task-clock:u -x, -o "$tmp" -- "$B/llc-$bin" -mtriple=mos -mcpu=mosw65816 -O2 \
    -o /dev/null "$IR/$f.ll" >/dev/null 2>&1 || rc=$?
  local ins clk
  ins=$(awk -F, '/instructions:u/{print $1}' "$tmp")
  clk=$(awk -F, '/task-clock:u/{print $1}' "$tmp")   # msec on-CPU
  echo "$f,$bin,$rep,${ins:-NA},${clk:-NA},$rc" >> "$OUT"
  rm -f "$tmp"
}

files=()
for ll in "$IR"/*.ll; do files+=("$(basename "$ll" .ll)"); done
echo "corpus: ${#files[@]} files, N=$N_CORPUS each side, interleaved"
for rep in $(seq 1 "$N_CORPUS"); do
  for f in "${files[@]}"; do
    measure "$f" prefix "$rep"
    measure "$f" postfix "$rep"
  done
  echo "  rep $rep done"
done
echo "large inputs: N=$N_LARGE each side, interleaved"
for f in $LARGE; do
  for rep in $(seq 1 "$N_LARGE"); do
    measure "$f" prefix "L$rep"
    measure "$f" postfix "L$rep"
  done
  echo "  $f done"
done
echo "results: $OUT ($(wc -l < "$OUT") rows)"
