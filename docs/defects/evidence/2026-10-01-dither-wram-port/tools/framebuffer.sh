#!/usr/bin/env bash
# framebuffer.sh — pixel comparison of the dither demo's picture before and after the frame buffer
# moved to high WRAM, at the same animation state (harness/dither_png.c), via jgxcheck PNG dumps.
set -euo pipefail
usage() {
  cat <<'EOT'
usage: framebuffer.sh OUTDIR SRCROOT_BEFORE SRCROOT_AFTER

For each of default, a16 and a16xy16 at -O2 (and the AFTER tree also at -O3) builds
harness/dither_png.c against the given source root (a directory holding examples/snes/dither.c and
examples/65816/dither.h; SRCROOT_AFTER is normally the repository root), runs the bsnes-jg gate for
1500 frames dumping the framebuffer to OUTDIR/<label>.png, asserts corpus_result == 0x80C4, and prints
the sha256 of every PNG. At most 3 jobs; ulimit -c 0 and ulimit -v 2000000 on compiler runs.
EOT
}
case "${1:-}" in -h|--help) usage; exit 0 ;; esac
if [ "${FB_JOB:-}" != 1 ]; then
  [ $# -eq 3 ] || { usage >&2; exit 2; }
  OUT=$(realpath -m "$1"); BEFORE=$(realpath "$2"); AFTER=$(realpath "$3")
fi
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd "$HERE/../../../../.." && pwd)
TOOL=$ROOT/build/llvm-mos-install/bin; CFG=$ROOT/build/install/bin/mos-snes.cfg
DB=$ROOT/vendor/bsnes-jg/Database; HARNESS=$HERE/../harness
mkdir -p "$OUT"
job() {  # LABEL SRCROOT LEVEL MODE
  local label=$1 src=$2 level=$3 mode=$4 feat=() rc off
  case "$mode" in
    default) ;;
    a16) feat=(-Xclang -target-feature -Xclang +mos-a16) ;;
    a16xy16) feat=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  set +e
  ( ulimit -c 0; ulimit -v 2000000; timeout 600 "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" \
      -"$level" -flto -I "$src" -I "$ROOT/examples/65816" -I "$ROOT/examples/snes" -I "$ROOT/build" \
      "$HARNESS/dither_png.c" -o "$OUT/$label.sfc" ) > "$OUT/$label.build.log" 2>&1
  rc=$?
  set -e
  [ "$rc" -eq 0 ] || { echo "$label build-fail rc=$rc"; return 0; }
  off=0x$("$TOOL/llvm-objdump" -t "$OUT/$label.sfc.elf" | awk '$NF=="corpus_result"{print $1;exit}' | sed 's/^0*//')
  set +e
  ( ulimit -c 0; timeout 300 "$ROOT/build/jgxcheck" "$OUT/$label.sfc" "$DB" "$off" 2 0x80C4 1500 "$OUT/$label.png" ) > "$OUT/$label.log" 2>&1
  rc=$?
  set -e
  echo "$label rc=$rc $(grep -h SMOKE "$OUT/$label.log") png=$(sha256sum "$OUT/$label.png" | cut -c1-16)"
}
if [ "${FB_JOB:-}" = 1 ]; then job "$@"; exit 0; fi
export FB_JOB=1 OUT ROOT TOOL CFG DB HARNESS
{ for m in default a16 a16xy16; do
    echo "before-O2-$m $BEFORE O2 $m"; echo "after-O2-$m $AFTER O2 $m"; echo "after-O3-$m $AFTER O3 $m"
  done; } | xargs -P 3 -L 1 bash "$0" 2>&1 | sort
