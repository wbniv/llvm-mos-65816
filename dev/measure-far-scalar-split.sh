#!/usr/bin/env bash
# dev/measure-far-scalar-split.sh -- Phase 1 measurement: why a far (address_space(2)) 16-bit scalar
# access is byte-split under +mos-a16, how often it happens, and what a single M=0 access wins.
#
# Reproduces every number in docs/investigations/2026-09-25-far-scalar-split-measurement.md.
#   1. root cause   -- MIR after the Legalizer for `x ^ fg`: the s16 G_LOAD(p2) is already 2x s8
#                      G_LOAD_FAR_ABS there (legalizeLoadStore16 only takes the native arm for a
#                      16-bit pointer; a p2 pointer falls to narrowScalar(s8)).
#   2. census       -- (a) exact: every far i16/i32 load/store in optimized IR, SNES + corpus +
#                      examples/65816; (b) shape: byte-split far pairs in the objects
#                      (dev/far-scalar-split/census.py), +mos-a16 and +mos-xy16.
#   3. current      -- dev/far-scalar-split/shapes.c in a16 / xy16 / both with -enable-misched=false.
#   4. M=0 target   -- (a) far-GLOBAL shapes: the same source compiled NEAR (FAR empty, extern) --
#                      the native s16 pipeline's output, which the MC layer relaxes to the exact
#                      long-addressed bytes an explicit M=0 far form would have; (b) hand-built
#                      dev/far-scalar-split/m0/*.s (minimal edits of the compiler's own -S output).
#   5. hazards      -- which near native s16 forms use a 16-bit DBR-relative operand (no long form).
#   6. bank seam    -- BANKCROSS=1 runs dev/far-scalar-split/bankcross.sh (bsnes-jg + MAME).
# Sizes/cycles: dev/longx-shapes/cycles.py (static W65C816S estimate; model in its header).
#
# HOST-ONLY except step 6's MAME leg (dev/container.sh). Override CLANG/MC/OBJDUMP/INSTALL when
# running from a worktree with no build/.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: dev/measure-far-scalar-split.sh [-h|--help]

Re-runs the far 16-bit scalar byte-split Phase 1 measurement. No arguments.

Environment overrides:
  ROOT       repo root            (default: the script's parent directory)
  BUILD      build dir            (default: $ROOT/build)
  CLANG      mos-clang            (default: $BUILD/llvm-mos-install/bin/mos-clang)
  MC         llvm-mc              (default: $BUILD/llvm-mos-install/bin/llvm-mc)
  OBJDUMP    llvm-objdump         (default: $BUILD/llvm-mos-install/bin/llvm-objdump)
  INSTALL    SDK install dir      (default: $BUILD/install; needs bin/mos-snes.cfg)
  GENDIR     generated SNES asset headers (default: $BUILD; apollo-reel-assets.h etc.)
  BANKCROSS  1 = also run the emulator bank-seam probe (step 6)
EOF
  exit 0
}
case "${1:-}" in -h|--help) usage ;; esac

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BUILD="${BUILD:-$ROOT/build}"
CLANG="${CLANG:-$BUILD/llvm-mos-install/bin/mos-clang}"
MC="${MC:-$BUILD/llvm-mos-install/bin/llvm-mc}"
OBJDUMP="${OBJDUMP:-$BUILD/llvm-mos-install/bin/llvm-objdump}"
INSTALL="${INSTALL:-$BUILD/install}"
GENDIR="${GENDIR:-$BUILD}"
FS="$ROOT/dev/far-scalar-split"
CYC=(python3 "$ROOT/dev/longx-shapes/cycles.py")
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for t in "$CLANG" "$MC" "$OBJDUMP"; do
  [ -x "$t" ] || { echo "FATAL: missing tool $t (set CLANG/MC/OBJDUMP)"; exit 1; }
done
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: no $INSTALL/bin/mos-snes.cfg (set INSTALL)"; exit 1; }

A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-xy16)
NOMS=(-mllvm -enable-misched=false)
SNESINC=(-I"$ROOT/examples/65816" -I"$ROOT/examples/snes" -I"$GENDIR" -I"$GENDIR/seamdemo-gen")
mode_flags() { # $1 = a16|xy16|a16-nm|xy16-nm -> FLAGS array
  case $1 in
    a16) FLAGS=("${A16[@]}") ;; xy16) FLAGS=("${A16[@]}" "${XY16[@]}") ;;
    a16-nm) FLAGS=("${A16[@]}" "${NOMS[@]}") ;; xy16-nm) FLAGS=("${A16[@]}" "${XY16[@]}" "${NOMS[@]}") ;;
  esac
}
x16_of() { case $1 in xy16*) echo --x16 ;; esac; }

echo "toolchain: $(readlink -f "$CLANG")  sha256 $(sha256sum "$(dirname "$CLANG")/clang-23" 2>/dev/null | cut -c1-16)"

# --- 1. root cause ------------------------------------------------------------------------
echo "==> 1) root cause: MIR for xe() after IRTranslator and after Legalizer (+mos-a16)"
"$CLANG" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o /dev/null "$FS/shapes.c" \
  -mllvm -print-after=irtranslator -mllvm -print-after=legalizer -mllvm -filter-print-funcs=xe 2> "$TMP/mir.txt" || true
grep -E "IR Dump After|G_LOAD|G_LOAD_FAR_ABS|G_MERGE_VALUES %[0-9]+:_\(s8\), %[0-9]+:_\(s8\)$" "$TMP/mir.txt" \
  | grep -vE "COPY" | sed 's/^/    /' | head -12

# --- 2. census ----------------------------------------------------------------------------
echo "==> 2a) exact census: far (addrspace 2) i16/i32 loads+stores in optimized IR (+mos-a16)"
mkdir -p "$TMP/ll"
nok=0; nfail=0
for c in "$ROOT"/examples/snes/*.c "$ROOT"/examples/snes/corpus/*.c; do
  b=$(basename "$c" .c)
  if "$CLANG" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Oz -fno-lto "${SNESINC[@]}" \
       -S -emit-llvm -o "$TMP/ll/snes_$b.ll" "$c" 2>/dev/null; then nok=$((nok+1)); else nfail=$((nfail+1)); fi
done
for c in "$ROOT"/examples/65816/*.c "$ROOT"/examples/65816/*/*.c; do
  b=$(basename "$c" .c)
  if "$CLANG" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -I"$ROOT/examples/65816" \
       -S -emit-llvm -o "$TMP/ll/ex_$b.ll" "$c" 2>/dev/null; then nok=$((nok+1)); else nfail=$((nfail+1)); fi
done
echo "    translation units: $nok compiled, $nfail failed to compile (skipped)"
python3 - "$TMP/ll" <<'PY'
import collections, os, re, sys
d = sys.argv[1]
pat = re.compile(r'\b(load|store)\s+(?:volatile\s+)?(\S+(?: addrspace\(\d\))?)\s*(?:%[^,]*)?,\s*ptr addrspace\(2\)\s*(\S)')
C, F = collections.Counter(), collections.Counter()
for f in sorted(os.listdir(d)):
    for line in open(os.path.join(d, f)):
        m = pat.search(line)
        if not m:
            continue
        op, ty, base = m.groups()
        kind = "global" if base == "@" or "getelementptr" in line.split("ptr addrspace(2)")[-1][:40] else "runtime-ptr"
        C[(op, ty, kind)] += 1
        if ty in ("i16", "i32"):
            F[(f[:-3], op, ty, kind)] += 1
print("    all far accesses (op width base):")
for k, v in sorted(C.items()):
    print(f"      {v:4d}  {' '.join(k)}")
print("    i16/i32 far accesses by translation unit:")
for k, v in sorted(F.items()):
    print(f"      {v:4d}  {' '.join(k)}")
PY

echo "==> 2b) shape census: byte-split far pairs in objects (dev/far-scalar-split/census.py)"
mkdir -p "$TMP/o"
for mode in a16 xy16; do
  mode_flags $mode; : > "$TMP/census.$mode"
  for c in "$ROOT"/examples/snes/*.c "$ROOT"/examples/snes/corpus/*.c; do
    b=$(basename "$c" .c)
    "$CLANG" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${FLAGS[@]}" -Oz -fno-lto "${SNESINC[@]}" \
      -c -o "$TMP/o/$b.o" "$c" 2>/dev/null || continue
    "$OBJDUMP" -dr "$TMP/o/$b.o" | python3 "$FS/census.py" "snes:$b" >> "$TMP/census.$mode"
  done
  for c in "$ROOT"/examples/65816/*.c "$ROOT"/examples/65816/*/*.c; do
    b=$(basename "$c" .c)
    "$CLANG" --target=mos -mcpu=mosw65816 "${FLAGS[@]}" -Os -I"$ROOT/examples/65816" -c -o "$TMP/o/$b.o" "$c" 2>/dev/null || continue
    "$OBJDUMP" -dr "$TMP/o/$b.o" | python3 "$FS/census.py" "ex:$b" >> "$TMP/census.$mode"
  done
  echo "    $mode: $(wc -l < "$TMP/census.$mode") byte-split sites"
  awk '{print "      ",$1,$2,$3,$4}' "$TMP/census.$mode" | sort | uniq -c
done

# --- 3 + 4a. current vs near-analog (the M=0 far-global target) ----------------------------
echo "==> 3/4a) current far codegen vs NEAR analog (= M=0 far-global target), -Os"
sed -e 's/^#define FAR .*/#define FAR/' "$FS/shapes.c" > "$TMP/near.c"
for mode in a16 xy16 a16-nm xy16-nm; do
  mode_flags $mode
  "$CLANG" --target=mos -mcpu=mosw65816 "${FLAGS[@]}" -Os -c -o "$TMP/far.o" "$FS/shapes.c"
  "$CLANG" --target=mos -mcpu=mosw65816 "${FLAGS[@]}" -Os -c -o "$TMP/near.o" "$TMP/near.c"
  echo "  -- $mode   (current far)"
  "$OBJDUMP" -dr "$TMP/far.o" | "${CYC[@]}" $(x16_of $mode)
  echo "  -- $mode   (near analog; only the global-scalar rows xe/tick/mixv/mixh/ldr/str are the far M=0 target)"
  "$OBJDUMP" -dr "$TMP/near.o" | "${CYC[@]}" $(x16_of $mode) | grep -E "^\s+(xe|tick|mixv|mixh|ldr|str)\s"
done

# --- 4b. hand-built M=0 shapes ------------------------------------------------------------
echo "==> 4b) hand-built M=0 shapes (dev/far-scalar-split/m0/*.s)"
for x in "" --x16; do
  echo "  -- ${x:-X=8}"
  for s in "$FS"/m0/*.s; do
    "$MC" -triple mos -mcpu=mosw65816 -filetype=obj -o "$TMP/h.o" "$s"
    "$OBJDUMP" -dr "$TMP/h.o" | "${CYC[@]}" $x
  done
done

# --- 5. hazards ---------------------------------------------------------------------------
echo "==> 5) native s16 forms with a 16-bit (DBR-relative) operand, near analog (hazard.c, FAR empty)"
for mode in a16 xy16; do
  mode_flags $mode
  "$CLANG" --target=mos -mcpu=mosw65816 "${FLAGS[@]}" -DFAR= -Os -c -o "$TMP/hz.o" "$FS/hazard.c"
  echo "  -- $mode: R_MOS_ADDR16 operands on hc/hn"
  "$OBJDUMP" -dr "$TMP/hz.o" | python3 "$FS/symops.py" hc,hn | grep ADDR16 | sed 's/^/    /' || true
done

# --- 6. bank seam -------------------------------------------------------------------------
if [ "${BANKCROSS:-}" = "1" ]; then
  echo "==> 6) bank seam (\$7EFFFF|\$7F0000) on bsnes-jg + MAME"
  ROOT="$ROOT" BUILD="$BUILD" "$FS/bankcross.sh"
else
  echo "==> 6) bank seam: SKIP (BANKCROSS=1 runs dev/far-scalar-split/bankcross.sh)"
fi
echo "==> done. Interpretation: docs/investigations/2026-09-25-far-scalar-split-measurement.md"
