#!/usr/bin/env bash
# dev/far_indir.sh — #320 Increment 3: prove a RUNTIME far pointer dereference
# lowers to 65816 indirect-long (`lda [dp]`, opcode A7) and reads the right byte
# across a ROM bank boundary. Builds examples/65816/far_indir.c against the
# snes-far child platform (64 KiB LoROM, banks $00+$01) with -mcpu=mosw65816 AND
# +mos-a16 (a runtime far pointer is a 32-bit value; 32-bit value legalization is
# a16-gated — the far machinery itself is a16-independent), asserts the deref is
# indirect-long (A7) not absolute-long, boots the ROM headless in MAME, and checks
# the byte read via the runtime far pointer round-trips to 0xF3.
#
# Gate is host-expected == +mos-a16 on both emulators (MAME here + bsnes-jg via
# dev/run.sh xcheck): the default 8-bit build legitimately can't compile a runtime
# far deref (no 32-bit value support without +mos-a16), so there is no default leg.
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh far_indir.
# Prereqs (built once): from-source toolchain (dev/run.sh toolchain) AND the SDK
# install incl. the snes-far platform (MOS_TOOLCHAIN=.../llvm-mos-install dev/run.sh build).
# See docs/plans/2026-06-20-320-far-pointer-runtime.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh far_indir   # build examples/65816/far_indir.c (snes-far, +mos-a16), boot in MAME, assert runtime far deref (lda [dp]) == 0xF3"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far_indir.c"
ROM="$BUILD/far_indir.sfc"
MAP="$BUILD/far_indir.map"
OBJ="$BUILD/far_indir.o"
A16=(-Xclang -target-feature -Xclang +mos-a16)
WANT=0xF3   # bank1_sentinel (0xA9) ^ 0x5A; flip this to exercise the negative control

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes-far.cfg" ] || { echo "FATAL: snes-far platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes-far.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

rc=0
sz="$(stat -c%s "$ROM")"
printf '    %-14s %6s bytes\n' far_indir.sfc "$sz"

echo "==> size gate: 64 KiB image (banks \$00 + \$01)"
[ "$sz" -eq 65536 ] && echo "  PASS: 64 KiB (65536 bytes)" || { echo "  FAIL: expected 65536, got $sz"; rc=1; }

echo "==> placement gate: bank1_sentinel lands in bank \$01 (\$018xxx) per the link map"
FARVMA="$(awk '$NF == "bank1_sentinel" { print $1; exit }' "$MAP" || true)"
if [ -n "$FARVMA" ] && [ "$((0x$FARVMA))" -ge "$((0x18000))" ]; then
  echo "  PASS: bank1_sentinel @ 0x$FARVMA (bank \$01)"
else
  echo "  FAIL: bank1_sentinel @ 0x${FARVMA:-<not found>} (expected >= 0x018000, bank \$01)"; rc=1
fi

echo "==> disasm gate: the runtime deref is indirect-long (A7 = lda [dp]), not absolute-long"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*a7 ' || true
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*a7 ' && echo "  PASS: runtime far deref -> LDA IndirectLong (a7)" || { echo "  FAIL: no A7 (indirect-long) deref"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (build/placement/disasm gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (the runtime far read)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "runtime far pointer dereferenced via lda [dp]; byte read across bank \$01 round-tripped == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
