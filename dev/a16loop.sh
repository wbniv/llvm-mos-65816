#!/usr/bin/env bash
# dev/a16loop.sh — #321 cross-block REP/SEP mode-tracking: the must-win loop.
#
# Builds examples/65816/a16loop.c with +mos-a16. A natural loop with a fully
# 16-bit body must compile to ONE `rep #$20` before the loop and ONE `sep #$20`
# after it — with NO per-iteration rep/sep inside the body. The old per-block
# 8-bit anchoring toggled the mode every iteration; cross-block propagation hoists
# the rep to the preheader and sinks the sep to the exit. corpus_result == 0x2340
# (16 * 0x0234, low byte carries into high) on BOTH MAME and bsnes-jg.
#
# Runs INSIDE the dev container; drive: dev/run.sh a16loop. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK. bsnes-jg leg reuses build/jgxcheck.
# See docs/plans/2026-06-15-321-cross-block-repsep-mode-tracking.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh a16loop   # 16-bit loop body: one rep before / one sep after, none inside; corpus_result==0x2340 both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16loop.c"
ROM="$BUILD/a16loop.sfc"; MAP="$BUILD/a16loop.map"; OBJ="$BUILD/a16loop.o"
WANT=0x2340
# Enable 16-bit-accumulator mode (the clang driver rejects -mattr; use cc1 path).
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

echo "==> compile+link $SRC (+mos-a16) -> $(basename "$ROM")"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
printf '    %-12s %6s bytes\n' a16loop.sfc "$(stat -c%s "$ROM")"

rc=0
echo "==> disasm gate: exactly one rep #\$20 / one sep #\$20, and NONE inside any loop body"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
printf '%s\n' "$DIS" > "$BUILD/a16loop.dis"
printf '%s\n' "$DIS" | grep -iE '^\s*[0-9a-f]+:\s*(c2 20|e2 20|6[df]|c[df]|80|d0|f0|90|b0)\b' | head -30
# Position-aware check: a backward branch (target address < its own address)
# delimits a loop body [target, branch). No rep/sep byte may fall in that range,
# and there must be exactly one rep and one sep total.
if ! python3 - "$BUILD/a16loop.dis" <<'PY'
import sys, re
BRANCH = {"bra","brl","bcc","bcs","bne","beq","bpl","bmi","bvc","bvs"}
insns = []  # (addr, bytestr, mnemonic, operand)
for ln in open(sys.argv[1]):
    m = re.match(r'\s*([0-9a-f]+):\s+([0-9a-f]{2}(?: [0-9a-f]{2})*)\s+(\S+)\s*(.*)',
                 ln, re.I)
    if not m:
        continue
    insns.append((int(m.group(1), 16), m.group(2).lower(),
                  m.group(3).lower(), m.group(4).strip()))

reps = [a for (a, b, *_ ) in insns if b.startswith("c2 20")]
seps = [a for (a, b, *_ ) in insns if b.startswith("e2 20")]
rc = 0
if len(reps) == 1:
    print("  PASS: exactly one rep #$20 (hoisted to the preheader)")
else:
    print(f"  FAIL: expected 1 rep #$20, got {len(reps)}"); rc = 1
if len(seps) == 1:
    print("  PASS: exactly one sep #$20 (sunk to the loop exit)")
else:
    print(f"  FAIL: expected 1 sep #$20, got {len(seps)}"); rc = 1

# Find loop bodies via backward branches and assert no rep/sep inside.
modes = set(reps) | set(seps)
loops = 0
for (addr, b, mn, op) in insns:
    if mn not in BRANCH:
        continue
    tm = re.search(r'\$([0-9a-f]+)', op, re.I)
    if not tm:
        continue
    target = int(tm.group(1), 16)
    if target >= addr:          # forward branch / self-loop: no body to police
        continue
    loops += 1
    inside = [x for x in modes if target <= x < addr]
    if inside:
        print(f"  FAIL: rep/sep at {['0x%x'%x for x in inside]} inside loop body "
              f"[0x{target:x},0x{addr:x}) — per-iteration toggle not hoisted"); rc = 1
    else:
        print(f"  PASS: no rep/sep inside loop body [0x{target:x},0x{addr:x})")
if loops == 0:
    print("  FAIL: no backward branch found — expected a loop"); rc = 1
sys.exit(rc)
PY
then rc=1; fi
[ $rc -eq 0 ] || { echo "RESULT: FAIL (disasm gate)"; exit 1; }

echo "==> MAME: assert corpus_result == $WANT (16 * 0x0234, low byte carries)"
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
[ $rc -eq 0 ] && echo "RESULT: PASS — 16-bit loop body holds 16-bit mode across iterations (rep hoisted, sep sunk); both emulators read 0x2340" \
             || echo "RESULT: FAIL"
exit $rc
