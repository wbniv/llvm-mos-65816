#!/usr/bin/env bash
# dev/a16isr.sh — the MINIMAL standing gate for the 65816 interrupt-prologue width defect found by
# demo #123 (nmitally). Compiles examples/65816/a16isr.c (four lines of C: one
# __attribute__((interrupt)) handler touching one volatile uint16_t) and runs the same ISR disasm
# gate the demo uses. Disasm-only — no emulator, no timing, so it stays a deterministic regression
# guard once the backend fix lands.
#
# Drive: dev/run.sh a16isr
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh a16isr   # minimal 65816 interrupt-prologue width gate (disasm only)"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16isr.c"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }

rc=0
for feat in +mos-a16 +mos-xy16; do
  echo "==> $feat"
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang "$feat" -Os \
    -c "$SRC" -o "$BUILD/a16isr-$feat.o"
  "$TOOL/llvm-objdump" -dr --mcpu=mosw65816 --section=.text.nmi "$BUILD/a16isr-$feat.o" \
    > "$BUILD/a16isr-$feat.dis"
  python3 "$ROOT/tools/nmitally-isr-gate.py" "$BUILD/a16isr-$feat.dis" || rc=1
done

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — the 65816 interrupt prologue establishes its widths and saves A/X/Y full-width"
else
  echo "RESULT: FAIL — interrupt-prologue width defect present (see docs/plans/2026-08-03-123-snes-nmitally.md)"
fi
exit $rc
