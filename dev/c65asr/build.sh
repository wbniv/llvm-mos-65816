#!/usr/bin/env bash
# dev/c65asr/build.sh — build a bare-metal 65CE02 ROM image from C.
#
# This is the reusable half of the 65CE02 execution work (see
# docs/howto-testing-65ce02-code.md). It links C compiled for -mcpu=mos65ce02
# into a raw 8 KiB image covering CPU $E000-$FFFF, with the 6502-style vectors
# in the last six bytes. It needs no platform support in llvm-mos-sdk: the
# linker script below is modelled on the `eater` (Ben Eater breadboard) bare-
# metal platform, which is the closest thing the SDK ships to "no operating
# system, just a reset vector".
#
# The image BUILDS and is correct; what is still missing is a trustworthy
# emulator to run it on — see the HOWTO's "Level 3" section before assuming a
# result from it means anything.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: dev/c65asr/build.sh <toolchain-prefix> <source.c> <out.bin> [mcpu]

  toolchain-prefix   an llvm-mos install dir (contains bin/mos-clang)
  mcpu               default mos65ce02; mos45gs02 for MEGA65

Example:
  dev/c65asr/build.sh build/llvm-mos-install dev/c65asr/target.c /tmp/asr.bin
EOF
  exit 0
}
[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage
[ $# -ge 3 ] || usage

PREFIX="$1"; SRC="$2"; OUT="$3"; MCPU="${4:-mos65ce02}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

CC="$PREFIX/bin/mos-clang"
[ -x "$CC" ] || { echo "no mos-clang at $CC" >&2; exit 1; }

# The SDK's common linker fragments (c.ld, imag-regs.ld) and crt0.o. crt0.o must
# be linked as an OBJECT, not via -lcrt0: its `.call_main` section is what
# references main, and an archive member is only pulled in if already referenced
# — link it as a library and --gc-sections silently drops your whole program.
LIB="$ROOT/build/install/mos-platform/common/lib"
[ -f "$LIB/crt0.o" ] || { echo "no SDK common lib at $LIB (build the SDK first)" >&2; exit 1; }

"$CC" --target=mos -mcpu="$MCPU" -Os -nostdlib -static \
  -T "$HERE/link.ld" -Wl,-L"$LIB" -Wl,--gc-sections -Wl,-Map,"$OUT.map" \
  "$LIB/crt0.o" "$HERE/start.s" "$SRC" \
  -L"$LIB" -lc -lcrt -linit-stack -lexit-loop \
  -o "$OUT"

sz=$(stat -c%s "$OUT")
[ "$sz" -eq 8192 ] || { echo "expected an 8192-byte image, got $sz" >&2; exit 1; }

# Sanity: the program must actually be in there. A silently gc'd main leaves
# only ~14 bytes of init code and pads the rest, which still links "fine".
code=$(python3 -c "
d=open('$OUT','rb').read()
print(sum(1 for b in d if b not in (0x00,0xff)))")
echo "$OUT: 8192 bytes, ~$code bytes of content, reset vector \$$(python3 -c "
d=open('$OUT','rb').read(); print('%04X' % (d[-4] | d[-3]<<8))")"
[ "$code" -gt 24 ] || { echo "WARNING: image looks empty — was main garbage-collected?" >&2; exit 1; }
