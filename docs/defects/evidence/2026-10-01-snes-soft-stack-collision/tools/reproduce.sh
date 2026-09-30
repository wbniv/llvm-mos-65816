#!/usr/bin/env bash
# reproduce.sh — capture and replay the dither -O3 soft-stack collision (snes-soft-stack-static-data-collision).
set -euo pipefail
usage() {
  cat <<'EOF'
usage: reproduce.sh SUBCOMMAND OUT [ARGS...]

Run from anywhere; paths resolve against the repository root. Every compiler, linker and
emulator run is bounded by `ulimit -c 0; ulimit -v 2000000` (emulator: -c 0 only) and timeout.

  gate OUT LEVEL MODE LAYOUT [FRAMES]
      Build examples/snes/dither.c with the SDK driver exactly as the o3-dither report did
      (mos-clang --config mos-snes.cfg -mcpu=mosw65816 [+mos-a16] -LEVEL, LTO), with
      --save-temps, into OUT/LEVEL-MODE-LAYOUT/. MODE is default or a16. LAYOUT is stock
      (the installed link.ld) or reorder (tools/reorder-ld.py: same script, data reordered).
      Prints toolchain/ROM hashes, main's soft-stack frame, the RAM layout and the overlap,
      then runs the bsnes-jg gate (build/jgxcheck, corpus_result == 0x80C4 after FRAMES,
      default 600). Exit status = jgxcheck's (1 on mismatch).
  code-identity OUT LEVEL MODE
      Compare the stock and reorder ROMs' instruction streams with every $-operand masked.
  llc OUT LEVEL MODE LLC OLVL
      Compile OUT/LEVEL-MODE-stock's precodegen bitcode with LLC at -OLVL (the LTO codegen
      options), link with the SDK, run the gate. Used for the upstream llc and -O0..-O3 replays.
  norecurse OUT
      Mark main norecurse in the -O3 default precodegen IR (text edit), compile with the
      installed llc, link: main's frame moves to the static stack and the link must fail.
  nonreentrant-main OUT
      Declare main __attribute__((nonreentrant)) in a copy of dither.c and build -O2 and -O3:
      main's frame goes on the static stack, so -O3 must fail to link and -O2 must pass.
  upstream-clang OUT LAYOUT
      Full build with the unpatched upstream clang (build/upstream-reference/742d554b...)
      and this repo's SNES SDK, stock or reorder layout, then the gate.
  host OUT
      Host oracle tools/dither-sim.c at -O2 and at -O3 with ASan+UBSan, and the whole demo
      (o2-large harness host-oracle.sh) at -O3 with ASan+UBSan.
  latch OUT ROM PC
      Build tools/jgxlatch.cpp against the probe core and print main's spill slots at PC.
  mame OUT
      (inside dev/container.sh) MAME + dev/dither.lua assert for every OUT/*/rom.sfc.
  verify OUT LEVEL MODE
      llc -verify-machineinstrs on OUT/LEVEL-MODE-stock's precodegen bitcode.
EOF
}
case "${1:-}" in -h|--help|'') usage; exit 0 ;; esac
SUB=$1; shift
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../../../.." && pwd)   # docs/defects/evidence/<dir>/tools -> repository root
TOOL=${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin
CFG=$ROOT/build/install/bin/mos-snes.cfg
LIB=$ROOT/build/install/mos-platform
SRC=$ROOT/examples/snes/dither.c
DB=$ROOT/vendor/bsnes-jg/Database
JGX=$ROOT/build/jgxcheck
UPCLANG=${UPSTREAM_CLANG:-/home/will/llvm-mos-65816/build/upstream-reference/742d554bf08042b8df93d791c335260fadd16643/bin}
PROBE_BSNES=${PROBE_BSNES:-/home/will/llvm-mos-65816/build/pressure-sets/opt-levels/probe/bsnes}
EXPECT=0x80C4
MOPTS=(-align-large-globals=false -force-loop-cold-block -force-precise-rotation-cost -jump-inst-cost=6
       -lsr-complexity-limit=10000000 -phi-node-folding-threshold=0 -speculate-blocks=0 -zp-avail=224)
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
sha() { sha256sum "$1" | cut -d' ' -f1; }
feat() { [ "$1" = a16 ] && echo "-Xclang -target-feature -Xclang +mos-a16" || true; }
sym() { "$TOOL/llvm-objdump" -t "$1" | awk -v n="$2" '$NF==n{print $1; exit}'; }

# Report main's soft-stack frame (prologue "adc #lo ... adc #hi" on __rc0/__rc1) and the overlap
# of [__stack - frame, __stack) with static low-WRAM data.
layout() {
  local elf=$1 map=${2:-} dis frame lo hi
  dis=$("$TOOL/llvm-objdump" -d "$elf" | sed -n '/<main>:/,+8p')
  lo=$(printf '%s\n' "$dis" | awk '/adc\t#\$/{print $NF; exit}' | tr -d '#$')
  hi=$(printf '%s\n' "$dis" | awk '/adc\t#\$/{n++; if (n==2) {print $NF; exit}}' | tr -d '#$')
  if printf '%s\n' "$dis" | sed -n 2,3p | grep -q 'lda.*\$0 ' && [ -n "$lo" ] && [ -n "$hi" ]; then
    frame=$(( 0x10000 - 0x$hi$lo ))
  else
    frame=0
  fi
  python3 - "$elf" "$frame" "$TOOL/llvm-objdump" "$map" <<'EOF'
import re, subprocess, sys
elf, frame, objdump, mapfile = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
syms = {}
for l in subprocess.check_output([objdump, '-t', elf], text=True).splitlines():
    p = l.split()
    if len(p) >= 5 and len(p[0]) == 8:
        syms[p[-1]] = (int(p[0], 16), int(p[-2], 16) if len(p[-2]) == 8 else 0, l)
stack = syms['__stack'][0]
lo = stack - frame
print(f'main soft-stack frame: {frame} B -> [{lo:#06x}, {stack:#06x})')
print(f'__bss_end={syms["__bss_end"][0]:#06x} __heap_start={syms["__heap_start"][0]:#06x} '
      f'soft-stack headroom above __heap_start: {stack - syms["__heap_start"][0]} B')
hits = []
for name, (a, s, l) in sorted(syms.items(), key=lambda kv: kv[1][0]):
    if s and ('.bss' in l or '.noinit' in l) and a < stack and a + s > lo:
        hits.append(f'  overlaps {name} [{a:#06x}, {a + s:#06x}) by {min(a + s, stack) - max(a, lo)} B')
if mapfile:
    for l in open(mapfile):
        m = re.match(r' +([0-9a-f]+) +[0-9a-f]+ +([0-9a-f]+) +1 +\.noinit$', l)
        if m:
            a, s = int(m.group(1), 16), int(m.group(2), 16)
            if s and a < stack and a + s > lo:
                hits.append(f'  overlaps .noinit (static stack) [{a:#06x}, {a + s:#06x}) '
                            f'by {min(a + s, stack) - max(a, lo)} B')
print('\n'.join(hits) if hits else '  no overlap with named .bss objects or .noinit')
EOF
}

gate_rom() {  # ROM LABEL FRAMES -> jgxcheck rc
  local rom=$1 frames=$2 off rc
  off=0x$(sym "$rom.elf" corpus_result | sed 's/^0*//')
  echo "$(ts) bsnes-jg: jgxcheck $rom $off 2 $EXPECT $frames (jgxcheck $(sha "$JGX"))"
  set +e
  ( ulimit -c 0; timeout 300 "$JGX" "$rom" "$DB" "$off" 2 "$EXPECT" "$frames" ) 2>&1 | grep -E 'SMOKE|error'
  rc=${PIPESTATUS[0]}
  set -e
  echo "$(ts) gate rc=$rc"
  return "$rc"
}

case "$SUB" in
gate)
  OUT=$1; L=$2; MODE=$3; LAYOUT=$4; FRAMES=${5:-600}
  D=$OUT/$L-$MODE-$LAYOUT; mkdir -p "$D"; cd "$D"
  EXTRA=()
  if [ "$LAYOUT" = reorder ]; then
    python3 "$HERE/reorder-ld.py" "$LIB/snes/lib/link.ld" "$D/ldscript" >/dev/null
    EXTRA=(-Wl,-L,"$D/ldscript")
  fi
  echo "$(ts) toolchain: clang-23 $(sha "$TOOL/clang-23") lld $(sha "$TOOL/lld") mos-snes.cfg $(sha "$CFG") link.ld $(sha "$LIB/snes/lib/link.ld")"
  echo "$(ts) input: $SRC $(sha "$SRC")"
  # shellcheck disable=SC2046
  CMD=("$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 $(feat "$MODE") -"$L" -I "$ROOT/examples/65816"
       -I "$ROOT/examples/snes" -I "$ROOT/build" "$SRC" -o rom.sfc -save-temps=obj -Wl,--save-temps
       -Wl,-Map=rom.map "${EXTRA[@]}")
  echo "$(ts) command (cwd $D): ${CMD[*]}"
  set +e
  ( ulimit -c 0; ulimit -v 2000000; timeout 600 "${CMD[@]}" )
  rc=$?
  set -e
  echo "$(ts) build rc=$rc"
  [ "$rc" -eq 0 ] || exit 3
  echo "$(ts) rom.sfc sha256 $(sha rom.sfc) (unchecksummed, as in the report)"
  layout rom.sfc.elf rom.map
  gate_rom rom.sfc "$FRAMES"
  ;;
code-identity)
  OUT=$1; L=$2; MODE=$3
  norm() { "$TOOL/llvm-objdump" -d --no-show-raw-insn "$1" | tail -n +3 |
           sed 's/;.*//;s/<[^>]*>//g;s/\$[0-9a-f]*/$X/g;s/^ *[0-9a-f]*://' | awk 'NF{$1=$1;print}'; }
  a=$OUT/$L-$MODE-stock/rom.sfc.elf; b=$OUT/$L-$MODE-reorder/rom.sfc.elf
  n=$(diff <(norm "$a") <(norm "$b") | grep -c '^[<>]' || true)
  echo "$(ts) $L $MODE stock vs reorder: $(norm "$a" | wc -l) instructions, $n differ after masking \$-operands"
  [ "$n" -eq 0 ]
  ;;
llc)
  OUT=$1; L=$2; MODE=$3; LLC=$4; OL=$5
  D=$OUT/$L-$MODE-stock; R=$OUT/llc-$L-$MODE-$(basename "$(dirname "$LLC")")-$(basename "$LLC")-O$OL
  mkdir -p "$R"
  ATTR=(); [ "$MODE" = a16 ] && ATTR=(-mattr=+mos-a16)
  echo "$(ts) llc $LLC sha256 $(sha "$LLC") -O$OL on $D/rom.sfc.0.5.precodegen.bc $(sha "$D/rom.sfc.0.5.precodegen.bc")"
  set +e
  ( ulimit -c 0; ulimit -v 2000000; timeout 600 "$LLC" -mtriple=mos -mcpu=mosw65816 "${ATTR[@]}" -O"$OL" \
      -function-sections -data-sections "${MOPTS[@]}" -filetype=obj "$D/rom.sfc.0.5.precodegen.bc" -o "$R/rom.o" )
  rc=$?
  set -e
  echo "$(ts) llc rc=$rc"; [ "$rc" -eq 0 ] || exit 3
  set +e
  ( ulimit -c 0; ulimit -v 2000000; timeout 300 "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Os \
      "$R/rom.o" -Wl,-Map="$R/rom.map" -o "$R/rom.sfc" )
  rc=$?
  set -e
  echo "$(ts) link rc=$rc"; [ "$rc" -eq 0 ] || exit 4
  echo "$(ts) rom.sfc sha256 $(sha "$R/rom.sfc")"
  layout "$R/rom.sfc.elf" "$R/rom.map"
  gate_rom "$R/rom.sfc" 600
  ;;
norecurse)
  OUT=$1; D=$OUT/O3-default-stock; R=$OUT/norecurse; mkdir -p "$R"
  DIS=${LLVM_DIS:-/home/will/llvm-mos-65816/build/llvm-mos/bin/llvm-dis}
  echo "$(ts) llvm-dis $DIS sha256 $(sha "$DIS")"
  "$DIS" "$D/rom.sfc.0.5.precodegen.bc" -o "$R/precodegen.ll"
  sed 's/^define dso_local noundef i16 @main() local_unnamed_addr #0 {$/define dso_local noundef i16 @main() local_unnamed_addr norecurse #0 {/' \
    "$R/precodegen.ll" > "$R/norecurse.ll"
  echo "$(ts) edit: $(diff "$R/precodegen.ll" "$R/norecurse.ll" | grep -c '^>') line(s) changed (main gains norecurse)"
  for v in precodegen norecurse; do
    set +e
    ( ulimit -c 0; ulimit -v 2000000; timeout 600 "$TOOL/llc" -mtriple=mos -mcpu=mosw65816 -O3 \
        -function-sections -data-sections "${MOPTS[@]}" -filetype=obj "$R/$v.ll" -o "$R/$v.o" )
    rc=$?
    set -e
    echo "$(ts) llc $v rc=$rc"
    set +e
    ( ulimit -c 0; ulimit -v 2000000; timeout 300 "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Os \
        "$R/$v.o" -Wl,-Map="$R/$v.map" -o "$R/$v.sfc" ) 2>&1 | grep -v '^$'
    rc=${PIPESTATUS[0]}
    set -e
    echo "$(ts) link $v rc=$rc"
    [ "$rc" -eq 0 ] && { layout "$R/$v.sfc.elf" "$R/$v.map"; gate_rom "$R/$v.sfc" 600 || true; }
  done
  ;;
nonreentrant-main)
  OUT=$1; R=$OUT/nonreentrant-main; mkdir -p "$R"
  sed 's/^int main(void) {$/__attribute__((nonreentrant)) int main(void) {/' "$SRC" > "$R/dither.c"
  echo "$(ts) edit: $(diff "$SRC" "$R/dither.c" | grep -c '^>') line(s) changed (main declared nonreentrant)"
  for L in O2 O3; do
    set +e
    ( ulimit -c 0; ulimit -v 2000000; timeout 600 "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -"$L" \
        -I "$ROOT/examples/65816" -I "$ROOT/examples/snes" -I "$ROOT/build" "$R/dither.c" \
        -Wl,-Map="$R/$L.map" -o "$R/$L.sfc" ) 2>&1 | grep -v '^$'
    rc=${PIPESTATUS[0]}
    set -e
    echo "$(ts) -$L build rc=$rc"
    [ "$rc" -eq 0 ] && { layout "$R/$L.sfc.elf" "$R/$L.map"; gate_rom "$R/$L.sfc" 600 || true; }
  done
  ;;
upstream-clang)
  OUT=$1; LAYOUT=$2; D=$OUT/upstream-clang-O3-default-$LAYOUT; mkdir -p "$D"; cd "$D"
  EXTRA=()
  if [ "$LAYOUT" = reorder ]; then
    python3 "$HERE/reorder-ld.py" "$LIB/snes/lib/link.ld" "$D/ldscript" >/dev/null
    EXTRA=(-Wl,-L,"$D/ldscript")
  fi
  echo "$(ts) upstream clang-23 $(sha "$UPCLANG/clang-23") (manifest: unpatched 742d554bf08042b8df93d791c335260fadd16643) lld $(sha "$UPCLANG/lld")"
  set +e
  ( ulimit -c 0; ulimit -v 2000000; timeout 600 "$UPCLANG/mos-clang" --config "$CFG" -mcpu=mosw65816 -O3 \
      -I "$ROOT/examples/65816" -I "$ROOT/examples/snes" -I "$ROOT/build" "$SRC" -o rom.sfc \
      -Wl,-Map=rom.map "${EXTRA[@]}" ) 2>&1 | grep -v 'different data layouts' | grep -v '^$'
  rc=${PIPESTATUS[0]}
  set -e
  echo "$(ts) build rc=$rc (the SDK libc data-layout warning is filtered: it lists address spaces p2/p3)"
  [ "$rc" -eq 0 ] || exit 3
  echo "$(ts) rom.sfc sha256 $(sha rom.sfc)"
  layout rom.sfc.elf rom.map
  gate_rom rom.sfc 600
  ;;
host)
  OUT=$1; mkdir -p "$OUT/bin"
  cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/dither-sim.c" -o "$OUT/dither-sim-O2"
  echo "$(ts) dither-sim -O2: $("$OUT/dither-sim-O2" 2>&1 | tr '\n' ' ')"
  gcc -O3 -fsanitize=undefined,address -fno-sanitize-recover=all -Wall -Wextra \
      -I "$ROOT/examples/65816" "$ROOT/tools/dither-sim.c" -o "$OUT/dither-sim-O3-san"
  set +e
  san=$("$OUT/dither-sim-O3-san" 2>&1)
  rc=$?
  set -e
  echo "$(ts) dither-sim -O3 ASan+UBSan (rc=$rc): $(printf '%s' "$san" | tr '\n' ' ')"
  printf '#!/usr/bin/env bash\nexec /usr/bin/gcc "$@" -O3 -fsanitize=undefined,address -fno-sanitize-recover=all -fno-sanitize=alignment\n' > "$OUT/bin/cc"
  chmod +x "$OUT/bin/cc"
  echo "$(ts) whole demo (o2-large host-oracle.sh; cc = gcc $(gcc -dumpfullversion) -O3 ASan+UBSan, alignment off for the harness MMIO shim):"
  ( ulimit -c 0; PATH=$OUT/bin:$PATH bash "$ROOT/docs/defects/evidence/2026-09-30-native-width-pressure-sets/o2-large/tools/host-oracle.sh" \
      "$ROOT" "$OUT/demo" dither dither:DITHER_RUN_FRAMES=6 )
  echo "$(ts) sanitized: $(ldd "$OUT/demo/dither" | grep -oE 'lib(a|ub)san[^ ]*' | tr '\n' ' ')"
  ;;
latch)
  OUT=$1; ROM=$2; PC=$3; mkdir -p "$OUT"
  ( ulimit -v 4000000; g++ -O2 -std=c++11 -I"$PROBE_BSNES/src" "$HERE/jgxlatch.cpp" "$PROBE_BSNES/objs/libbsnes.a" \
      -lsamplerate -lm -o "$OUT/jgxlatch" )
  echo "$(ts) probe core $(sha "$PROBE_BSNES/objs/libbsnes.a"); ROM $(sha "$ROM"); watch $PC"
  ( ulimit -c 0; timeout 300 "$OUT/jgxlatch" "$ROM" "$DB" "$PC" 300 40 )
  ;;
mame)
  OUT=$1
  for rom in "$OUT"/*/rom.sfc; do
    off=$(sym "$rom.elf" corpus_result); addr=$(printf '0x%X' $(( 0x7E0000 + 0x$off )))
    set +e
    line=$(SHOT_ADDR="$addr" SHOT_WANT="$EXPECT" timeout 120 xvfb-run -a mame snes -cart "$rom" \
      -rompath "$ROOT/dev/roms" -autoboot_script "$ROOT/dev/dither.lua" -skip_gameinfo -sound none \
      -nothrottle -seconds_to_run 30 -snapshot_directory /tmp/snap -cfg_directory /tmp -nvram_directory /tmp \
      2>/dev/null | grep -m1 '^SHOT:')
    set -e
    echo "$(ts) MAME $(basename "$(dirname "$rom")") corpus_result@$addr: ${line:-no SHOT line}"
  done
  ;;
verify)
  OUT=$1; L=$2; MODE=$3; D=$OUT/$L-$MODE-stock
  ATTR=(); [ "$MODE" = a16 ] && ATTR=(-mattr=+mos-a16)
  set +e
  ( ulimit -c 0; ulimit -v 2000000; timeout 900 "$TOOL/llc" -mtriple=mos -mcpu=mosw65816 "${ATTR[@]}" -"$L" \
      -function-sections -data-sections "${MOPTS[@]}" -verify-machineinstrs -filetype=null \
      "$D/rom.sfc.0.5.precodegen.bc" -o /dev/null ) 2>&1 | tail -3
  rc=${PIPESTATUS[0]}
  set -e
  echo "$(ts) $L $MODE -verify-machineinstrs rc=$rc"
  ;;
*) usage >&2; exit 2 ;;
esac
