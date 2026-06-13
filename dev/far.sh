#!/usr/bin/env bash
# dev/far.sh — #320 Increment 1 verification: compile the far-pointer test with
# the FROM-SOURCE toolchain and prove, at the disassembly level, that a far
# (addrspace 2) access lowers to 65816 absolute-long (LDA/STA $xxxxxx, opcodes
# AF/8F) while a near (addrspace 0) access stays 16-bit absolute (AD/8D).
# Runs INSIDE the dev container; drive from the host: dev/run.sh far.
# Requires the from-source toolchain (dev/run.sh toolchain) at build/llvm-mos-install.
set -euo pipefail

usage() { echo "Usage: dev/run.sh far   # compile+disassemble examples/65816/far-deref.c, assert far->long"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
TOOL="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far-deref.c"
OBJ="$ROOT/build/far-deref.o"
ASM="$ROOT/build/far-deref.s"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }

echo "==> compile $SRC  (--target=mos -mcpu=mosw65816 -Os)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Os -S -o "$ASM" "$SRC"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Os -c -o "$OBJ" "$SRC"

echo "==> disassembly + relocations (llvm-objdump -dr --mcpu=mosw65816)"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS"

echo
echo "==> assertions"
rc=0
check() { # name regex should-exist(yes|no)
  if printf '%s\n' "$DIS" | grep -qiE "$2"; then
    [ "$3" = yes ] && echo "  PASS: $1" || { echo "  FAIL: $1 (unexpected match: $2)"; rc=1; }
  else
    [ "$3" = yes ] && { echo "  FAIL: $1 (no match: $2)"; rc=1; } || echo "  PASS: $1"
  fi
}
# Far constant 0x7E1234 -> absolute-long: opcode AF/8F + the 3 address bytes
# "34 12 7e" (little-endian, incl. the bank byte). The bank byte proves it's a
# true 24-bit access, not a relaxed 16-bit one.
check "far load  0x7E1234 -> LDA AbsoluteLong (af 34 12 7e)"  '^\s*[0-9a-f]+:\s*af 34 12 7e\b'  yes
check "far store 0x7E1234 -> STA AbsoluteLong (8f 34 12 7e)"  '^\s*[0-9a-f]+:\s*8f 34 12 7e\b'  yes
# Near constant 0x1234 -> 16-bit absolute: 3 bytes, address "34 12", no bank byte.
# Load is LDA abs (ad); store may be STA (8d) or STX (8e) abs — both 16-bit.
check "near load  0x1234 -> LDA Absolute (ad 34 12)"          '^\s*[0-9a-f]+:\s*ad 34 12\b'     yes
check "near store 0x1234 -> ST{A,X} Absolute (8[de] 34 12)"   '^\s*[0-9a-f]+:\s*8[de] 34 12\b'  yes
# The far GLOBAL access must carry a 24-bit relocation against farbyte — proof
# the far path works for symbols, not just constants (a near symbol would get a
# 16-bit Addr16 reloc). This is the only ADDR24 relocation in the object.
check "far global -> 24-bit relocation (R_MOS_ADDR24)"        'ADDR(_)?24'                        yes

echo
[ $rc -eq 0 ] && echo "RESULT: PASS — addrspace 2 -> absolute-long (24-bit), addrspace 0 -> absolute (16-bit)" \
             || echo "RESULT: FAIL"
exit $rc
