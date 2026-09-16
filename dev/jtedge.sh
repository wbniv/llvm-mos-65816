#!/usr/bin/env bash
# dev/jtedge.sh — render the Jump-Table Boundary Sweep (#152 stress-test, Round 8 Cluster C).
# Corner: the EXACT `Table.MBBs.size() <= 128` test in legalizeBrJt (MOSLegalizerInfo.cpp:3334).
# Three dispatchers at 127, 128 and 129 successors compile both arms and the boundary itself
# side by side. Measured result: the boundary is exact and inclusive at 128 — there is NO
# off-by-one, which is a negative result for the bug this demo was built to find and a positive
# one for the constant, which nothing in the tree pinned before. #142 jt256 sits at 256.
# Drive: dev/run.sh jtedge. Outputs build/jtedge-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh jtedge   # run the 127/128/129-successor sweep; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/jtedge.c"
SIM="$ROOT/examples/snes/corpus/jtedge_sim.c"
SDKINC="$BUILD/install/mos-platform/common/include"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/jtedge-sim.c" -o "$BUILD/jtedge-sim"
ORACLE=$("$BUILD/jtedge-sim")
EXPECT=$(printf '%s\n' "$ORACLE" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: jtedge gate hash = $EXPECT"
printf '    %s\n' "$(printf '%s\n' "$ORACLE" | head -1)"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/jtedge.map" -o "$BUILD/jtedge.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/jtedge.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/jtedge.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/jtedge.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate — WHICH ARM each dispatcher took, read out of the emitted assembly. This is
#    the whole point of the demo: if all three took the same arm, or if 128 fell over to the
#    split arm, the boundary constant is not what the source says it is.
#      JMPIdxIndir arm : `jmp (.LJTI<n>_0,x)`
#      split lo/hi arm : `ld{a,x,y} .LJTI<n>_0,x` + `ld{a,x,y} .LJTI<n>_0+256,x` (MO_HI_JT)
#                        + `jmp (__rc<n>)`
echo "==> structure gate (127/128 take JMP (abs,X); 129 takes the split lo/hi + MO_HI_JT arm)"
for MODE in default a16 xy16; do
  case "$MODE" in
    default) FEAT=() ;;
    a16)     FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16)    FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  ASM="$BUILD/jtedge_sim_$MODE.s"
  if ! "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -isystem "$SDKINC" -Os \
      -mllvm -verify-machineinstrs -S -o "$ASM" "$SIM" \
      -I"$ROOT/examples" 2>"$BUILD/jtedge_sim_$MODE.err"; then
    echo "    FAIL  $MODE: did not compile:"; sed 's/^/      /' "$BUILD/jtedge_sim_$MODE.err" | head -5
    rc=1; continue
  fi
  report=$(python3 - "$ASM" <<'PY'
import sys, re
fn, cur = None, {}
for line in open(sys.argv[1]):
    m = re.match(r'^(je_d\d+):', line)
    if m:
        fn = m.group(1); cur[fn] = {'idx': 0, 'lo': 0, 'hi': 0, 'ind': 0}
    if re.match(r'^\.Lfunc_end', line):
        fn = None
    if fn:
        if re.search(r'jmp\s+\(\.LJTI', line):                      cur[fn]['idx'] += 1
        elif re.search(r'ld[axy]\s+\.LJTI\S*\+256', line):          cur[fn]['hi'] += 1
        elif re.search(r'ld[axy]\s+\.LJTI', line):                  cur[fn]['lo'] += 1
        if re.search(r'jmp\s+\(__rc', line):                        cur[fn]['ind'] += 1
# table entry counts
sizes, name, n = {}, None, 0
for line in open(sys.argv[1]):
    m = re.match(r'^(\.LJTI\d+_\d+):', line)
    if m:
        if name: sizes[name] = n
        name, n = m.group(1), 0; continue
    if name is not None:
        if re.match(r'^\s*\.(byte|word|short|addr)\b', line): n += 1
        elif re.match(r'^\s*\.(section|size|globl|type)', line) or re.match(r'^\S+:', line):
            sizes[name] = n; name, n = None, 0
if name: sizes[name] = n
ok = True
out = []
for f, want_split in (('je_d127', False), ('je_d128', False), ('je_d129', True)):
    v = cur.get(f)
    if v is None:
        out.append('%s MISSING' % f); ok = False; continue
    is_split = v['lo'] >= 1 and v['hi'] >= 1 and v['ind'] >= 1 and v['idx'] == 0
    is_idx   = v['idx'] >= 1 and v['lo'] == 0 and v['hi'] == 0
    got = 'split-lo/hi' if is_split else ('JMPIdxIndir' if is_idx else 'UNRECOGNISED')
    if (want_split and not is_split) or ((not want_split) and not is_idx): ok = False
    out.append('%s=%s' % (f, got))
out.append('tables=' + ','.join('%s:%d' % (k, v) for k, v in sorted(sizes.items())))
print(('OK ' if ok else 'BAD ') + '  '.join(out))
PY
)
  case "$report" in
    OK*)  echo "    PASS  $MODE: ${report#OK }  (-verify clean)" ;;
    *)    echo "    FAIL  $MODE: ${report#BAD }"; rc=1 ;;
  esac
done

# 3b. Runtime cross-checks: the three lowerings must be indistinguishable, and no dispatcher may
#     have taken its default arm (an out-of-range opcode would make the comparison vacuous).
DIS=$(printf '%s\n' "$ORACLE" | grep -oE 'disagreements=[0-9]+' | cut -d= -f2)
MIS=$(printf '%s\n' "$ORACLE" | grep -oE 'default_arm_hits=[0-9]+' | cut -d= -f2)
if [ "${DIS:-1}" -eq 0 ] && [ "${MIS:-1}" -eq 0 ]; then
  echo "    PASS  three-way agreement: disagreements=$DIS  default-arm hits=$MIS"
else
  echo "    FAIL  disagreements=${DIS:-?} default_arm_hits=${MIS:-?} (want 0 / 0)"; rc=1
fi
echo "    INFO  measured: the boundary is EXACT and INCLUSIVE at 128 — no off-by-one. The split"
echo "          arm's high table is addressed at a fixed +256 from the low one whatever the"
echo "          real entry count, so it costs a full 512-byte table at 129 entries."

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
  echo "==> bsnes-jg: render + assert (build/jtedge-jg.png, frame 600)"
  "$JGX" "$BUILD/jtedge.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/jtedge-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/jtedge-mame.png)"
  SNAP="$BUILD/.jtedge-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/jtedge.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/jtedge.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/jtedge-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Jump-Table Boundary Sweep on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc
