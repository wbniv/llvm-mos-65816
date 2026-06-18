#!/usr/bin/env bash
# dev/crt0native.sh — #321 native-mode crt0 contract gate.
#
# Asserts the SNES platform's reset path establishes the full 65816 native-mode
# contract the codegen depends on, and that it survives as a STANDING gate (so a
# future "simplification" of crt0.c can't silently drop it):
#
#   1. byte-exact .init.50 preamble at the reset entry, INCLUDING the explicit
#      DBR=0 establishment (phk/plb = 4b ab, right after sep #$30 / e2 30);
#   2. native ($FFE0-$FFEF) + emulation ($FFF0-$FFFF) interrupt vectors present,
#      RESET ($FFFC) -> _start, NMI/IRQ native == emulation (both -> the stubs);
#   3. FUNCTIONAL: a DEFAULT (8-bit) build whose global access uses the
#      DBR-relative `abs`/R_MOS_ADDR16 path round-trips corpus_result==0x2345 on
#      MAME (+ bsnes-jg) — i.e. DBR=0 actually holds at runtime, not just in the
#      disassembly.
#
# Runs INSIDE the dev container; drive: dev/run.sh crt0native.
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK (dev/run.sh build).
# See docs/plans/2026-06-18-321-native-mode-crt0-xy16.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh crt0native   # native-mode crt0 contract: phk/plb DBR=0 + vectors + 0x2345 round-trip"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/crt0native.c"
ROM="$BUILD/crt0native.sfc"; MAP="$BUILD/crt0native.map"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (DEFAULT 8-bit, abs/R_MOS_ADDR16 global path) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-14s %6s bytes\n' crt0native.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> contract gate: reset preamble (incl. phk/plb DBR=0) + interrupt vectors"
# Expected .init.50 preamble at the reset entry (32 KiB LoROM: ROM $8000 = file 0):
#   78 d8 18 fb  c2 10  a2 ff 01  9a  e2 30  4b ab  a9 00  8d 00 42  a9 8f  8d 00 21
#   sei cld clc XCE  REP#$10  LDX#$01ff  txs  SEP#$30  PHK PLB  lda#0 sta$4200  lda#$8f sta$2100
if python3 - "$ROM" "$MAP" <<'PY'
import sys
rom, mapf = sys.argv[1], sys.argv[2]
d = open(rom, "rb").read()
w = lambda o: d[o] | (d[o + 1] << 8)
EXPECT = bytes.fromhex("78d818fbc210a2ff019ae2304baba9008d0042a98f8d0021")

ok = True
reset = w(0x7FFC)                       # emulation RESET vector ($FFFC) — boot entry
print(f"    emu RESET   : ${reset:04X} -> _start")
if not (0x8000 <= reset <= 0xFFFF):
    print(f"    FAIL: RESET ${reset:04X} not in ROM ($8000-$FFFF)"); ok = False
got = d[reset - 0x8000: reset - 0x8000 + len(EXPECT)]
print(f"    reset bytes : {got.hex()}")
print(f"    expected    : {EXPECT.hex()}")
if got != EXPECT:
    print("    FAIL: reset preamble != expected native-mode contract"); ok = False
else:
    print("    PASS: .init.50 byte-exact (native entry + 16-bit SP + M=1/X=1)")
# The new explicit DBR=0: PHK(4b) PLB(ab) must follow SEP #$30 (e2 30).
if b"\xe2\x30\x4b\xab" in got:
    print("    PASS: phk/plb (4b ab) present immediately after sep #$30 — DBR=0 is explicit")
else:
    print("    FAIL: phk/plb (4b ab) not found after sep #$30 — DBR=0 left implicit"); ok = False

# Interrupt vectors. Native $FFE0-$FFEF (file 0x7FE0), emulation $FFF0-$FFFF (0x7FF0).
nN, nI = w(0x7FEA), w(0x7FEE)           # native    NMI ($FFEA), IRQ ($FFEE)
eN, eI = w(0x7FFA), w(0x7FFE)           # emulation NMI ($FFFA), IRQ ($FFFE)
print(f"    native NMI=${nN:04X} IRQ=${nI:04X}   emu NMI=${eN:04X} IRQ=${eI:04X}")
if nN and nI and nN == eN and nI == eI:
    print("    PASS: native NMI/IRQ == emulation NMI/IRQ (both -> the rti stubs)")
else:
    print("    FAIL: native/emulation NMI/IRQ vectors inconsistent or null"); ok = False

sys.exit(0 if ok else 1)
PY
then echo "  PASS: native-mode crt0 contract"; else echo "  FAIL: native-mode crt0 contract"; rc=1; fi
[ $rc -eq 0 ] || { echo "RESULT: FAIL (contract gate)"; exit 1; }

echo "==> MAME: assert corpus_result == 0x2345 (8-bit abs global round-trip => DBR=0 holds at runtime)"
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
run_assert "$ROM" "$MAP" corpus_result 0x2345 || rc=1

if [ -x "$BUILD/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "==> bsnes-jg: corpus_result == 0x2345 (independent confirmation)"
  read -r vma size < <(_emu_map_lookup "$MAP" corpus_result) || true
  len=$((0x$size)); [ "$len" -ge 1 ] || len=1
  if line="$("$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "0x$vma" "$len" 0x2345 180 2>&1)"; then echo "  $line"; else echo "  $line"; rc=1; fi
else
  echo "==> bsnes-jg: SKIP (run dev/run.sh xcheck first to build build/jgxcheck)"
fi

[ $rc -eq 0 ] && echo "RESULT: PASS — native-mode crt0 contract holds (DBR=0 explicit, vectors placed, round-trip OK)" || echo "RESULT: FAIL"
exit $rc
