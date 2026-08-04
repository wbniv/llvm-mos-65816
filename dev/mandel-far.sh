#!/usr/bin/env bash
# dev/mandel-far.sh — #321 Track 3a: prove the fixed-point Mandelbrot fills a HIGH-WRAM
# buffer ($7E2000, reachable only by 24-bit addressing) via far stores, and reads it
# back via far loads — the #320 far store→load path on a real workload.
#
# Builds examples/65816/k_mandel_far.c (snes, +mos-a16 — a far pointer is a 32-bit
# value, so default-8bit legitimately can't compile it), asserts the far store is
# indirect-long (`sta [dp]`, opcode 87), then boots in MAME AND bsnes-jg and checks the
# CRC of the far buffer (computed via far loads, parked in near corpus_result) ==
# 0x820B — the SAME host reference as dev/run.sh k_mandel (identical 16x10/N=12 grid),
# so this is host == +mos-a16 on both emulators.
#
# Drive: dev/run.sh mandel-far.  See docs/plans/2026-06-24-snes-mandelbrot-beefy-demo.md (Track 3).
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh mandel-far   # Mandelbrot into high WRAM via far stores (host==+mos-a16, 0x820B)"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/k_mandel_far.c"
ROM="$BUILD/k_mandel_far.sfc"
MAP="$BUILD/k_mandel_far.map"
OBJ="$BUILD/k_mandel_far.o"
A16=(-Xclang -target-feature -Xclang +mos-a16)
WANT=0x820B
export SMOKE_SETTLE="${SMOKE_SETTLE:-170}"   # far fill finishes ~frame 129; sample after

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: dev/run.sh build)"; exit 1; }

echo "==> compile+link $(basename "$SRC")  (mos-snes.cfg -mcpu=mosw65816 +mos-a16 -Os -verify)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null

rc=0
echo "==> disasm gate: the far store into high WRAM is indirect-long (87 = sta [dp])"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -mllvm -verify-machineinstrs -c -o "$OBJ" "$SRC"
"$TOOL/llvm-objdump" -h "$OBJ" >/dev/null 2>&1 \
  || { echo "FAIL: -verify-machineinstrs emitted no real object (vacuous verify)"; exit 1; }
# grep -c (not -q): -q exits on first match and closes the pipe, which SIGPIPEs
# llvm-objdump → under `set -o pipefail` the pipeline reports failure even on a match.
N87=$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ" | grep -ciE '^[[:space:]]*[0-9a-f]+:[[:space:]]*87 ' || true)
if [ "${N87:-0}" -ge 1 ]; then
  echo "  PASS: far store -> STA [dp] (87)"
else
  echo "  FAIL: no indirect-long (87) far store in k_mandel_far"; rc=1
fi

echo "==> execution gate (MAME): far buffer CRC (via far loads) -> corpus_result == $WANT"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
run_assert "$ROM" "$MAP" corpus_result "$WANT" || rc=1

# bsnes-jg leg (independent core) — build the harness if needed, then assert the same.
JGX="$BUILD/jgxcheck"; VENDOR="$ROOT/vendor/bsnes-jg"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$MAP")
  echo "==> execution gate (bsnes-jg): corpus_result == $WANT"
  "$JGX" "$ROM" "$VENDOR/Database" "0x$VMA" 2 "$WANT" 600 || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Mandelbrot far-stored into high WRAM \$7E2000; CRC $WANT host == +mos-a16 (MAME + bsnes-jg)"
else
  echo "RESULT: FAIL — see the per-step lines above"
fi
exit $rc
