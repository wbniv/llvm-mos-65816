#!/usr/bin/env bash
# dev/a16copy.sh — #321 native 16-bit fused indirect copy (`g = *p`).
#
# Builds examples/65816/a16copy.c with +mos-a16. A single-use 16-bit indirect load
# feeding a 16-bit store must fold the load directly into the accumulator — `lda (p);
# sta g` — NOT round-trip the value through an Imag16 temp (`lda (p); sta tmp; lda
# tmp; sta g`). The gate asserts every `lda (zp)` (B2) is immediately followed by a
# 16-bit store (sta abs 8D/8F or sta (zp) 92), never a `sta zp` (85, the round-trip).
# corpus_result == 0x3456 (0x2345 via *psa, +0x1111) on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16copy. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg leg reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-native-16bit-absolute-load-store.md (copy-fusion follow-up).
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16copy   # fused indirect copy g=*p (lda (p); sta g, no Imag16 round-trip); corpus_result==0x3456 both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16copy.c"
ROM="$BUILD/a16copy.sfc"; MAP="$BUILD/a16copy.map"; OBJ="$BUILD/a16copy.o"
WANT=0x3456
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16copy.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: each lda (zp) folds directly into a 16-bit store (no Imag16 round-trip)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" > "$BUILD/a16copy.dis"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|b2|92|8[df]|85)\b' | head -20
if ! python3 - "$BUILD/a16copy.dis" <<'PY'
import sys, re
insns = []
for ln in open(sys.argv[1]):
    m = re.match(r'\s*[0-9a-f]+:\s+([0-9a-f]{2})(?: [0-9a-f]{2})*\s+(\S+)', ln, re.I)
    if m:
        insns.append((m.group(1).lower(), m.group(2).lower()))
nindir = sum(1 for op, _ in insns if op == "b2")  # lda (zp)
rc = 0
if nindir >= 1:
    print(f"  PASS: {nindir} lda (zp) (16-bit indirect load)")
else:
    print("  FAIL: no lda (zp) (b2)"); rc = 1
# Each b2 (indirect value load) must be immediately followed by a store — sta abs
# (8d/8f) or sta (zp) (92) — NOT `sta zp` (85), which is the STAImag16 round-trip.
for i, (op, mn) in enumerate(insns):
    if op != "b2":
        continue
    nxt = insns[i + 1][0] if i + 1 < len(insns) else None
    if nxt in ("8d", "8f", "92"):
        print(f"  PASS: lda (zp) folds directly into a store ({insns[i+1][1]})")
    elif nxt == "85":
        print("  FAIL: lda (zp) followed by `sta zp` — Imag16 round-trip not fused"); rc = 1
    else:
        print(f"  FAIL: lda (zp) followed by unexpected {nxt}"); rc = 1
sys.exit(rc)
PY
then rc=1; fi
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (0x2345 via *psa, +0x1111)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
run_assert "$ROM" "$MAP" corpus_result "$WANT" || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> bsnes-jg: assert corpus_result == $WANT (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$MAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" "$WANT" 180 2>&1)"; then
    echo "  $line"
  else echo "  $line"; rc=1; fi
else
  echo "==> bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

echo
emu_verdict "$rc" "fused indirect copy (lda (p); sta g, no round-trip) reads 0x3456; both emulators agree"
exit $rc
