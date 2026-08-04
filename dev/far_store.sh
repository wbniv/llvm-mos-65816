#!/usr/bin/env bash
# dev/far_store.sh — #320 Inc 3 follow-up: prove a RUNTIME far-pointer STORE lowers
# to 65816 indirect-long (`sta [dp]`, opcode 87) and writes the right 24-bit address.
# Builds examples/65816/far_store.c against the snes platform (bank $00) with
# -mcpu=mosw65816 AND +mos-a16 (the far pointer is a 32-bit value), asserts the store
# is indirect-long (87), boots the ROM headless in MAME, and checks the byte written
# via the far pointer and read back near round-trips to 0xF3.
#
# Gate is host-expected == +mos-a16 on both emulators (MAME here + bsnes-jg via
# dev/run.sh xcheck); the default 8-bit build can't compile a runtime far store.
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh far_store.
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK (dev/run.sh build).
# See docs/plans/2026-06-20-320-inc4-far-calls-and-far-pointer-cc.md (Phase 0).
set -euo pipefail

usage() { echo "Usage: dev/run.sh far_store   # build examples/65816/far_store.c (snes, +mos-a16), boot in MAME, assert sta [dp] store == 0xF3"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far_store.c"
ROM="$BUILD/far_store.sfc"
MAP="$BUILD/far_store.map"
OBJ="$BUILD/far_store.o"
A16=(-Xclang -target-feature -Xclang +mos-a16)
WANT=0xF3   # the byte stored through the far pointer and read back near

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes.cfg -mcpu=mosw65816 +mos-a16 -Os)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM"

rc=0
echo "==> disasm gate: the runtime far store is indirect-long (87 = sta [dp])"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC"
"$TOOL/llvm-objdump" -h "$OBJ" >/dev/null 2>&1 \
  || { echo "FAIL: -verify-machineinstrs emitted no real object (vacuous verify)"; exit 1; }
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*87 ' || true
printf '%s\n' "$DIS" | grep -qiE '^\s*[0-9a-f]+:\s*87 ' && echo "  PASS: far store -> STA IndirectLong (87)" || { echo "  FAIL: no 87 (indirect-long) store"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> execution gate: boot in MAME, assert corpus_result == $WANT (the far store, read back)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
  emu_verdict 0 "runtime far-pointer store (sta [dp], bank \$00) then near read-back == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
else
  emu_verdict 1 ""
  exit 1
fi
