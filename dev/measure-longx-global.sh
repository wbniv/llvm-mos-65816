#!/usr/bin/env bash
# dev/measure-longx-global.sh — Phase 1 measurement for `long,X` (bf/9f) on a far GLOBAL base plus a
# runtime index, and the long-form ALU opcodes (0f/2f/4f/6f/cf/ef + their ,X forms).
#
# Reproduces every number quoted in
#   docs/investigations/2026-09-25-longx-global-measurement.md
#
# What it does:
#   1. SNES-corpus census — every opcode byte bf/9f/long-ALU in every prebuilt *.elf under $ELFDIR,
#      attributed to the enclosing symbol (NOT filtered to post-<main>: code laid out before <main>
#      would be missed). Classification of the hits (hand-written .s / inline asm / disassembly
#      desync) is in the doc; the script prints the per-symbol tally it is based on.
#   2. examples/65816/*.c census in default, +mos-a16, +mos-a16 +mos-xy16 (the #320 audit's census).
#   3. Current codegen for dev/longx-shapes/{single,loop}.c in +mos-a16, +mos-xy16, and both again
#      with -enable-misched=false (isolates the pre-RA scheduler carry-pressure cliff).
#   4. Hand-built long,X shapes dev/longx-shapes/*.s assembled with llvm-mc.
#   Sizes + cycles come from dev/longx-shapes/cycles.py (static W65C816S estimate; model in its header).
#
# HOST-ONLY (no Docker). Override CLANG/MC/OBJDUMP when running from a worktree with no build/.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: dev/measure-longx-global.sh [-h|--help]

Re-runs the Phase 1 `long,X` (bf/9f) + long-form-ALU measurement. No arguments.

Environment overrides:
  ROOT     repo root            (default: the script's parent directory)
  BUILD    build dir            (default: $ROOT/build)
  CLANG    mos-clang            (default: $BUILD/llvm-mos-install/bin/mos-clang)
  MC       llvm-mc              (default: $BUILD/llvm-mos-install/bin/llvm-mc)
  OBJDUMP  llvm-objdump         (default: $BUILD/llvm-mos-install/bin/llvm-objdump)
  ELFDIR   dir of *.elf for the corpus census (default: $BUILD)
EOF
  exit 0
}
case "${1:-}" in -h|--help) usage ;; esac

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BUILD="${BUILD:-$ROOT/build}"
CLANG="${CLANG:-$BUILD/llvm-mos-install/bin/mos-clang}"
MC="${MC:-$BUILD/llvm-mos-install/bin/llvm-mc}"
OBJDUMP="${OBJDUMP:-$BUILD/llvm-mos-install/bin/llvm-objdump}"
ELFDIR="${ELFDIR:-$BUILD}"
SHAPES="$ROOT/dev/longx-shapes"
CYC=(python3 "$SHAPES/cycles.py")
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for t in "$CLANG" "$MC" "$OBJDUMP"; do
  [ -x "$t" ] || { echo "FATAL: missing tool $t (set CLANG/MC/OBJDUMP)"; exit 1; }
done

A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-xy16)
NOMS=(-mllvm -enable-misched=false)
OPS='^(bf|9f|0f|2f|4f|6f|cf|ef|1f|3f|5f|7f|df|ff)$'

census() { # stdin: objdump -d ; $1 = label -> "label symbol opcode" per hit
  awk -v lab="$1" -v ops="$OPS" '
    /^[0-9a-f]+ <[^>]+>:/ { fn=$2; gsub(/[<>:]/,"",fn); next }
    /^[ \t]*[0-9a-f]+:[ \t]/ && $2 ~ ops { print lab, fn, $2 }'
}

# --- 1. SNES corpus census ------------------------------------------------------------------
echo "==> 1) SNES-corpus census: bf/9f/long-ALU opcode bytes in prebuilt ROM images"
elfs=$(ls "$ELFDIR"/*.elf 2>/dev/null || true)
if [ -z "$elfs" ]; then
  echo "  SKIP: no *.elf under $ELFDIR"
else
  echo "  scanning $(echo "$elfs" | wc -l) ROM images"
  for f in $elfs; do "$OBJDUMP" -d "$f" 2>/dev/null | census "$(basename "$f")"; done > "$TMP/census.txt"
  echo "  total opcode-byte hits: $(wc -l < "$TMP/census.txt")"
  echo "  by opcode:  $(awk '{print $3}' "$TMP/census.txt" | sort | uniq -c | tr -s ' \n' ' ')"
  echo "  by enclosing symbol:"
  awk '{print $2}' "$TMP/census.txt" | sort | uniq -c | sort -rn | sed 's/^/    /'
fi

# --- 2. examples/65816 census ---------------------------------------------------------------
echo "==> 2) examples/65816/*.c census (the #320 audit's corpus)"
for mode in default a16 xy16; do
  case $mode in default) F=() ;; a16) F=("${A16[@]}") ;; xy16) F=("${A16[@]}" "${XY16[@]}") ;; esac
  ok=0; : > "$TMP/ex.$mode"
  for c in "$ROOT"/examples/65816/*.c; do
    b=$(basename "$c" .c)
    "$CLANG" --target=mos -mcpu=mosw65816 ${F[@]+"${F[@]}"} -Os -c -o "$TMP/$b.o" "$c" 2>/dev/null || continue
    ok=$((ok+1))
    "$OBJDUMP" -d "$TMP/$b.o" | census "$b" >> "$TMP/ex.$mode"
  done
  printf "  %-8s compiled %3d  hits: %s\n" "$mode" "$ok" \
    "$(awk '{print $1":"$3}' "$TMP/ex.$mode" | sort | uniq -c | tr -s ' \n' ' ')"
done

# --- 3. current codegen ---------------------------------------------------------------------
echo "==> 3) current codegen (dev/longx-shapes/{single,loop}.c, -Os)"
for mode in a16 xy16 a16-nomisched xy16-nomisched; do
  case $mode in
    a16) F=("${A16[@]}") ;; xy16) F=("${A16[@]}" "${XY16[@]}") ;;
    a16-nomisched) F=("${A16[@]}" "${NOMS[@]}") ;; xy16-nomisched) F=("${A16[@]}" "${XY16[@]}" "${NOMS[@]}") ;;
  esac
  echo "  -- $mode"
  for s in single loop; do
    "$CLANG" --target=mos -mcpu=mosw65816 "${F[@]}" -Os -c -o "$TMP/$s.o" "$SHAPES/$s.c"
    "$OBJDUMP" -dr "$TMP/$s.o" | "${CYC[@]}"
  done
done

# --- 4. hand-built shapes -------------------------------------------------------------------
echo "==> 4) hand-built shapes (dev/longx-shapes/*.s)"
for s in "$SHAPES"/*.s; do
  "$MC" -triple mos -mcpu=mosw65816 -filetype=obj -o "$TMP/h.o" "$s"
  "$OBJDUMP" -dr "$TMP/h.o" | "${CYC[@]}"
done

echo "==> done. Interpretation: docs/investigations/2026-09-25-longx-global-measurement.md"
