#!/usr/bin/env bash
# dev/a16localx.sh — #321 Increment 1d-retry, step 4: the COMPLEX multi-op s16
# case that crashed the first 1d prototype's register coalescer.
#
# examples/65816/a16localx.c does five native s16 adds with locals reused across
# later ops (heavy Imag16 pressure + spills). The prototype coalesced an 8-bit
# value into A16 here and emitted a malformed `$a16 = LDImm`. With the value
# resident in Imag16 and the accumulator entered/left only via load/store (no
# Ac16<->8-bit COPY), this must (a) COMPILE CLEAN (the regression that killed the
# prototype) and (b) run corpus_result == 0x33A0 on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16localx. Prereqs: from-source
# toolchain + SDK. bsnes-jg cross-check reuses build/jgxcheck (dev/run.sh xcheck).
# See docs/plans/2026-06-14-321-increment-1d-retry-imag16-native-s16.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16localx   # complex native-s16 case compiles clean + corpus_result==0x33A0 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16localx.c"
ROM="$BUILD/a16localx.sfc"; MAP="$BUILD/a16localx.map"; OBJ="$BUILD/a16localx.o"
WANT=0x33A0
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0
echo "==> compile-clean gate: complex multi-op native s16 must NOT crash the coalescer"
# -verify-machineinstrs catches malformed MIR (e.g. an 8-bit imm in a 16-bit reg).
if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -mllvm -verify-machineinstrs \
     -Os -c -o "$OBJ" "$SRC" 2>"$BUILD/a16localx.cc.err"; then
  echo "  PASS: compiled clean (-verify-machineinstrs), no coalescer crash"
else
  echo "  FAIL: compile crashed/failed"; sed -n '1,12p' "$BUILD/a16localx.cc.err"; exit 1
fi
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
# Native s16 adds appear as adc zp (65, Imag16 operand) OR adc abs/long (6[df], a near-abs
# global operand read directly — the mixed-operand load-fold turns t+c16v's global into
# adc abs/long). 6d (abs) since the 0007 near-abs relaxation fix; 6f (long) pre-fix/far.
# Count both: the 5 source adds map to 5 native adc ops across the zp + abs[/long] forms.
nadczp=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*65\b')     # adc zp
nadcabs=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*6[df]\b') # adc abs/long
nadc=$((nadczp + nadcabs))
nbra=$(printf '%s\n' "$DIS" | grep -ciE '^\s*[0-9a-f]+:\s*c2 20\b') # rep #$20 brackets
[ "$nadc" -ge 4 ] && echo "  PASS: $nadc native adc ops present ($nadczp adc-zp + $nadcabs adc-abs, 5 s16 adds)" || { echo "  FAIL: expected >=4 native adc (zp+abs), got $nadc"; rc=1; }
echo "  ($nbra rep #\$20 brackets — multiple, as expected for spilled multi-op)"

echo "==> compile+link -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-13s %6s bytes\n' a16localx.sfc "$(stat -c%s "$ROM")"

echo "==> MAME: assert corpus_result == $WANT (0x227E + 0x1122)"
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
emu_verdict "$rc" "complex native-s16 (5 adds, reused locals) compiles clean and computes 0x33A0; both emulators agree"
exit $rc
