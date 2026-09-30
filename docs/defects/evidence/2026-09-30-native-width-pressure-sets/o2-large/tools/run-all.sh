#!/usr/bin/env bash
set -euo pipefail
usage() {
  cat <<'EOF'
usage: run-all.sh OUTDIR

Runs the o2-large measurement from the main checkout (/home/will/llvm-mos-65816), with this
worktree's harness mounted at /wt:
  1. host-oracle.sh for every spec -> OUTDIR/oracle.txt (the expected corpus_result values);
  2. runtime-clocks-large.py --lto (all three harnesses, the SDK's LTO ROM build) -> OUTDIR/lto;
  3. runtime-clocks-large.py without --lto (the frozen non-LTO method; mvscrl and packrec only,
     since dither's non-LTO object overflows low WRAM) -> OUTDIR/nolto.
Levels O2 and O3; modes +mos-a16 and +mos-a16,+mos-xy16; at most 3 parallel jobs. Variants:
  head  = unchanged 321-16                      (build/pressure-sets/llc/321-16)
  t4    = the ungated design                    (build/pressure-sets/t4/llc/321-16-t4)
  final = final split #321-16 (da1a6f4b...)     (build/pressure-sets/final/llc/321-16)
          ungated at -O2, sets off at -O3
  memb1 = appended sets off (T4 head-probe, -mos-native-pressure-probe=1)
Each spec runs at two lengths so the steady-state loop cost is the difference.
OUTDIR must live under build/ of the main checkout.
EOF
}
case "${1:-}" in -h|--help|"") usage; exit 0 ;; esac
ROOT=/home/will/llvm-mos-65816
WT=$(cd "$(dirname "$0")/../../../../../.." && pwd)
OUT=$(realpath -m "$1")
case "$OUT" in $ROOT/build/*) ;; *) echo "OUTDIR must live under $ROOT/build" >&2; exit 2 ;; esac
REL=${OUT#$ROOT/}
EV=docs/defects/evidence/2026-09-30-native-width-pressure-sets/o2-large
ulimit -c 0
mkdir -p "$OUT"
SPECS_ALL=(dither:DITHER_RUN_FRAMES=6 dither:DITHER_RUN_FRAMES=12
           mvscrl:MVSCRL_RUN_STEPS=32 mvscrl:MVSCRL_RUN_STEPS=128
           packrec:PACKREC_RUN_FRAMES=240 packrec:PACKREC_RUN_FRAMES=960)
SPECS_NOLTO=("${SPECS_ALL[@]:2}")
"$WT/$EV/tools/host-oracle.sh" "$ROOT" "$OUT/host" "${SPECS_ALL[@]}" > "$OUT/oracle.txt"
cat "$OUT/oracle.txt"
VARIANTS=(--variant head=build/pressure-sets/llc/321-16
          --variant t4=build/pressure-sets/t4/llc/321-16-t4
          --variant final=build/pressure-sets/final/llc/321-16
          --variant memb1=build/pressure-sets/t4/llc/head-probe:-mos-native-pressure-probe=1)
run() {
  local dir=$1; shift
  local specs=() s
  for s in "$@"; do [ "$s" = --lto ] || specs+=(--spec "$s"); done
  cd "$ROOT"
  timeout 14400 dev/container.sh -v "$WT:/wt" -- python3 "/wt/$EV/tools/runtime-clocks-large.py" \
    "/work/$REL/$dir" --harness "/wt/$EV/harness" --oracle "/work/$REL/oracle.txt" \
    --level O2 --level O3 --modes a16,a16xy16 "${VARIANTS[@]}" "${specs[@]}" --jobs 3 \
    $([ "${*: -1}" = --lto ] && echo --lto)
}
run lto "${SPECS_ALL[@]}" --lto > "$OUT/lto.log" 2>&1
run nolto "${SPECS_NOLTO[@]}" > "$OUT/nolto.log" 2>&1
echo "done: $OUT"
