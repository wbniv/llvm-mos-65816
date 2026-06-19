#!/usr/bin/env bash
# dev/a16call.sh — #321 cross-block REP/SEP mode-tracking: the M8-at-call rule.
#
# Builds examples/65816/a16call.c with +mos-a16. A function call sits between two
# 16-bit-accumulator adds. The 65816 calling convention runs 8-bit at every call
# boundary, so the pass must `sep #$20` back to 8-bit before the `jsl`/`jsr` and
# `rep #$20` afterwards. The gate tracks the accumulator width instruction by
# instruction and asserts it is 8-bit at the call. corpus_result == 0x4456 on BOTH
# MAME and bsnes-jg (a call left in 16-bit mode would corrupt the return).
#
# Runs INSIDE the dev container; drive: dev/run.sh a16call. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg leg reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-cross-block-repsep-mode-tracking.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16call   # call inside a 16-bit region: 8-bit A at the call boundary; corpus_result==0x4456 both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16call.c"
ROM="$BUILD/a16call.sfc"; MAP="$BUILD/a16call.map"; OBJ="$BUILD/a16call.o"
WANT=0x4456
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16call.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: accumulator is 8-bit at every call (sep before jsl/jsr, rep after)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" > "$BUILD/a16call.dis"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|2[02]|fc)\b' | head -30
# Track the M width down main: start 8-bit, rep -> 16-bit, sep -> 8-bit. Assert it
# is 8-bit at each call, and that at least one rep/sep bracket exists (so we really
# exercised the close-before-call / reopen-after path).
if ! python3 - "$BUILD/a16call.dis" <<'PY'
import sys, re
CALLS = {"jsr", "jsl"}
in_main = False
m16 = False
reps = seps = calls = 0
rc = 0
for ln in open(sys.argv[1]):
    fm = re.match(r'[0-9a-f]+ <([^>]+)>:', ln, re.I)
    if fm:
        in_main = (fm.group(1) == "main")
        continue
    if not in_main:
        continue
    m = re.match(r'\s*([0-9a-f]+):\s+([0-9a-f]{2}(?: [0-9a-f]{2})*)\s+(\S+)\s*(.*)',
                 ln, re.I)
    if not m:
        continue
    b, mn = m.group(2).lower(), m.group(3).lower()
    if b.startswith("c2 20"):
        m16 = True;  reps += 1
    elif b.startswith("e2 20"):
        m16 = False; seps += 1
    elif mn in CALLS:
        calls += 1
        if m16:
            print(f"  FAIL: call ({mn}) reached in 16-bit mode — 8-bit ABI violated"); rc = 1
        else:
            print(f"  PASS: 8-bit accumulator at the call ({mn})")
if calls == 0:
    print("  FAIL: no call found in main — expected a jsl/jsr"); rc = 1
if reps >= 1 and seps >= 1:
    print(f"  PASS: {reps} rep / {seps} sep — 16-bit work brackets the call")
else:
    print(f"  FAIL: expected a rep/sep bracket around the call, got {reps} rep / {seps} sep"); rc = 1
sys.exit(rc)
PY
then rc=1; fi
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (0x2345 -> ext -> 0x3345 + 0x1111)"
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
emu_verdict "$rc" "call executes in 8-bit mode inside a 16-bit region; both emulators read 0x4456"
exit $rc
