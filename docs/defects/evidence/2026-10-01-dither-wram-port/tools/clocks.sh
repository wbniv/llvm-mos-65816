#!/usr/bin/env bash
# clocks.sh — master clocks of the dither demo's own main, before and after the frame buffer moved to
# high WRAM, with the o2-large method (bsnes-jg cycle probe, main entry to the corpus_result write).
set -euo pipefail
usage() {
  cat <<'EOT'
usage: clocks.sh OUTDIR LABEL SRCROOT HARNESSDIR LEVEL [MODE ...]

Builds HARNESSDIR/dither_run.c (it includes examples/snes/dither.c, found under SRCROOT) with the
installed SDK driver, as the o2-large LTO path does (mos-clang --config mos-snes.cfg -mcpu=mosw65816
[mode features] -LEVEL -flto), at DITHER_RUN_FRAMES = 6 and 12, links, checksums, and measures
main's entry to the instruction that writes the expected corpus_result with the cycle probe, two runs per
ROM. MODE is default, a16 or a16xy16 (default: all three). Writes OUTDIR/LABEL.tsv:
  label level mode frames status clocks main_bytes rom_sha256
The expected folds are the host oracle's for the unchanged algorithm (o2-large runtime/oracle.txt):
6 frames 0x15CC, 12 frames 0x21FF. At most 3 jobs run at once; every compiler and probe run is under
ulimit -c 0, a 2 GB address-space cap (compiler) and a timeout.

Environment: PROBE (default: a copy of the o2-large jgxcycles), MOS_TOOLCHAIN (default build/llvm-mos-install).
EOT
}
case "${1:-}" in -h|--help|"") usage; exit 0 ;; esac
[ $# -ge 5 ] || { usage >&2; exit 2; }
OUT=$(realpath -m "$1"); LABEL=$2; SRCROOT=$(realpath "$3"); HARNESS=$(realpath "$4"); LEVEL=$5; shift 5
MODES=("$@"); [ ${#MODES[@]} -gt 0 ] || MODES=(default a16 a16xy16)
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../../../.." && pwd)
TOOL=${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin
CFG=$ROOT/build/install/bin/mos-snes.cfg
PROBE=${PROBE:-$ROOT/build/jgxcycles}
DB=$ROOT/vendor/bsnes-jg/Database
HOOKDIR=$ROOT/docs/defects/evidence/2026-09-30-native-width-pressure-sets/o2-large/harness
mkdir -p "$OUT/$LABEL"

job() {  # MODE FRAMES
  local mode=$1 frames=$2 want feat=() d rc
  case "$frames" in 6) want=0x15CC ;; 12) want=0x21FF ;; *) echo "bad frames $frames" >&2; return 2 ;; esac
  case "$mode" in
    default) ;;
    a16) feat=(-Xclang -target-feature -Xclang +mos-a16) ;;
    a16xy16) feat=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  d=$OUT/$LABEL/$LEVEL-$mode-$frames; mkdir -p "$d"
  set +e
  ( ulimit -c 0; ulimit -v 2000000; timeout 600 "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" \
      -"$LEVEL" -flto -I "$SRCROOT" -I "$HARNESS" -I "$HOOKDIR" -I "$ROOT/examples/65816" -I "$ROOT/examples/snes" \
      -I "$ROOT/build" -DDITHER_RUN_FRAMES="$frames"u "$HARNESS/dither_run.c" -o "$d/rom.sfc" \
      -Wl,-Map="$d/rom.map" ) > "$d/build.log" 2>&1
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    printf '%s\t%s\t%s\t%s\tbuild-fail-rc%s\t-\t-\t-\n' "$LABEL" "$LEVEL" "$mode" "$frames" "$rc"; return 0
  fi
  python3 "$ROOT/tools/snes-checksum.py" "$d/rom.sfc" > /dev/null
  local sym start size off
  sym=$("$TOOL/llvm-objdump" -t "$d/rom.sfc.elf")
  read -r start size < <(printf '%s\n' "$sym" | awk '$NF=="main"{print "0x"$1, "0x"$(NF-1); exit}')
  off=$(printf '%s\n' "$sym" | awk '$NF=="corpus_result"{print "0x"$1; exit}')
  off=$(printf '0x%X' $(( off >= 0x7e0000 ? off - 0x7e0000 : off )))
  local o1 o2
  set +e
  o1=$( ( ulimit -c 0; timeout 600 "$PROBE" "$d/rom.sfc" "$DB" "$start" $(( start + size )) 0xffffffff "$off" 2 "$want" 3000 1 ) 2>&1 )
  o2=$( ( ulimit -c 0; timeout 600 "$PROBE" "$d/rom.sfc" "$DB" "$start" $(( start + size )) 0xffffffff "$off" 2 "$want" 3000 1 ) 2>&1 )
  set -e
  printf '%s\n%s\n' "$o1" "$o2" > "$d/probe.json"
  python3 - "$LABEL" "$LEVEL" "$mode" "$frames" "$o1" "$o2" "$size" "$(sha256sum "$d/rom.sfc" | cut -c1-16)" <<'EOP'
import json, sys
label, level, mode, frames, o1, o2, size, sha = sys.argv[1:]
try:
    a, b = json.loads(o1), json.loads(o2)
    ok = a['pass'] and b['pass'] and a == b
    clocks = a['samples'][0] if a['samples'] else '-'
    status = 'PASS' if ok else ('FAIL got=%s' % hex(a['got']) if not a['pass'] else 'NONDETERMINISTIC')
except Exception as e:
    status, clocks = 'probe-error', '-'
print('\t'.join([label, level, mode, frames, status, str(clocks), str(int(size, 16)), sha]))
EOP
}

if [ "${CLOCKS_JOB:-}" = 1 ]; then job "$@"; exit 0; fi
export CLOCKS_JOB=1 OUT LABEL SRCROOT HARNESS LEVEL PROBE MOS_TOOLCHAIN="${MOS_TOOLCHAIN:-}"
{ for m in "${MODES[@]}"; do for f in 6 12; do echo "$m $f"; done; done; } |
  xargs -P 3 -L 1 bash "$0" "$OUT" "$LABEL" "$SRCROOT" "$HARNESS" "$LEVEL" > "$OUT/$LABEL.tsv.unsorted"
sort -k3,3 -k4,4n "$OUT/$LABEL.tsv.unsorted" > "$OUT/$LABEL.tsv"; rm -f "$OUT/$LABEL.tsv.unsorted"
cat "$OUT/$LABEL.tsv"
