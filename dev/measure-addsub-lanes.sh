#!/usr/bin/env bash
# measure-addsub-lanes.sh - census of multi-byte add/sub carry chains under +mos-a16.
#
# Phase A of the "does G_ADD/G_SUB miss 16-bit lanes under +mos-a16?" investigation
# (docs/investigations/2026-08-04-g-add-sub-s16-lanes.md).
#
# Under +mos-a16, legalizeAddSub passes s16 G_ADD/G_SUB through to selectAlu16Native
# (native 16-bit ADC/SBC on A16). Wider scalars have NO maxScalar, so they fall to
# Helper.narrowScalarAddSub(MI, 0, S8) -> an N-lane 8-bit G_UADDE/G_SBC carry chain,
# identical to the default (non-a16) build. This script measures the population and
# shape of those chains so the size prize of a 2x s16 lane form can be costed BEFORE
# any backend change (project lesson 1: measure, don't assume).
#
# Per chain it records the lane count and the DEFINING OPCODE of every byte operand,
# because that is what decides whether a 16-bit lane would win (project lesson 2: a
# native 16-bit op routes operands through Imag16 + a rep/sep bracket and LOSES when
# the operand is already register-resident or consumed as bytes).
#
# Host-only: uses the prebuilt mos-clang, makes NO vendor/ edits, runs no emulator.
# Env overrides: CLANG, OBJDUMP (default $ROOT/build/llvm-mos-install/bin/...).
#
# Usage: dev/measure-addsub-lanes.sh [-h|--help] [SRC ...]
#   With no SRC arguments, sweeps examples/snes/corpus/*.c.

set -euo pipefail

usage() {
  cat <<'EOF'
measure-addsub-lanes.sh - multi-byte add/sub carry-chain census (+mos-a16 -Os)

Sweeps the corpus (or the given .c files), compiles each with +mos-a16 -Os, dumps
post-legalize MIR, and reports every G_UADDE / G_SBC carry chain: its lane count and
the defining opcodes of its byte operands. Also reports per-slice .text bytes and the
count of emitted 8-bit adc/sbc instructions.

Env overrides: CLANG, OBJDUMP (default $ROOT/build/llvm-mos-install/bin/...).
Usage: dev/measure-addsub-lanes.sh [-h|--help] [SRC ...]
EOF
}
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLANG="${CLANG:-$ROOT/build/llvm-mos-install/bin/mos-clang}"
OBJDUMP="${OBJDUMP:-$ROOT/build/llvm-mos-install/bin/llvm-objdump}"
[[ -x "$CLANG" ]] || { echo "FATAL: no toolchain at $CLANG (set CLANG=)" >&2; exit 1; }

A16=(--target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os)
BASE=(--target=mos -mcpu=mosw65816 -Os)

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

srcs=("$@")
if [[ ${#srcs[@]} -eq 0 ]]; then
  mapfile -t srcs < <(find "$ROOT/examples/snes/corpus" -maxdepth 1 -name '*.c' | sort)
fi

# Emit "<slice>\t<a16_text_bytes>\t<base_text_bytes>\t<a16_adc>\t<a16_sbc>" plus the raw
# MIR, which the python pass below turns into the chain census.
: > "$tmp/sizes.tsv"
for src in "${srcs[@]}"; do
  name="$(basename "$src" .c)"
  if ! "$CLANG" "${A16[@]}" -c "$src" -o "$tmp/$name.a16.o" 2>/dev/null; then
    echo -e "$name\tCRASH-a16\t-\t-\t-" >> "$tmp/sizes.tsv"; continue
  fi
  "$CLANG" "${BASE[@]}" -c "$src" -o "$tmp/$name.base.o" 2>/dev/null || true
  "$CLANG" "${A16[@]}" -mllvm -print-after=legalizer -c "$src" -o /dev/null \
    2> "$tmp/$name.mir" || true

  # llvm-objdump prints section sizes in hex; mawk has no strtonum, so sum in bash.
  text_bytes() {
    local total=0 sz
    while read -r _ nm sz _; do
      case "$nm" in .text*) total=$(( total + 16#$sz ));; esac
    done < <("$OBJDUMP" --section-headers "$1" 2>/dev/null)
    echo "$total"
  }
  a16b=$(text_bytes "$tmp/$name.a16.o")
  baseb=0
  [[ -f "$tmp/$name.base.o" ]] && baseb=$(text_bytes "$tmp/$name.base.o")
  nadc=$("$OBJDUMP" -d --mcpu=mosw65816 "$tmp/$name.a16.o" 2>/dev/null | grep -cE '\badc\b' || true)
  nsbc=$("$OBJDUMP" -d --mcpu=mosw65816 "$tmp/$name.a16.o" 2>/dev/null | grep -cE '\bsbc\b' || true)
  echo -e "$name\t${a16b:-0}\t${baseb:-0}\t$nadc\t$nsbc" >> "$tmp/sizes.tsv"
done

MIRDIR="$tmp" SIZES="$tmp/sizes.tsv" python3 - <<'PY'
import os, re, glob, collections

mirdir = os.environ["MIRDIR"]
sizes = {}
for line in open(os.environ["SIZES"]):
    f = line.rstrip("\n").split("\t")
    sizes[f[0]] = f[1:]

# A post-legalize MIR line for a carry-chain lane, e.g.
#   %24:_(s8), %25:_(s1) = G_UADDE %33:_, %43:_, %32:_
LANE = re.compile(
    r'^\s*%(\d+):_\(s8\),\s*%(\d+):_\(s1\)\s*=\s*(G_UADDE|G_SADDE|G_USUBE|G_SSUBE|G_SBC)\s+(.*)$')
DEF  = re.compile(r'^\s*(%\d+):_(?:\([^)]*\))?(?:,\s*%\d+:_\([^)]*\))*\s*=\s*([A-Za-z_0-9]+)')
REG  = re.compile(r'%(\d+)')

rows = []            # (slice, func, lanes, operand-opcode multiset)
per_slice = collections.Counter()

for path in sorted(glob.glob(os.path.join(mirdir, "*.mir"))):
    name = os.path.basename(path)[:-4]
    func = "?"
    defop = {}       # vreg -> defining opcode
    lanes = {}       # carry-out vreg -> (dst, opcode, [use regs])
    order = []
    for line in open(path, errors="replace"):
        m = re.match(r'^# Machine code for function (\S+):', line)
        if m: func = m.group(1)
        d = DEF.match(line)
        if d:
            # record every def in the line
            head = line.split('=')[0]
            op = d.group(2)
            for r in REG.findall(head):
                defop[r] = op
        m = LANE.match(line)
        if m:
            dst, cout, opc, uses = m.groups()
            useregs = REG.findall(uses)
            lanes[cout] = (dst, opc, useregs, func)
            order.append(cout)

    # Stitch chains: lane L follows lane K when L's carry-in use == K's carry-out.
    cout_set = set(lanes)
    succ = {}
    roots = []
    for cout, (dst, opc, useregs, fn) in lanes.items():
        carry_in = useregs[-1] if useregs else None
        if carry_in in cout_set:
            succ[carry_in] = cout
        else:
            roots.append(cout)
    for r in roots:
        chain = []
        cur = r
        seen = set()
        while cur is not None and cur not in seen:
            seen.add(cur)
            chain.append(cur)
            cur = succ.get(cur)
        opnd_ops = collections.Counter()
        opc = lanes[chain[0]][1]
        fn = lanes[chain[0]][3]
        for c in chain:
            _, _, useregs, _ = lanes[c]
            for u in useregs[:-1]:          # skip the carry operand
                opnd_ops[defop.get(u, "?")] += 1
        rows.append((name, fn, len(chain), opc, opnd_ops))
        per_slice[name] += 1

# ---------------- report ----------------
width = collections.Counter(r[2] for r in rows)
print("=== carry-chain lane-width histogram (all corpus slices, +mos-a16 -Os) ===")
print(f"{'lanes':>6} {'chains':>7} {'meaning':<44} {'lane-bytes':>10}")
mean = {1: "s8 add w/ carry (not a widened add)", 2: "s16 (NOT via native path)",
        3: "s24 / packed far", 4: "s32", 8: "s64"}
for w in sorted(width):
    print(f"{w:>6} {width[w]:>7} {mean.get(w,'other'):<44} {w*width[w]:>10}")
print(f"{'TOTAL':>6} {sum(width.values()):>7} {'':<44} {sum(w*n for w,n in width.items()):>10}")

print()
print("=== chains of width >= 3 (the ones a 2x/4x s16 lane form could replace) ===")
wide = [r for r in rows if r[2] >= 3]
print(f"count={len(wide)} across {len(set(r[0] for r in wide))} slices")
opnd_total = collections.Counter()
for r in wide:
    opnd_total.update(r[4])
print("byte-operand defining opcodes over all wide chains:")
for op, n in opnd_total.most_common(18):
    print(f"   {n:>6}  {op}")

print()
print("=== per-slice: wide chains, .text bytes (a16 / default), adc+sbc count ===")
print(f"{'slice':<22} {'wide':>5} {'w4+':>5} {'a16B':>7} {'defB':>7} {'adc':>5} {'sbc':>5}")
agg = collections.defaultdict(lambda: [0,0])
for r in rows:
    if r[2] >= 3:
        agg[r[0]][0] += 1
        if r[2] >= 4: agg[r[0]][1] += 1
tot = [0,0,0,0,0,0]
for name in sorted(sizes):
    s = sizes[name]
    w, w4 = agg.get(name, [0,0])
    if w == 0 and s[0] not in ("CRASH-a16",):
        pass
    a16b = s[0]; defb = s[1]; adc = s[2] if len(s)>2 else '-'; sbc = s[3] if len(s)>3 else '-'
    if w or (a16b.isdigit() and int(a16b)):
        print(f"{name:<22} {w:>5} {w4:>5} {a16b:>7} {defb:>7} {adc:>5} {sbc:>5}")
    if a16b.isdigit():
        tot[0]+=w; tot[1]+=w4; tot[2]+=int(a16b); tot[3]+=int(defb)
        tot[4]+=int(adc); tot[5]+=int(sbc)
print(f"{'TOTAL':<22} {tot[0]:>5} {tot[1]:>5} {tot[2]:>7} {tot[3]:>7} {tot[4]:>5} {tot[5]:>5}")
PY
