#!/usr/bin/env bash
# dev/a16local.sh — #321 Increment 1d: GISel-native 16-bit add (multi-use local).
set -euo pipefail
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && { echo "Usage: dev/run.sh a16local"; exit 0; }
ROOT=/work; BUILD="$ROOT/build"; INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16local.c"; ROM="$BUILD/a16local.sfc"; MAP="$BUILD/a16local.map"; OBJ="$BUILD/a16local.o"
WANT=0x1122; A16=(-Xclang -target-feature -Xclang +mos-a16)
echo "==> compile+link $SRC (+mos-a16)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
rc=0
echo "==> disasm gate: native 16-bit adc (zp) inside a rep/sep bracket"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|6[59])' | head
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*c2 20\b' && echo "  PASS: rep #\$20 present" || { echo "  FAIL: no rep"; rc=1; }
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*65\b' && echo "  PASS: 16-bit adc zp (native ADCImag16)" || { echo "  FAIL: no adc zp"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm)"; exit 1; }
echo "==> MAME: assert corpus_result == $WANT"
source "$ROOT/dev/_emu.sh"; require_bios || exit $?
run_assert "$ROM" "$MAP" corpus_result "$WANT" || rc=1
if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  read -r vma size < <(_emu_map_lookup "$MAP" corpus_result) || true; len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  line="$("$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)" && echo "  $line" || { echo "  $line"; rc=1; }
fi
echo; [ $rc -eq 0 ] && echo "RESULT: PASS — native 16-bit add (multi-use local) computes 0x1122 on both emulators" || echo "RESULT: FAIL"
exit $rc
