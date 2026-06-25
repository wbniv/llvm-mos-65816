#!/usr/bin/env bash
# dev/corpus-a16.sh — M0/M1 SNES corpus under +mos-a16 (differential).
#
# For each examples/snes/corpus/*.c whose result symbol is corpus_result, assert
#   host(expected) == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == +mos-a16@bsnes-jg
# via the shared differential engine (tools/a16_fuzz.py check). globals.c used to auto-XFAIL
# (regalloc-out-of-registers, a +mos-a16 -Os RA crash) with NO special-casing here, via the
# engine's KNOWN_ISSUES classifier. That signature was FIXED 2026-06-24 by fork patch 0009
# (the i8 small-const inc/dec relocation) and its KNOWN_ISSUES entry removed, so globals.c now
# compiles + runs clean and is asserted as a positive differential gate like the rest. Closes
# the "corpus only ever built default 8-bit" gap (the gap that hid the globals.c crash).
# Prints a table + "N/N passed, X xfail"; exits nonzero if any program FAILs. Runs INSIDE
# the dev container; drive from host: dev/run.sh corpus-a16. Build first (toolchain + build).
set -euo pipefail

usage() { echo "Usage: dev/run.sh corpus-a16   # examples/snes/corpus/*.c under +mos-a16 (differential, vs expected.tsv)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
MANIFEST="$ROOT/examples/snes/corpus/expected.tsv"
TOOL="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin"
[ -f "$MANIFEST" ] || { echo "no manifest: $MANIFEST"; exit 1; }
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$ROOT/build/install/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$ROOT/build/llvm-mos-install dev/run.sh build)"; exit 1; }
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
NOBSNES=(); { [ -x "$ROOT/build/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; } || NOBSNES=(--no-bsnes)

echo "==> corpus-a16: $(basename "$MANIFEST")  (default == +mos-a16 == +mos-xy16, MAME + bsnes-jg)"
pass=0; fail=0; xfail=0; total=0
# `desc` soaks up the rest of each line; the `|| [ -n … ]` guard handles a final line
# with no trailing newline. Only corpus_result rows run (skips hello.c's `sentinel`).
while read -r cfile symbol expected desc || [ -n "${cfile:-}" ]; do
  case "${cfile:-}" in ''|\#*) continue ;; esac          # skip blanks + comments
  [ "$symbol" = "corpus_result" ] || continue            # skip hello.c (sentinel smoke)
  total=$((total + 1)); name="$(basename "$cfile" .c)"
  out="$(python3 "$ROOT/tools/a16_fuzz.py" check --src "$ROOT/examples/snes/$cfile" \
         --name "corpus-$name" --expected "$expected" "${NOBSNES[@]}" 2>&1)" && rc=0 || rc=$?
  if printf '%s\n' "$out" | grep -q 'known issue'; then
    printf '  %-10s XFAIL  %s\n' "$name" "$(printf '%s\n' "$out" | grep -o 'known issue \[[^]]*\]' | head -1)"; xfail=$((xfail + 1))
  elif [ "$rc" -eq 0 ]; then
    printf '  %-10s PASS   %s=%s  %s\n' "$name" "$symbol" "$expected" "$desc"; pass=$((pass + 1))
  else
    printf '  %-10s FAIL   %s\n' "$name" "$(printf '%s\n' "$out" | grep -E 'RESULT: FAIL|mismatch|CRASH' | head -1)"; fail=$((fail + 1))
  fi
done < "$MANIFEST"

echo "==> corpus-a16: $pass/$total passed, $xfail xfail"
[ "$fail" -eq 0 ]
