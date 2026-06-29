#!/usr/bin/env bash
# dev/buddha-grid.sh — #4 Buddhabrot: the headless far SCATTER-WRITE density-grid gate.
#
# Proves the +mos-a16 far codegen customer the on-screen Buddhabrot renderer depends on, with zero
# display risk ("mandel-far / blossom-grid for Buddhabrot"): draw K_GATE random complex samples
# (deterministic xorshift16), iterate z^2+c, and for the ESCAPING orbits replay each orbit into a
# 128x128 hit-count grid at high WRAM $7E2000 via the far path — each visited point a far RMW
# (lda [dp] / saturate / inc / sta [dp]) at a RUNTIME-computed index — then roll a far-load hash into
# NEAR corpus_result.
#
# The golden is DERIVED from the host oracle (cc -DHOST over the SAME examples/65816/buddha.h), so it
# can't drift if K_GATE changes. A far pointer is a 32-bit value => +mos-a16-only, so this is
# host == +mos-a16 on MAME + bsnes-jg, plus a far-RMW + complex-multiply disasm gate, -verify clean.
#
# Drive: dev/run.sh buddha-grid.  Plan: docs/plans/2026-06-28-4-snes-buddhabrot.md.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh buddha-grid   # Buddhabrot far scatter-write density grid into high WRAM (host==+mos-a16)"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/k_buddha_far.c"
ROM="$BUILD/k_buddha_far.sfc"
MAP="$BUILD/k_buddha_far.map"
OBJ="$BUILD/k_buddha_far.o"
A16=(-Xclang -target-feature -Xclang +mos-a16)
# Heavy kernel: 16 KiB volatile far clear + K_GATE samples (each up to BUD_MAXITER iters x 3 __mulsi3,
# twice) + 16 KiB far-load hash. Settles later than blossom's 1-mul/point orbit; give it room.
export SMOKE_SETTLE="${SMOKE_SETTLE:-1500}"
export SMOKE_SECONDS="${SMOKE_SECONDS:-30}"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: dev/run.sh build)"; exit 1; }

echo "==> 1) host oracle derives the golden grid hash (cc -DHOST over buddha.h)"
cc -DHOST -O2 -o "$BUILD/k_buddha_far_host" "$SRC"
HOSTOUT="$("$BUILD/k_buddha_far_host" 2>&1 1>/dev/null || true)"
WANT="$("$BUILD/k_buddha_far_host")"
echo "    $HOSTOUT"
echo "    golden grid hash = $WANT"

echo "==> 2) compile+link (mos-snes.cfg -mcpu=mosw65816 +mos-a16 -Os -verify)"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null

rc=0
echo "==> 3) disasm gate: far RMW indirect-long (a7=lda [dp], 87=sta [dp]) + native 16-bit + complex multiply"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -c -o "$OBJ" "$SRC"
DIS="$("$TOOL/llvm-objdump" -d --mcpu=mosw65816 "$OBJ")"
NA7=$(echo "$DIS" | grep -ciE '^[[:space:]]*[0-9a-f]+:[[:space:]]*a7 ' || true)
N87=$(echo "$DIS" | grep -ciE '^[[:space:]]*[0-9a-f]+:[[:space:]]*87 ' || true)
NC2=$(echo "$DIS" | grep -ciE '^[[:space:]]*[0-9a-f]+:[[:space:]]*c2 ' || true)
NE2=$(echo "$DIS" | grep -ciE '^[[:space:]]*[0-9a-f]+:[[:space:]]*e2 ' || true)
DISR="$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$OBJ" 2>/dev/null || true)"
NMUL=$(echo "$DISR" | grep -cE '__mulsi3|__umulsi3' || true)
if [ "${NA7:-0}" -ge 1 ] && [ "${N87:-0}" -ge 1 ]; then
  echo "  PASS: far RMW present (lda [dp]=$NA7, sta [dp]=$N87)"
else
  echo "  FAIL: far RMW not indirect-long (lda [dp]=$NA7, sta [dp]=$N87)"; rc=1
fi
if [ "${NC2:-0}" -ge 4 ] && [ "${NE2:-0}" -ge 4 ]; then
  echo "  PASS: native 16-bit active (rep=$NC2, sep=$NE2)"
else
  echo "  FAIL: native 16-bit not firing (rep=$NC2, sep=$NE2)"; rc=1
fi
if [ "${NMUL:-0}" -ge 1 ]; then
  echo "  PASS: complex multiply present (__mulsi3/__umulsi3=$NMUL)"
else
  echo "  FAIL: no 32-bit multiply (__mulsi3/__umulsi3=$NMUL)"; rc=1
fi

# bsnes-jg leg (independent core, no SPC700 IPL needed) — the demo bar; carries the verdict.
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
  echo "==> 4) execution gate (bsnes-jg): corpus_result == $WANT"
  "$JGX" "$ROM" "$VENDOR/Database" "0x$VMA" 2 "$WANT" 5000 || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# MAME leg (bonus cross-check) — a missing SPC700 IPL is env-wide and NON-blocking for demos, so a
# missing BIOS SKIPs rather than failing (the bsnes-jg leg above is the verdict).
echo "==> 5) execution gate (MAME, bonus): far density grid hash -> corpus_result == $WANT"
source "$ROOT/dev/_emu.sh"
if require_bios; then
  run_assert "$ROM" "$MAP" corpus_result "$WANT" || rc=1
else
  echo "    SKIP MAME (no SPC700 IPL — bsnes-jg carries the verdict; non-blocking per demos policy)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Buddhabrot far scatter-write density grid in high WRAM \$7E2000; hash $WANT host == +mos-a16 (MAME + bsnes-jg)"
else
  echo "RESULT: FAIL — see the per-step lines above"
fi
exit $rc
