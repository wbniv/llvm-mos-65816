#!/usr/bin/env bash
# dev/_check.sh — shared differential-kernel runner (sourced, not executed).
#
# Provides diff_check NAME EXPECTED: compile examples/65816/NAME.c twice (DEFAULT and
# +mos-a16), run both on MAME (+ a16 on bsnes-jg), and assert
#     host/baked EXPECTED == default@MAME == a16@MAME == a16@bsnes-jg
# plus a clean -verify-machineinstrs on the +mos-a16 build. The heavy lifting is in
# tools/a16_fuzz.py `check`; this just guards prereqs. Runs INSIDE the dev container.
# Used by dev/k_*.sh (realistic kernels) and dev/a16mix*.sh (combinatorial tests).
set -euo pipefail

diff_check() {
  local name="$1" expected="${2-}"
  local ROOT=/work
  local TOOL="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin"
  [ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
  [ -f "$ROOT/build/install/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$ROOT/build/llvm-mos-install dev/run.sh build)"; exit 1; }
  source "$ROOT/dev/_emu.sh"
  require_bios || exit $?
  local args=(check --src "$ROOT/examples/65816/$name.c" --name "$name")
  [ -n "$expected" ] && args+=(--expected "$expected")
  [ -x "$ROOT/build/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ] || args+=(--no-bsnes)
  exec python3 "$ROOT/tools/a16_fuzz.py" "${args[@]}"
}
