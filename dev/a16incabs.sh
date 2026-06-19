#!/usr/bin/env bash
# dev/a16incabs.sh — #321 native s16 inc/dec on globals (`g = g ± 1`).
#
# Builds examples/65816/a16incabs.c with +mos-a16. A 16-bit `g ± 1` on a global selects
# to `lda <g>; inc a/dec a; sta <g>` (dropping the clc + shrinking adc #$0001 to a 1-byte
# inc a/dec a), using the SAME 24-bit long addressing the compiler uses for data. A
# DBR-relative `inc abs`/`dec abs` memory-RMW is deliberately NOT used (no `inc long` on
# the 65816; it would couple correctness to DBR==0 + bank-0 LoRAM placement). The gate
# asserts inc a (1a)/dec a (3a) appear, no old `adc #$0001` (69 01 00), and no inc abs
# (ee)/dec abs (ce). corpus_result == 0x3502 on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16incabs. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg cross-check reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-s16-inc-dec-memory-rmw.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16incabs   # native 16-bit inc a/dec a on globals (g +-1), corpus_result==0x3502 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16incabs.c"
ROM="$BUILD/a16incabs.sfc"; MAP="$BUILD/a16incabs.map"; OBJ="$BUILD/a16incabs.o"
WANT=0x3502
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16incabs.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: each global +-1 is lda <g>; inc a (1a)/dec a (3a); sta <g> — no old"
echo "    clc;adc #\$0001 (69 01 00), and NO DBR-relative inc abs (ee)/dec abs (ce) RMW."
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
ninc=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*1a\b' || true)          # inc a
ndec=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*3a\b' || true)          # dec a
nadcimm=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*69 01 00\b' || true) # adc #$0001
nincabs=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*(ee|ce)\b' || true)  # inc/dec abs RMW
echo "  inc a=$ninc  dec a=$ndec  adc #\$0001=$nadcimm  inc/dec abs(ee/ce)=$nincabs"
[ "$ninc" -ge 3 ] && echo "  PASS: $ninc inc a — native 16-bit increments on globals" || { echo "  FAIL: expected >=3 inc a, got $ninc"; rc=1; }
[ "$ndec" -ge 1 ] && echo "  PASS: $ndec dec a — native 16-bit decrement on a global" || { echo "  FAIL: expected >=1 dec a, got $ndec"; rc=1; }
[ "$nadcimm" -eq 0 ] && echo "  PASS: no clc; adc #\$0001 (the ±1 went to inc/dec a)" || { echo "  FAIL: found $nadcimm adc #\$0001 — ±1 still uses adc"; rc=1; }
[ "$nincabs" -eq 0 ] && echo "  PASS: no DBR-relative inc abs/dec abs RMW (long addressing kept)" || { echo "  FAIL: found $nincabs inc/dec abs — DBR-dependent RMW emitted"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (3 inc a + 1 dec a on globals)"
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
emu_verdict "$rc" "native 16-bit inc a/dec a on globals (g +-1, long addressing) computes 0x3502; both emulators agree"
exit $rc
