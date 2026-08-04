#!/usr/bin/env bash
# dev/far_memops.sh — #320/#321: prove far (addrspace 2) memset/memcpy land in the
# RIGHT BANK. Before the fix, a far memop the backend couldn't inline (variable
# size, or constant > SizeLimit) fell through legalizeMemOp into the generic
# createMemLibcall, calling the NEAR runtime (__memset/memcpy, 16-bit char*) with
# the 32-bit far pointer — the bank byte was dropped -> silent wrong-bank store.
# The fix routes far memops to __memset_far/__memcpy_far.
#
# Gate: (1) disasm — the far runtime (__memset_far/__memcpy_far) is selected and
# the NEAR __memset/memcpy are NOT; (2) execution at BOTH -Os and -O2 — fill HIGH
# WRAM ($7E2000) with a variable-size far memset + a far aggregate memcpy, read
# back via far loads and SUM -> corpus_result == 0x74 (a wrong-bank write reads
# back as not-0x5A/not-the-ROM-bytes, changing the sum). Host-expected ==
# +mos-a16 on MAME (here) + bsnes-jg (dev/run.sh xcheck); the default 8-bit build
# can't compile a far memop.
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh far_memops.
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK (dev/run.sh build).
# See docs/plans/2026-06-26-fix-the-far-addrspace-2-memset-memcpy-memmove-sile.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh far_memops   # build examples/65816/far_memops.c (snes, +mos-a16) at -Os/-O2, boot in MAME, assert far memset/memcpy hit bank \$7E (corpus_result == 0x74)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far_memops.c"
A16=(-Xclang -target-feature -Xclang +mos-a16)
WANT=0x74   # 50*0x5A + sum(0..63) = 6516 & 0xFF

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0
echo "==> disasm gate: far memops route to the FAR runtime (__memset_far/__memcpy_far), not the near one"
OBJ="$BUILD/far_memops.o"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC"
"$TOOL/llvm-objdump" -h "$OBJ" >/dev/null 2>&1 \
  || { echo "FAIL: -verify-machineinstrs emitted no real object (vacuous verify)"; exit 1; }
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
if printf '%s\n' "$DIS" | grep -qE '__memset_far' && printf '%s\n' "$DIS" | grep -qE '__memcpy_far'; then
  echo "  PASS: calls __memset_far and __memcpy_far"
else
  echo "  FAIL: far runtime not selected (expected __memset_far + __memcpy_far)"; rc=1
fi
if printf '%s\n' "$DIS" | grep -qE '\b(__memset|memcpy|memmove)\b'; then
  echo "  FAIL: a NEAR mem runtime symbol is still referenced (bank byte would be dropped):"
  printf '%s\n' "$DIS" | grep -nE '\b(__memset|memcpy|memmove)\b' | head
  rc=1
else
  echo "  PASS: no near __memset/memcpy/memmove reference"
fi
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

source "$ROOT/dev/_emu.sh"
require_bios || exit $?

for OPT in -Os -O2; do
  ROM="$BUILD/far_memops${OPT}.sfc"
  MAP="$BUILD/far_memops${OPT}.map"
  echo "==> compile+link $SRC -> $(basename "$ROM")  (--config mos-snes.cfg -mcpu=mosw65816 +mos-a16 $OPT)"
  "$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" "$OPT" \
    -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$ROM"
  echo "==> execution gate ($OPT): boot in MAME, assert corpus_result == $WANT (far memset+memcpy, read back)"
  if run_assert "$ROM" "$MAP" corpus_result "$WANT"; then
    echo "  PASS ($OPT)"
  else
    emu_verdict 1 ""; exit 1
  fi
done

emu_verdict 0 "far memset (variable) + far aggregate memcpy land in bank \$7E at -Os and -O2; read back == $WANT (bsnes-jg confirms via dev/run.sh xcheck)"
