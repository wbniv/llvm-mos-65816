#!/usr/bin/env bash
# dev/xcheck-suite.sh — #321 second-emulator (bsnes-jg) ONLY confirmation pass.
#
# Runs the value-differential micro-tests' bsnes-jg leg WITHOUT booting MAME, by
# exporting JG_ONLY=1 (the dev/_emu.sh run_assert/require_bios guard turns the MAME
# leg into a no-op). The bsnes-jg leg (build/jgxcheck) is DETERMINISTIC — a fixed
# frame count + a direct WRAM read, no Lua bridge / settle window — so this pass is
# load-insensitive, needs no quiet box and no SPC700 BIOS. Tests run SERIALLY (one
# core, nice -n 19) so it stays a light neighbour to any concurrent MAME. The
# disasm/llc gates inside each test still run; only the MAME emulator leg is skipped.
#
# Drive: dev/run.sh xcheck-suite [PREFIX]   (PREFIX filters by basename stem:
# `xy16`, `a16eq`, …; default = all a16*/xy16* tests that carry a jgxcheck leg).
# Prereqs: from-source toolchain + SDK + build/jgxcheck (the last via dev/run.sh
# xcheck). See docs/plans/2026-06-19-second-emulator-jg-only-confirmation.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh xcheck-suite [PREFIX]   # bsnes-jg-only (JG_ONLY) pass over the a16/xy16 value tests (PREFIX filters, e.g. xy16); deterministic, no MAME, no BIOS"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
PREFIX="${1:-}"
LOGDIR="$BUILD/xcheck-suite"   # under /work (mounted) so per-test logs persist on the host
mkdir -p "$LOGDIR"

# Prereqs — fail loudly rather than letting 45 tests each FATAL or (worse) silently
# SKIP their bsnes-jg leg, which would make this a no-op "confirmation".
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }
[ -x "$BUILD/jgxcheck" ] || { echo "FATAL: no build/jgxcheck — the bsnes-jg leg would SKIP (run: dev/run.sh xcheck first)"; exit 1; }
[ -d "$ROOT/vendor/bsnes-jg/Database" ] || { echo "FATAL: vendor/bsnes-jg/Database missing (run: dev/run.sh xcheck first)"; exit 1; }

# The value-test set = a16*/xy16* scripts that carry a jgxcheck leg. Compile-only
# gates (no jgxcheck: a16spill, a16mix*, a16spillir, xy16spill, …) are auto-excluded.
mapfile -t TESTS < <(grep -l jgxcheck "$ROOT"/dev/a16*.sh "$ROOT"/dev/xy16*.sh | sort)
if [ -n "$PREFIX" ]; then
  filtered=()
  for t in "${TESTS[@]}"; do case "$(basename "$t")" in "$PREFIX"*) filtered+=("$t");; esac; done
  TESTS=("${filtered[@]:-}")
fi
[ -n "${TESTS[0]:-}" ] || { echo "FATAL: no jgxcheck-carrying test matches PREFIX='$PREFIX'"; exit 1; }

echo "==> bsnes-jg-only (JG_ONLY) confirmation — ${#TESTS[@]} value test(s)${PREFIX:+ matching '$PREFIX'}, serial, nice -n 19"
echo "    MAME leg skipped; deterministic bsnes-jg leg only. logs: $LOGDIR/"
echo

pass=0; fail=0; skipped=0; bad=()
for t in "${TESTS[@]}"; do
  name="$(basename "$t" .sh)"
  log="$LOGDIR/$name.log"
  if JG_ONLY=1 nice -n 19 bash "$t" >"$log" 2>&1; then
    ec=0
  else
    ec=$?
  fi
  # The real bsnes-jg verdict line: jgxcheck prints "...(ran N frames, bsnes-jg)".
  # Its PRESENCE is the positive proof the second-emulator leg actually ran (a green
  # exit alone can also mean the leg SKIPped when build/jgxcheck is absent).
  jgline="$(grep -m1 'frames, bsnes-jg' "$log" | sed 's/^[[:space:]]*//' || true)"
  if [ "$ec" -ne 0 ]; then
    printf "  FAIL  %-16s (exit %d; see %s)\n" "$name" "$ec" "$log"
    tail -3 "$log" | sed 's/^/        | /'
    fail=$((fail+1)); bad+=("$name")
  elif [ -z "$jgline" ]; then
    printf "  SKIP  %-16s (no bsnes-jg result line — leg did not run; see %s)\n" "$name" "$log"
    skipped=$((skipped+1)); bad+=("$name(jg-skip)")
  else
    printf "  PASS  %-16s %s\n" "$name" "$jgline"
    pass=$((pass+1))
  fi
done

echo
total=${#TESTS[@]}
if [ "$fail" -eq 0 ] && [ "$skipped" -eq 0 ]; then
  echo "RESULT: PASS — $pass/$total bsnes-jg value tests agree (second emulator confirmed, MAME not run)"
  exit 0
else
  echo "RESULT: FAIL — $pass/$total PASS, $fail FAIL, $skipped jg-SKIP: ${bad[*]}"
  exit 1
fi
