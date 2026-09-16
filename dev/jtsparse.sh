#!/usr/bin/env bash
# dev/jtsparse.sh — render the Sparse Switch Ladder (#153 stress-test, Round 8 Cluster C).
# Corner: the THIRD switch-lowering strategy. A switch whose case values are too sparse to
# tabulate never reaches legalizeBrJt at all — it becomes a binary-search compare tree, distinct
# from both jump-table arms (#142 jt256, #152 jtedge) and never deliberately forced before.
# Two dispatchers carry the SAME sixteen handler bodies, one dense (jump table) and one sparse
# (compare tree), and must agree.
# Drive: dev/run.sh jtsparse. Outputs build/jtsparse-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh jtsparse   # run the sparse/dense dispatcher pair; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/jtsparse.c"
SIM="$ROOT/examples/snes/corpus/jtsparse_sim.c"
SDKINC="$BUILD/install/mos-platform/common/include"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/jtsparse-sim.c" -o "$BUILD/jtsparse-sim"
ORACLE=$("$BUILD/jtsparse-sim")
EXPECT=$(printf '%s\n' "$ORACLE" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: jtsparse gate hash = $EXPECT"
printf '    %s\n' "$(printf '%s\n' "$ORACLE" | head -1)"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/jtsparse.map" -o "$BUILD/jtsparse.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/jtsparse.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/jtsparse.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/jtsparse.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate — the sparse dispatcher must NOT have produced a jump table, and the dense
#    one must have. If js_sparse tabulated, the third strategy was never entered and this demo
#    would be a duplicate of #142/#152 with extra steps.
echo "==> structure gate (js_sparse = compare tree, ZERO .LJTI; js_dense = jump table; all modes)"
for MODE in default a16 xy16; do
  case "$MODE" in
    default) FEAT=() ;;
    a16)     FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16)    FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  ASM="$BUILD/jtsparse_sim_$MODE.s"
  if ! "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -isystem "$SDKINC" -Os \
      -mllvm -verify-machineinstrs -S -o "$ASM" "$SIM" \
      -I"$ROOT/examples" 2>"$BUILD/jtsparse_sim_$MODE.err"; then
    echo "    FAIL  $MODE: did not compile:"; sed 's/^/      /' "$BUILD/jtsparse_sim_$MODE.err" | head -5
    rc=1; continue
  fi
  report=$(python3 - "$ASM" <<'PY'
import sys, re
fn, cur = None, {}
for line in open(sys.argv[1]):
    m = re.match(r'^(js_(?:sparse|dense)):', line)
    if m:
        fn = m.group(1); cur[fn] = {'ljti': 0, 'idx': 0, 'cmp': 0}
    if re.match(r'^\.Lfunc_end', line):
        fn = None
    if fn:
        if '.LJTI' in line:                      cur[fn]['ljti'] += 1
        if re.search(r'jmp\s+\(\.LJTI', line):   cur[fn]['idx'] += 1
        if re.match(r'^\s+(cmp|cpx|cpy|sbc)\b', line): cur[fn]['cmp'] += 1
sp, de = cur.get('js_sparse'), cur.get('js_dense')
if sp is None or de is None:
    print('BAD js_sparse/js_dense not both present in the emitted asm'); raise SystemExit
ok = (sp['ljti'] == 0 and sp['cmp'] >= 8 and de['idx'] >= 1)
print(('OK ' if ok else 'BAD ')
      + 'js_sparse: LJTI=%d compares=%d   js_dense: jmp(.LJTI,x)=%d LJTI=%d'
        % (sp['ljti'], sp['cmp'], de['idx'], de['ljti']))
PY
)
  case "$report" in
    OK*)  echo "    PASS  $MODE: ${report#OK }  (-verify clean)" ;;
    *)    echo "    FAIL  $MODE: ${report#BAD }"; rc=1 ;;
  esac
done

# 3b. Runtime cross-checks: the two strategies must agree at every step, and both default arms
#     must genuinely have been taken — an all-hit stream would leave the miss path untested, and
#     a compare tree's default is the fall-out of the whole search, not a range check.
DIS=$(printf '%s\n' "$ORACLE" | grep -oE 'disagreements=[0-9]+' | cut -d= -f2)
DM=$(printf '%s\n' "$ORACLE" | grep -oE 'dense_misses=[0-9]+' | cut -d= -f2)
SM=$(printf '%s\n' "$ORACLE" | grep -oE 'sparse_misses=[0-9]+' | cut -d= -f2)
if [ "${DIS:-1}" -eq 0 ] && [ "${DM:-0}" -ge 1 ] && [ "${SM:-0}" -ge 1 ] && [ "${DM:-0}" -eq "${SM:-1}" ]; then
  echo "    PASS  strategy 1 == strategy 3: disagreements=$DIS  default arms taken: dense=$DM sparse=$SM"
else
  echo "    FAIL  disagreements=${DIS:-?} dense_misses=${DM:-?} sparse_misses=${SM:-?} (want 0 / >=1 / equal)"
  rc=1
fi

# 4. bsnes-jg.
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + assert (build/jtsparse-jg.png, frame 600)"
  "$JGX" "$BUILD/jtsparse.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/jtsparse-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/jtsparse-mame.png)"
  SNAP="$BUILD/.jtsparse-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/jtsparse.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/jtsparse.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/jtsparse-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Sparse Switch Ladder on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc
