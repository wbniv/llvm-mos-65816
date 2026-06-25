#!/usr/bin/env bash
# dev/a16scavnz.sh — #321 POSITIVE gate for the (FIXED) +mos-a16 register-scavenger crash.
# examples/65816/a16scavnz.c (delta-debugged from fuzz seed-306; the 169/173/196/268/271/272/
# 306/420 family) used to crash the register scavenger under +mos-a16/+mos-xy16 -O1/-Os:
# MOSRegisterInfo::saveScavengerRegister assumed N/Z dead at every scavenge point, but a 16-bit
# compare/ALU keeps N (or Z) live across a frame-index materialization whose carry the scavenger
# must place in $c (a sub-register of $p) — forcing the whole $p to be preserved across an
# UNBALANCED hard-stack range. The old code had no GPR spill home for $p, so it emitted illegal
# `STImag8 $p` ("$p is not a GPR register") + an undefined-$p `PH $p`. Upstream fix 0011 routes
# $p hard-stack-neutrally through a dead index register into RC17 and flags the no-reaching-def
# PHP undef. This gate asserts the program now compiles clean under -verify-machineinstrs AND
# computes the SAME corpus_result host == default == +mos-a16 == +mos-xy16 on BOTH MAME and
# bsnes-jg (0x22A6).
#
# Runs INSIDE the dev container; drive: dev/run.sh a16scavnz. Prereqs: from-source toolchain
# (dev/run.sh toolchain) + SDK. bsnes-jg leg reuses build/jgxcheck.
# See docs/plans/2026-06-26-321-scavenger-nz-live-p-save-fix.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16scavnz   # FIXED a16/xy16 scavenger crash now compiles + corpus_result==0x22A6 both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16scavnz.c"
WANT=0x22A6
A16=(-Xclang -target-feature -Xclang +mos-a16)
XY16=(-Xclang -target-feature -Xclang +mos-xy16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0
echo "==> crash gate: compile +mos-a16 and +mos-xy16 under -verify-machineinstrs (must NOT crash the scavenger)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}"  -Os -mllvm -verify-machineinstrs -c "$SRC" -o "$BUILD/a16scavnz.a16.o"  \
  && echo "  PASS: +mos-a16 verifies clean (no \$p-is-not-a-GPR / undef PHP)" || { echo "  FAIL: +mos-a16 still crashes"; rc=1; }
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${XY16[@]}" -Os -mllvm -verify-machineinstrs -c "$SRC" -o "$BUILD/a16scavnz.xy16.o" \
  && echo "  PASS: +mos-xy16 verifies clean" || { echo "  FAIL: +mos-xy16 still crashes"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (crash gate)"; exit 1; }

source "$ROOT/dev/_emu.sh"
require_bios || exit $?

# Build + run all three value legs (default 8-bit oracle, +mos-a16, +mos-xy16) and assert each
# computes WANT on both emulators.
for leg in default a16 xy16; do
  case "$leg" in
    default) FEAT=() ;;
    a16)     FEAT=("${A16[@]}") ;;
    xy16)    FEAT=("${XY16[@]}") ;;
  esac
  ROM="$BUILD/a16scavnz.$leg.sfc"; MAP="$BUILD/a16scavnz.$leg.map"
  echo "==> [$leg] link + assert corpus_result == $WANT"
  "$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${FEAT[@]}" -Os \
    -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
  run_assert "$ROM" "$MAP" corpus_result "$WANT" || rc=1

  if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
    read -r vma size < <(_emu_map_lookup "$MAP" corpus_result) || true
    len=$((0x$size)); [ "$len" -ge 1 ] || len=1
    if line="$("$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)"; then
      echo "  bsnes-jg: $line"
    else echo "  bsnes-jg: $line"; rc=1; fi
  fi
done

echo
emu_verdict "$rc" "FIXED a16/xy16 scavenger crash: compiles clean + corpus_result==0x22A6 (host==default==+mos-a16==+mos-xy16, both emulators)"
exit $rc
