#!/usr/bin/env bash
# dev/far_memops32.sh — far (addrspace 2) memset/memcpy/memmove with lengths
# above 65535 (docs/defects/mos-far-memop-length-truncation.json).
#
# The backend calls the 16-bit-size_t __memset_far/__memcpy_far/__memmove_far
# only when the length provably fits 16 bits, and the uint32_t __mem*_far32
# entries (platforms/snes/mem-far.c) otherwise, so no length is truncated.
#
# Gate: (1) disasm: examples/65816/far_memops32.c references all three
# __mem*_far32 entries; (2) execution at -Os and -O2 in +mos-a16 and
# +mos-a16,+mos-xy16: 70000-byte fills, a 69984-byte overlapping move and a
# 32 KiB copy, all crossing the $7E/$7F WRAM bank boundary, on MAME and
# bsnes-jg. Each of 16 checks sets one bit: corpus_result == 0xFFFF.
#
# Runs INSIDE the dev container; drive from the host: dev/run.sh far_memops32.
# Prereqs: toolchain (dev/run.sh toolchain), SDK (dev/run.sh build), and
# build/jgxcheck (dev/run.sh xcheck) for the bsnes-jg leg.
# See docs/plans/2026-09-30-far-prerequisite-defects.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh far_memops32   # far memset/memcpy/memmove > 64 KiB across \$7E/\$7F on MAME + bsnes-jg (corpus_result == 0xFFFF)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/far_memops32.c"
A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-xy16)
WANT=0xFFFF
# The runtime moves about 320 KB one byte at a time: allow for it.
export SMOKE_SETTLE="${SMOKE_SETTLE:-2400}"
export SMOKE_SECONDS="${SMOKE_SECONDS:-45}"
JG_FRAMES="${JG_FRAMES:-2400}"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0
echo "==> disasm gate: lengths above 0xFFFF reach the __mem*_far32 entries"
OBJ="$BUILD/far_memops32.o"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -O2 -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ")"
for f in __memset_far32 __memcpy_far32 __memmove_far32; do
  if printf '%s\n' "$DIS" | grep -qE "\\b$f\\b"; then
    echo "  PASS: references $f"
  else
    echo "  FAIL: no reference to $f"; rc=1
  fi
done
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

source "$ROOT/dev/_emu.sh"
require_bios || exit $?

for mode in a16 xy16; do
  flags=("${A16[@]}"); [ "$mode" = xy16 ] && flags+=("${XY16[@]}")
  for OPT in -Os -O2; do
    ROM="$BUILD/far_memops32_${mode}${OPT}.sfc"
    MAP="$BUILD/far_memops32_${mode}${OPT}.map"
    echo "==> [$mode $OPT] compile+link -> $(basename "$ROM")"
    "$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${flags[@]}" "$OPT" \
      -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
    python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
    echo "==> [$mode $OPT] MAME: corpus_result == $WANT"
    run_assert "$ROM" "$MAP" corpus_result "$WANT" || rc=1
    if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
      echo "==> [$mode $OPT] bsnes-jg: corpus_result == $WANT"
      read -r vma size < <(_emu_map_lookup "$MAP" corpus_result) || true
      len=$((0x$size)); [ "$len" -ge 1 ] || len=1
      if line="$("$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" "$JG_FRAMES" 2>&1)"; then
        echo "  $line"
      else
        echo "  $line"; rc=1
      fi
    else
      echo "  FAIL: bsnes-jg harness missing (run dev/run.sh xcheck first)"; rc=1
    fi
  done
done

emu_verdict $rc "far memset/memcpy/memmove above 64 KiB across \$7E/\$7F honour the full length on both emulators (a16, xy16; -Os, -O2)"
exit $rc
