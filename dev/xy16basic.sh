#!/usr/bin/env bash
# dev/xy16basic.sh — #321 xy16 smoke test: +mos-xy16 feature flag accepted, implies +mos-a16,
# corpus_result == 0x0042 on both emulators (g16 fully zeroed by rep #$20 / stz / sep #$20).
#
# Parallel to dev/a16.sh; proves the X-flag lattice in MOSInsertREPSEP doesn't disturb
# M-flag placement for M16-only ops (LDAbs16, STZ in 16-bit mode — XLow=0 → no rep/sep #$10).
# Runs INSIDE the dev container; drive: dev/run.sh xy16basic.
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK (MOS_TOOLCHAIN=... dev/run.sh build).
set -euo pipefail

usage() { echo "Usage: dev/run.sh xy16basic   # +mos-xy16 smoke: rep/stz/sep + corpus_result==0x0042 on both emus"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/xy16basic.c"
ROM="$BUILD/xy16basic.sfc"; MAP="$BUILD/xy16basic.map"; OBJ="$BUILD/xy16basic.o"
XY16=(-Xclang -target-feature -Xclang +mos-xy16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-xy16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${XY16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' xy16basic.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: 16-bit store-of-zero fuses to rep #\$20 / single stz / sep #\$20 (same as +mos-a16)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|9c|e2 20)' | head
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*c2 20\b' && echo "  PASS: rep #\$20 (c2 20)" || { echo "  FAIL: no rep #\$20"; rc=1; }
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*e2 20\b' && echo "  PASS: sep #\$20 (e2 20)" || { echo "  FAIL: no sep #\$20"; rc=1; }
# Must NOT emit rep/sep #$10 — the stz is XLow=0 (X-agnostic); the X-flag lattice is inert
if printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*[ce]2 10\b'; then
  echo "  FAIL: unexpected rep/sep #\$10 — X-flag lattice fires for an X-agnostic M16 op"; rc=1
else
  echo "  PASS: no rep/sep #\$10 (X-flag lattice correctly inert for XLow=0 ops)"
fi
nstz=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*9c ')
[ "$nstz" -eq 1 ] && echo "  PASS: single fused stz (was 2 without +mos-a16/-xy16)" || { echo "  FAIL: expected 1 stz, got $nstz"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == 0x0042 (g16 fully zeroed)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
run_assert "$ROM" "$MAP" corpus_result 0x0042 || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> bsnes-jg: corpus_result == 0x0042 (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$MAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" 0x0042 180 2>&1)"; then echo "  $line"; else echo "  $line"; rc=1; fi
else
  echo "==> bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
[ $rc -eq 0 ] && echo "RESULT: PASS — +mos-xy16 accepted, X-flag lattice inert for M16-only ops, corpus_result==0x0042" \
             || echo "RESULT: FAIL"
exit $rc
