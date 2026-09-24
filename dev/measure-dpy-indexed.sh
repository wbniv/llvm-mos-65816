#!/usr/bin/env bash
# dev/measure-dpy-indexed.sh — Phase 1 measurement for `[dp],Y` (b7/97), indirect-long indexed.
#
# Reproduces every byte count quoted in
#   docs/investigations/2026-09-24-dpy-indexed-measurement.md
#
# What it does:
#   1. SNES-corpus census — scans every prebuilt *.sfc.elf under $BUILD for genuine
#      b7/97/9f selections (the audit's open "does it fire outside examples/65816?" question).
#   2. Compiles dev/dpy-shapes/{red.c,loop.c} with the real toolchain (+mos-a16, +mos-xy16)
#      and prints the .text size of each function -> the "current codegen" column.
#   3. Assembles the hand-built shapes dev/dpy-shapes/*.s with llvm-mc and prints their
#      sizes -> the "[dp],Y" and "add hoisted, no index" columns.
#
# HOST-ONLY (no Docker, no container): uses build/llvm-mos-install directly.
# Override with CLANG=/path/to/mos-clang MC=... OBJDUMP=... when running from a worktree
# that has no build/ of its own.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: dev/measure-dpy-indexed.sh [-h|--help]

Re-runs the Phase 1 `[dp],Y` (b7/97) byte measurement. No arguments.

Environment overrides:
  ROOT     repo root            (default: the script's parent directory)
  BUILD    build dir to scan    (default: $ROOT/build)
  CLANG    mos-clang            (default: $BUILD/llvm-mos-install/bin/mos-clang)
  MC       llvm-mc              (default: $BUILD/llvm-mos-install/bin/llvm-mc)
  OBJDUMP  llvm-objdump         (default: $BUILD/llvm-mos-install/bin/llvm-objdump)
  ELFDIR   dir of *.sfc.elf for the corpus census (default: $BUILD)
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
SHAPES="$ROOT/dev/dpy-shapes"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for t in "$CLANG" "$MC" "$OBJDUMP"; do
  [ -x "$t" ] || { echo "FATAL: missing tool $t (set CLANG/MC/OBJDUMP)"; exit 1; }
done

A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-xy16)

# --- 1. corpus census -------------------------------------------------------
echo "==> 1) SNES-corpus census: genuine b7/97/9f selections in prebuilt ROMs"
elfs=$(ls "$ELFDIR"/*.elf 2>/dev/null || true)
if [ -z "$elfs" ]; then
  echo "  SKIP: no *.elf under $ELFDIR"
else
  echo "  scanning $(echo "$elfs" | wc -l) ROM images"
  hits=0
  for f in $elfs; do
    # A hit BEFORE the first <main> is header/preamble disassembly desync, not codegen.
    n=$("$OBJDUMP" -d "$f" 2>/dev/null | awk '
      /<main>:/ { past=1 }
      past && /^[ \t]*[0-9a-f]+:[ \t]/ && ($2=="b7"||$2=="97"||$2=="9f") { c++ }
      END { print c+0 }')
    [ "$n" -gt 0 ] && { echo "  HIT $n  $(basename "$f")"; hits=$((hits+n)); }
  done
  echo "  genuine (post-<main>) b7/97/9f selections: $hits"
fi

# --- 2. current codegen -----------------------------------------------------
echo "==> 2) current codegen sizes (dev/dpy-shapes/*.c)"
fnsize() { # $1=object  -> prints "<section> <bytes>" per .text.*
  "$OBJDUMP" -h "$1" | while read -r _idx name size _rest; do
    case "$name" in .text.*) printf "     %-24s %d bytes\n" "$name" "$((16#$size))" ;; esac
  done
}
"$CLANG" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$TMP/red.o"  "$SHAPES/red.c"
echo "   red.c  (+mos-a16):"; fnsize "$TMP/red.o"
"$CLANG" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$TMP/loop.o" "$SHAPES/loop.c"
echo "   loop.c (+mos-a16):"; fnsize "$TMP/loop.o"
"$CLANG" --target=mos -mcpu=mosw65816 "${A16[@]}" "${XY16[@]}" -Os -c -o "$TMP/loopxy.o" "$SHAPES/loop.c"
echo "   loop.c (+mos-a16 +mos-xy16):"; fnsize "$TMP/loopxy.o"

# --- 3. hand-built shapes ---------------------------------------------------
echo "==> 3) hand-built shape sizes (dev/dpy-shapes/*.s)"
for s in "$SHAPES"/*.s; do
  b=$(basename "$s" .s)
  "$MC" -triple mos -mcpu=mosw65816 -filetype=obj -o "$TMP/$b.o" "$s"
  # `|| true`: the while-loop's last iteration exits non-zero when the line isn't .text,
  # which would propagate through the command substitution under `set -e`.
  sz=$("$OBJDUMP" -h "$TMP/$b.o" | while read -r _i n v _r; do
         [ "$n" = ".text" ] && printf "%d" "$((16#$v))"
       done || true)
  printf "     %-24s %d bytes\n" "$b" "$sz"
done

echo "==> done. Interpretation + the cycle table: docs/investigations/2026-09-24-dpy-indexed-measurement.md"
