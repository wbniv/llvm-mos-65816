#!/usr/bin/env bash
# dev/a16incdec.sh — #321 native s16 1-byte inc a / dec a (register ±1).
#
# Builds examples/65816/a16incdec.c with +mos-a16. A 16-bit register/local `x + 1` /
# `x - 1` selects to a single `inc a` (0x1a) / `dec a` (0x3a) in M16 mode, NOT the 8-bit
# byte inc/dec-with-carry chain (`sep; ldx; stx; inc zp (e6); bne; inc zp; rep`) the
# default path emits. The gate asserts inc a / dec a appear and NO 8-bit inc-zp (e6) /
# dec-zp (c6) byte-step survives. corpus_result == 0x2668 on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16incdec. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-s16-inc-dec-accumulator.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16incdec   # native 16-bit inc a/dec a (register +-1), corpus_result==0x2668 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16incdec.c"
ROM="$BUILD/a16incdec.sfc"; MAP="$BUILD/a16incdec.map"; OBJ="$BUILD/a16incdec.o"
WANT=0x2668
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16incdec.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: each register +-1 is a single inc a (1a) / dec a (3a) in M16,"
echo "    NOT the 8-bit byte inc-zp (e6) / dec-zp (c6) carry chain."
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
ninc=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*1a\b' || true)   # inc a
ndec=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*3a\b' || true)   # dec a
ninczp=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*e6\b' || true) # inc zp (8-bit)
ndeczp=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c6\b' || true) # dec zp (8-bit)
echo "  inc a=$ninc  dec a=$ndec  inc-zp(e6)=$ninczp  dec-zp(c6)=$ndeczp"
[ "$ninc" -ge 2 ] && echo "  PASS: $ninc inc a — native 16-bit increments" || { echo "  FAIL: expected >=2 inc a, got $ninc"; rc=1; }
[ "$ndec" -ge 2 ] && echo "  PASS: $ndec dec a — native 16-bit decrements" || { echo "  FAIL: expected >=2 dec a, got $ndec"; rc=1; }
{ [ "$ninczp" -eq 0 ] && [ "$ndeczp" -eq 0 ]; } && echo "  PASS: no 8-bit byte inc/dec chain (fully native)" || { echo "  FAIL: 8-bit inc/dec survives (e6=$ninczp c6=$ndeczp)"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (two inc a + two dec a)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
run_assert "$ROM" "$MAP" corpus_result "$WANT" || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> bsnes-jg: assert corpus_result == $WANT (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$MAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)"; then
    echo "  $line"
  else echo "  $line"; rc=1; fi
else
  echo "==> bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
emu_verdict "$rc" "native 16-bit inc a/dec a (register +-1) computes 0x2668; both emulators agree"
exit $rc
