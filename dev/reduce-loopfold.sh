#!/usr/bin/env bash
# Reproduce the cvise reduction of the DEFAULT-8bit 65816 matrix-fold-LOOP miscompile.
# (See docs/plans/2026-06-25-default8-loopfold-miscompile-reduce-and-fix.md and
#  docs/investigations/2026-06-25-default8-65816-loopfold-miscompile.md.)
#
# Self-contained + host-side (no Docker): builds a scratch WORK dir with a FIXED loop-form and
# unroll-form zoom.h, the baked sd pyramid, and two prebuilt jgxcheck-zoom verifiers, then runs
# cvise on a location-independent copy of examples/snes/mandel-zoom.c. zoom.h is held fixed (host
# and target must compile the SAME fold) so the reduction shrinks only the pressure CONTEXT in
# mandel-zoom.c. The cvise interestingness predicate is the loop-vs-unroll control on each
# candidate:
#     loop  build -> ZOOM: FAIL  ... host=0xF56C rom=0x....   (the miscompile)
#     unroll build -> ZOOM: PASS  ... zoom_crc=0xF56C          (the control)
# loop FAIL AND unroll PASS == interesting. The control rejects any cvise edit that introduces UB
# or collapses the wrong-X trigger, pinning cvise to the genuine loop-fold codegen bug.
#
# Prereqs (all in the main checkout): build/llvm-mos-install, build/install, vendor/bsnes-jg.
# Usage: dev/reduce-loopfold.sh [setup|interesting|reduce]   (default: reduce = setup + cvise)
#   setup        build the WORK dir only (honours LOOPFOLD_WORK; default a fresh mktemp)
#   interesting  run the cvise predicate on ./mandel-zoom.c in cwd (needs LOOPFOLD_WORK set)
#   reduce       setup, then run cvise --n $(nproc) to a minimal mandel-zoom.c (prints the path)
set -euo pipefail
case "${1:-reduce}" in -h|--help)
  sed -n '2,22p' "$0"; exit 0;; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLANG="$ROOT/build/llvm-mos-install/bin/mos-clang"
CFG="$ROOT/build/install/bin/mos-snes.cfg"
DB="$ROOT/vendor/bsnes-jg/Database"
SCRIPT="R:30,A:10,SELECT:4,R:50,NONE:120"   # the canonical pad dive (yields host CRC 0xF56C)

do_setup(){
  local W="$1"
  rm -rf "$W/snes-loop" "$W/snes-unroll" "$W/h65816"
  mkdir -p "$W/snes-loop" "$W/snes-unroll" "$W/h65816"
  cp "$ROOT/examples/snes/mode7.h" "$W/snes-loop/"; cp "$ROOT/examples/snes/mode7.h" "$W/snes-unroll/"
  cp "$ROOT/examples/65816/mandel.h" "$W/h65816/"
  # baked sd pyramid (64x64x6, single-bank); EXPECT = level-0 host hash
  cc -O2 -I "$ROOT/examples/65816" -I "$ROOT/tools" "$ROOT/tools/mandel-bake-pyramid.c" -o "$W/bake" -lm
  PYR_MULTIBANK=0 "$W/bake" "$W/snes-loop/pyramid_image.h" 64 64 6 32 "$W/pyr" \
    | awk '/level 0:/{for(i=1;i<=NF;i++)if($i~/^hash=/){sub(/hash=/,"",$i);print $i}}' > "$W/EXPECT"
  cp "$W/snes-loop/pyramid_image.h" "$W/snes-unroll/pyramid_image.h"
  # unroll = shipped zoom.h as-is; loop = shipped with the m[] fold rewritten to the for loop
  cp "$ROOT/examples/snes/zoom.h" "$W/snes-unroll/zoom.h"
  python3 - "$ROOT/examples/snes/zoom.h" "$W/snes-loop/zoom.h" <<'PY'
import sys
t = open(sys.argv[1]).read()
blk = "".join('  crc = zoom_crc16_byte(crc, (uint8_t)m[%d]);\n'
              '  crc = zoom_crc16_byte(crc, (uint8_t)((uint16_t)m[%d] >> 8));\n' % (i, i) for i in range(4))
loop = ("  for (int i = 0; i < 4; i++) {\n"
        "    crc = zoom_crc16_byte(crc, (uint8_t)m[i]);\n"
        "    crc = zoom_crc16_byte(crc, (uint8_t)((uint16_t)m[i] >> 8));\n  }\n")
assert blk in t, "unrolled m[] fold block not found in zoom.h"
open(sys.argv[2], "w").write(t.replace(blk, loop))
PY
  # location-independent candidate (../65816/mandel.h -> mandel.h, resolved by -I)
  sed 's#\.\./65816/mandel\.h#mandel.h#' "$ROOT/examples/snes/mandel-zoom.c" > "$W/mandel-zoom.c"
  cp "$W/mandel-zoom.c" "$W/mandel-zoom.orig.c"
  # prebuild the two host verifiers (depend only on the fixed zoom.h form)
  local ARCHIVE; ARCHIVE="$(find "$ROOT/vendor/bsnes-jg/objs" -name '*.a' | head -1)"
  for form in loop unroll; do
    g++ -O2 -std=c++11 -DJGX_ZOOM -I"$ROOT/vendor/bsnes-jg/src" -I"$ROOT/tools" \
        -I"$W/snes-$form" -c "$ROOT/dev/jgxcheck.cpp" -o "$W/jgxz-$form.o"
    g++ "$W/jgxz-$form.o" "$ARCHIVE" -lsamplerate -lm -o "$W/jgxcheck-$form"
  done
}

# cvise interestingness predicate: build ./mandel-zoom.c both ways, demand loop FAIL & unroll PASS.
do_interesting(){
  local W="${LOOPFOLD_WORK:?set LOOPFOLD_WORK}" EXPECT; EXPECT="$(cat "$W/EXPECT")"
  [ -f mandel-zoom.c ] || exit 1
  local T; T="$(mktemp -d)"
  vma(){ awk -v s="$1" '$NF==s{print $1; exit}' "$2"; }
  run(){ # $1=form -> writes $T/$1.zoom
    local f="$1" sfc="$T/$1.sfc" map="$T/$1.map"
    "$CLANG" --config "$CFG" -mcpu=mosw65816 -Os -mllvm -verify-machineinstrs \
        -I"$W/snes-$f" -I"$W/h65816" -Wl,-Map="$map" -o "$sfc" mandel-zoom.c >/dev/null 2>&1 || return 0
    python3 "$ROOT/tools/snes-checksum.py" "$sfc" >/dev/null 2>&1 || return 0
    local pad zc nf cr; pad="$(vma pad_log "$map")"; zc="$(vma zoom_crc "$map")"
    nf="$(vma nframes "$map")"; cr="$(vma corpus_result "$map")"
    [ -n "$pad" ] && [ -n "$zc" ] && [ -n "$nf" ] || return 0
    JGX_SCRIPT="$SCRIPT" JGX_PADLOG="0x$pad" JGX_PADLOG_N=64 JGX_ZOOMCRC="0x$zc" JGX_NFRAMES="0x$nf" \
      "$W/jgxcheck-$f" "$sfc" "$DB" "0x${cr:-0}" 2 "$EXPECT" 200 /dev/null 2>/dev/null \
      | grep -E '^ZOOM' | head -1 > "$T/$f.zoom" || true
  }
  run loop; run unroll
  local lo uo; lo="$(cat "$T/loop.zoom" 2>/dev/null || true)"; uo="$(cat "$T/unroll.zoom" 2>/dev/null || true)"
  rm -rf "$T"
  printf '%s\n' "$lo" | grep -q '^ZOOM: FAIL frames=64 nonzero=64 swaps=3 host=0xF56C rom=0x' || exit 1
  printf '%s\n' "$uo" | grep -q '^ZOOM: PASS frames=64 nonzero=64 swaps=3 zoom_crc=0xF56C'      || exit 1
  exit 0
}

case "${1:-reduce}" in
  setup)        do_setup "${LOOPFOLD_WORK:?set LOOPFOLD_WORK}"; echo "setup OK: $LOOPFOLD_WORK";;
  interesting)  do_interesting;;
  reduce)
    W="${LOOPFOLD_WORK:-$(mktemp -d)}"; export LOOPFOLD_WORK="$W"
    echo "WORK=$W"; do_setup "$W"
    # cvise calls an executable test script in each worker dir; wrap the 'interesting' predicate.
    printf '#!/usr/bin/env bash\nexec env LOOPFOLD_WORK=%q bash %q interesting\n' \
      "$W" "$ROOT/dev/reduce-loopfold.sh" > "$W/interesting.sh"
    chmod +x "$W/interesting.sh"
    ( cd "$W" && cvise --n "$(nproc)" "$W/interesting.sh" mandel-zoom.c )
    echo "reduced: $W/mandel-zoom.c ($(wc -l < "$W/mandel-zoom.c") lines)";;
  *) echo "usage: $0 [setup|interesting|reduce]" >&2; exit 2;;
esac
