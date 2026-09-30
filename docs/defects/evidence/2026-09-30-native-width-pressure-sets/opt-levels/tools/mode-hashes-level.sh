#!/usr/bin/env bash
# Opt-level variant (2026-09-30 optimization-level gating run): OLEVEL=0-3
# selects llc -O (default 2; clang -Os/-Oz also run codegen at -O2 and differ
# only in the optsize/minsize attributes, see make-level-inputs.sh), and
# every llc runs under ulimit -v 2000000 (the 2026-09-30 OOM rule).
# Hash llc output (asm and object) for every input of the fixed set, per mode.
#
# usage: mode-hashes.sh LLC OUT.tsv [MODE ...]
#   LLC   llc binary under /home/will/llvm-mos-65816 (runs in the dev container)
#   OUT   TSV under /home/will/llvm-mos-65816: input, mode, asm rc, asm sha256,
#         obj rc, obj sha256
#   MODE  label=cpu[:features]; default: mos6502=mos6502 mosw65816=mosw65816
#         (native examples: a16=mosw65816:+mos-a16
#          a16xy16=mosw65816:+mos-a16,+mos-xy16)
# Env: INPUTS  input directory as seen in the container
#              (default /work/build/pressure-sets/default-inputs: the split's
#              fixed set, 38 MOS CodeGen .ll tests at 06bc967d2668 plus 52
#              frozen corpus IRs with target-cpu/features attributes stripped).
# A failing compile is keyed by its first diagnostic line with the leading
# "program-name: " prefix, digits and /work paths removed, so the llc file name
# does not affect the result.
# Derived from build/split-320-321/spec/default-hashes.sh (modes parameterized,
# program-name prefix dropped from the error key).
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
LLC=$(realpath "$1"); OUT=$(realpath -m "$2"); shift 2
[ $# -gt 0 ] || set -- mos6502=mos6502 mosw65816=mosw65816
case "$LLC" in $ROOT/*) ;; *) echo "llc must live under $ROOT" >&2; exit 2;; esac
case "$OUT" in $ROOT/*) ;; *) echo "output must live under $ROOT" >&2; exit 2;; esac
C_LLC=/work/${LLC#$ROOT/}; C_OUT=/work/${OUT#$ROOT/}
IN=${INPUTS:-/work/build/pressure-sets/default-inputs}
cd "$ROOT"
dev/container.sh -- sh -c '
set -eu
ulimit -c 0; ulimit -v 2000000
LLC=$1; OUT=$2; IN=$3; OL=$4; shift 4
T=$(mktemp -d)
: > "$OUT.tmp"
for f in "$IN"/tests/*.ll "$IN"/corpus/*.ll; do
  rel=${f#$IN/}
  for spec in "$@"; do
    label=${spec%%=*}; rest=${spec#*=}; cpu=${rest%%:*}
    case "$rest" in *:*) attr="-mattr=${rest#*:}";; *) attr=;; esac
    set +e
    timeout 120 "$LLC" -mtriple=mos -mcpu=$cpu $attr -O$OL "$f" -o "$T/o.s" 2>"$T/e"; ra=$?
    timeout 120 "$LLC" -mtriple=mos -mcpu=$cpu $attr -O$OL -filetype=obj "$f" -o "$T/o.o" 2>/dev/null; ro=$?
    set -e
    if [ $ra -eq 0 ]; then ha=$(sha256sum < "$T/o.s" | cut -c1-16); else ha=err:$(head -n1 "$T/e" | sed "s/^[^ :]*: //; s/[0-9]//g; s|/work/[^ :]*||g" | sha256sum | cut -c1-12); fi
    if [ $ro -eq 0 ]; then ho=$(sha256sum < "$T/o.o" | cut -c1-16); else ho=-; fi
    printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$rel" "$label" "$ra" "$ha" "$ro" "$ho" >> "$OUT.tmp"
    rm -f "$T/o.s" "$T/o.o"
  done
done
mv "$OUT.tmp" "$OUT"
rm -rf "$T"
' _ "$C_LLC" "$C_OUT" "$IN" "${OLEVEL:-2}" "$@"
wc -l < "$OUT"
