#!/usr/bin/env bash
# Red/green matrix for the tests the fourth-round series adds or changes.
#
# usage: r4-red-green.sh OUT.tsv
# For each (test, owning commit) the test file is taken from the owning commit's
# tree (probe-r3/<label>__<test>) and run with run-test-with.py against the
# parent commit's llc (red), an unrepaired llc where one applies (red), and the
# owning and every later third-round llc (green). Rows of kind "char" are
# characterization tests, expected to pass on the parent as well.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
S=$ROOT/build/split-320-321
OUT=$(realpath -m "$1")
P=$S/probe-r4; rm -rf "$P"; mkdir -p "$P"
declare -A C; while read -r l c; do C[$l]=$c; done < "$S/evidence/r4-stages.list"
ORDER="r4-320-1a1 r4-320-1a2 r4-320-1a3 r4-320-1b r4-320-1c r4-320-1d r4-320-2 r4-320-3 r4-320-4 r4-fw-9 r4-fw-5 r4-fw-6 r4-fw-7 r4-fw-8 r4-fw-11 r4-fw-12 r4-fw-13 r4-fw-14"
# test path | owner | parent | unrepaired | kind
SPEC="
CodeGen/MOS/imag32-reserved-pairs.ll|r4-320-1b|r4-320-1a3||reg
CodeGen/MOS/imag32-allocation-gate.mir|r4-320-1c|r4-320-1b||reg
CodeGen/MOS/far-ptr-arg-exhaustion.ll|r4-320-1c|r4-320-1b|c-320-01|reg
CodeGen/MOS/prologepilog.mir|r4-320-1d|r4-320-1c||reg
CodeGen/MOS/far-ptr-arg-exhaustion.ll|r4-320-2|r4-320-1d|c-320-02|reg
CodeGen/MOS/far-quad-spill-call.ll|r4-320-2|r4-320-1d|c-320-02|reg
CodeGen/MOS/far-access-non-65816.ll|r4-320-2|r4-320-1d|r2-320-2|reg
CodeGen/MOS/far-fold-debug.ll|r4-320-2|r4-320-1d|c-320-02|reg
CodeGen/MOS/far-ptr-trunc.ll|r4-320-2|r4-320-1d|p-320-02|reg
CodeGen/MOS/far-memop-length.ll|r4-320-3|r4-320-2|p-320-03|reg
CodeGen/MOS/far-fold-debug.ll|r4-320-4|r4-320-3|r2-320-4|reg
CodeGen/MOS/far-index-fold-debug.ll|r4-320-4|r4-320-3|p-320-04|reg
CodeGen/MOS/native-index-copy-cost.mir|r4-fw-9|r4-320-4||reg
CodeGen/MOS/native-copy-unlowered.mir|r4-fw-9|r4-320-4|r2-fw-9|reg
CodeGen/MOS/far-global-long-x.ll|r4-fw-5|r4-fw-9||reg
CodeGen/MOS/far-fold-debug.ll|r4-fw-5|r4-fw-9|c-fw-14|reg
CodeGen/MOS/far-loop-range.mir|r4-fw-8|r4-fw-7||reg
CodeGen/X86/virtregrewriter-x86-undef-high-byte-result.mir|r4-fw-11|r4-fw-8||reg
CodeGen/X86/virtregrewriter-x86-copy-contracts.mir|r4-fw-11|r4-fw-8||char
CodeGen/MOS/far-word-policy.mir|r4-fw-12|r4-fw-11|r2-fw-14|reg
CodeGen/MOS/far-index-fold-debug.ll|r4-fw-12|r4-fw-11|fw-old|reg
CodeGen/MOS/far-word-policy.mir|r4-fw-13|r4-fw-12||char
CodeGen/MOS/far-word-index-boundaries.mir|r4-fw-13|r4-fw-12||char
CodeGen/MOS/far-loop-range-boundaries.mir|r4-fw-13|r4-fw-12||char
CodeGen/MOS/far-word-rep-sep.mir|r4-fw-13|r4-fw-12||char
CodeGen/MOS/far-word-index-integration.ll|r4-fw-13|r4-fw-12||char
CodeGen/MOS/far-word-index-boundaries.mir|r4-fw-14|r4-fw-13||char
"
echo "$SPEC" | while IFS='|' read -r t own par unr kind; do
  [ -n "$t" ] || continue
  git -C "$S/source" show "${C[$own]}:llvm/test/$t" > "$P/${own}__$(basename "$t")"
done
cd "$ROOT"
dev/container.sh -- bash -c '
set -uo pipefail
S=/work/build/split-320-321; P=$S/probe-r4; L=$S/llc; OUT=$1; ORDER=$2; SPEC=$3
row() { # file test version role label kind
  local llc=$L/$5 h r
  h=$(sha256sum "$llc" | cut -c1-16)
  r=$(python3 $S/spec/run-test-with.py "$llc" "$1" 2>&1 | head -1)
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$2" "$3" "$4" "$5" "$6" "$h" "${r%% *}" "${r#* }"
}
printf "test\tversion\trole\tllc\tkind\tllc_sha256_16\tresult\tfirst_diagnostic\n" > "$OUT"
echo "$SPEC" | while IFS="|" read -r t own par unr kind; do
  [ -n "$t" ] || continue
  f=$P/${own}__$(basename "$t")
  row "$f" "$t" "$own" red-parent "$par" "$kind" >> "$OUT"
  [ -n "$unr" ] && row "$f" "$t" "$own" red-unrepaired "$unr" "$kind" >> "$OUT"
  on=0; for l in $ORDER; do [ "$l" = "$own" ] && on=1; [ $on = 1 ] && row "$f" "$t" "$own" green "$l" "$kind" >> "$OUT"; done
done
' _ "/work/${OUT#$ROOT/}" "$ORDER" "$SPEC" </dev/null
awk -F'\t' 'NR>1{k=($3 ~ /red/)?"red":"green"; print k, $5, $7}' "$OUT" | sort | uniq -c
echo "unexpected:"
awk -F'\t' 'NR>1 && (($3 ~ /red/ && $5=="reg" && $7!="FAIL") || ($3=="green" && $7!="PASS") || ($3 ~ /red/ && $5=="char" && $7!="PASS"))' "$OUT"
