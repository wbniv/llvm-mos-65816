#!/usr/bin/env bash
# dev/probe-far-roundtrip.sh — does compiler-emitted 65816 far / 24-bit assembly
# survive a `-S`-then-reassemble round trip?
#
# For every fixture, compile twice with the SAME clang:
#   (a) `-c`  -> object straight from the integrated code emitter   (the reference)
#   (b) `-S`  -> .s, then assemble that .s with a standalone llvm-mc (the round trip)
# and compare the resulting .text bytes. Any divergence is a parser/printer
# asymmetry: the same program means two different things depending on whether it
# ever passed through text. (This is the class of defect patch 0039 fixed for
# `mos16(constant)` / `mos24(constant)`.)
#
# Pass --mc to point at a specific assembler so the same corpus can be run
# against a pre-fix and a fixed llvm-mc and the two compared.
#
# Host-side, compile-only: no container, no emulator, no SDK platform needed.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: dev/probe-far-roundtrip.sh [--cc PATH] [--mc PATH] [--objdump PATH]
                                  [--cpu CPU] [--flags "..."] [-v] [FIXTURE...]

  --cc      mos-clang to compile with   (default: build/llvm-mos-install/bin/mos-clang)
  --mc      llvm-mc to reassemble with  (default: build/llvm-mos-install/bin/llvm-mc)
  --objdump llvm-objdump               (default: alongside --cc)
  --cpu     -mcpu value                 (default: mosw65816)
  --flags   extra clang flags           (default: "-Os")
  -v        print the diverging bytes for each mismatch
  FIXTURE   .c/.s paths; default = examples/65816/far*.c + packed24 fixtures

Exit 0 when every fixture round-trips byte-identically, 1 otherwise.
EOF
  exit 0
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CC="$ROOT/build/llvm-mos-install/bin/mos-clang"
MC=""
OBJDUMP=""
CPU="mosw65816"
FLAGS="-Os"
VERBOSE=0
FIXTURES=()

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage ;;
    --cc) CC="$2"; shift 2 ;;
    --mc) MC="$2"; shift 2 ;;
    --objdump) OBJDUMP="$2"; shift 2 ;;
    --cpu) CPU="$2"; shift 2 ;;
    --flags) FLAGS="$2"; shift 2 ;;
    -v) VERBOSE=1; shift ;;
    *) FIXTURES+=("$1"); shift ;;
  esac
done

BIN="$(dirname "$CC")"
[ -n "$MC" ] || MC="$BIN/llvm-mc"
[ -n "$OBJDUMP" ] || OBJDUMP="$BIN/llvm-objdump"

for t in "$CC" "$MC" "$OBJDUMP"; do
  [ -x "$t" ] || { echo "FATAL: not executable: $t" >&2; exit 2; }
done

if [ ${#FIXTURES[@]} -eq 0 ]; then
  while IFS= read -r f; do FIXTURES+=("$f"); done < <(
    # shellcheck disable=SC2012  # fixture names are plain ASCII
    ls "$ROOT"/examples/65816/far*.c "$ROOT"/examples/65816/packed24/*.c 2>/dev/null | sort -u
  )
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# .text bytes only: strip the objdump header (which carries the temp filename)
# and the symbolic comment column, keeping opcode bytes + mnemonic.
textbytes() {
  "$OBJDUMP" -d --triple=mos "--mcpu=$CPU" "$1" 2>/dev/null \
    | sed -e '1,/Disassembly of section .text/d' -e 's/;.*$//' -e 's/[[:space:]]*$//' \
    | grep -E '^[[:space:]]*[0-9a-f]+:' || true
}

pass=0; fail=0; skip=0; failed=()
for src in "${FIXTURES[@]}"; do
  name="$(basename "$src")"
  obj_direct="$TMP/$name.direct.o"
  asm="$TMP/$name.s"
  obj_rt="$TMP/$name.rt.o"

  # shellcheck disable=SC2086
  if ! "$CC" --target=mos "-mcpu=$CPU" $FLAGS -c -o "$obj_direct" "$src" >"$TMP/err" 2>&1; then
    echo "SKIP  $name  (does not compile: $(head -1 "$TMP/err"))"
    skip=$((skip+1)); continue
  fi
  # shellcheck disable=SC2086
  "$CC" --target=mos "-mcpu=$CPU" $FLAGS -S -o "$asm" "$src" >/dev/null 2>&1

  if ! "$MC" -triple mos "-mcpu=$CPU" -filetype=obj -o "$obj_rt" "$asm" >"$TMP/err" 2>&1; then
    echo "FAIL  $name  (reassembly rejected the compiler's own output)"
    [ "$VERBOSE" = 1 ] && { sed 's/^/        /' "$TMP/err" | head -10; } || true
    fail=$((fail+1)); failed+=("$name:reassembly-error"); continue
  fi

  textbytes "$obj_direct" > "$TMP/a.txt"
  textbytes "$obj_rt"     > "$TMP/b.txt"

  if diff -q "$TMP/a.txt" "$TMP/b.txt" >/dev/null; then
    pass=$((pass+1))
    [ "$VERBOSE" = 1 ] && echo "ok    $name  ($(wc -l < "$TMP/a.txt") insns)" || true
  else
    # `diff` exits 1 on difference; under `pipefail` that would abort the sweep.
    n=$({ diff "$TMP/a.txt" "$TMP/b.txt" || true; } | grep -cE '^[<>]' || true)
    echo "FAIL  $name  ($n diverging lines: -c object vs .s reassembled)"
    fail=$((fail+1)); failed+=("$name:$n")
    if [ "$VERBOSE" = 1 ]; then
      { diff "$TMP/a.txt" "$TMP/b.txt" || true; } | head -20 | sed 's/^/        /'
    fi
  fi
done

echo
echo "cc=$CC"
echo "mc=$MC"
echo "round-trip: $pass identical, $fail divergent, $skip skipped"
if [ $fail -gt 0 ]; then
  printf '  divergent: %s\n' "${failed[@]}"
  exit 1
fi
exit 0
