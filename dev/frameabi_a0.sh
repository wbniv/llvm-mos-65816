#!/usr/bin/env bash
# dev/frameabi_a0.sh — #321 frame-ABI study, Phase A0 (make-or-break gate).
#
# Builds examples/65816/frameabi_a0.c (DEFAULT 8-bit) and proves the TCD
# direct-page-window can coexist with llvm-mos's linker-fixed __rc* zero-page
# registers: a hand-encoded sequence sets D=$1000, writes a frame local via DP
# ($10 -> $1010), and — WHILE D=$1000 — reads the __rc16 cell via ABSOLUTE
# ($0010), proving abs ignores D so __rc stays reachable under a DP-window.
# corpus_result == 0xBBAA iff the DP-vs-abs split is correct on real silicon.
# A 0xBBBB/0x00BB result would mean DP and abs collided -> (a) is infeasible.
#
# Runs INSIDE the dev container; drive: dev/run.sh frameabi_a0. Prereqs:
# from-source toolchain (dev/run.sh toolchain) + SDK (dev/run.sh build).
# bsnes-jg cross-check reuses build/jgxcheck (dev/run.sh xcheck).
# See docs/plans/2026-06-20-321-frame-abi-build-all-three-and-measure.md (A0).
set -euo pipefail

usage() { echo "Usage: dev/run.sh frameabi_a0   # DP-window vs __rc collision proof; assert corpus_result==0xBBAA on both emulators"; exit 0; }
if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then usage; fi

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/frameabi_a0.c"
ROM="$BUILD/frameabi_a0.sfc"; MAP="$BUILD/frameabi_a0.map"; OBJ="$BUILD/frameabi_a0.o"
WANT=0xBBAA

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (DEFAULT 8-bit) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-14s %6s bytes\n' frameabi_a0.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: DP-window structure present (phd/pld; DP \$10 + abs \$0010 — the split)"
# NB: the 16-bit `lda #$1000; tcd` (bytes a9 00 10 5b) disassembles ambiguously —
# objdump can't track the runtime M flag, so it misreads it as an 8-bit lda + a
# phantom branch and swallows the tcd (5b). The BYTES are correct (verified) and
# the CPU reads them right once rep #$20 sets M=0; the runtime value is the real
# proof. We gate on the unambiguously-decoded ops: phd/pld and the DP-vs-abs split.
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
have() { printf '%s\n' "$DIS" | grep -ciE "^\s*[0-9a-f]+:\s*$1\b" || true; }
nphd=$(have '0b'); npld=$(have '2b')
ndp=$(have '85 10'); nabs=$(have '(8d|ad) 10 00')
[ "$nphd" -ge 1 ] && [ "$npld" -ge 1 ] && echo "  PASS: phd/pld D save+restore present" || { echo "  FAIL: missing phd/pld"; rc=1; }
[ "$ndp"  -ge 1 ] && echo "  PASS: DP access to \$10 present (the frame-local path)"      || { echo "  FAIL: no DP \$10 access"; rc=1; }
[ "$nabs" -ge 1 ] && echo "  PASS: absolute access to \$0010 present (the __rc-via-abs path)" || { echo "  FAIL: no abs \$0010 access"; rc=1; }
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (DP local \$1010=0xBB high, __rc abs \$0010=0xAA low)"
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
emu_verdict "$rc" "DP-window (D=\$1000) + __rc-via-absolute coexist: DP local 0xBB, abs __rc 0xAA -> 0xBBAA; both emulators agree"
exit $rc
