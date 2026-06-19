#!/usr/bin/env bash
# dev/csmith.sh — #321 Csmith differential +mos-a16 fuzzer (runs HOST-side, NOT in Docker).
#
# Unlike dev/fuzz.sh (the builtin generator, run inside the dev container), the Csmith path
# runs on the host: csmith is built on the host into gitignored vendor/csmith, and MAME +
# bsnes-jg are host tools. tools/csmith_run.py generates one UB-free-at-16-bit C program per
# seed (csmith reads examples/65816/csmith/platform.info → `integer size = 2`), force-includes
# the freestanding adapter, host-filters non-buildable seeds, then runs the trusted-DEFAULT-
# build-as-oracle differential (default == +mos-a16 == +mos-xy16, + the bsnes-jg leg).
#
# Driven by dev/run.sh's `fuzz --gen csmith` dispatch; or directly:
#   dev/csmith.sh [N] [seed]        # default: 25 programs from seed 1
#   dev/csmith.sh 1 11              # reproduce a single seed
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK; csmith is built on demand
# (dev/fetch-csmith.sh); the bsnes-jg leg reuses build/jgxcheck when present, else SKIPs it.
# See docs/plans/2026-06-19-321-csmith-differential-fuzzer.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh fuzz --gen csmith [N] [seed]   # N Csmith differential programs (host==default==a16==xy16)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
TOOL="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$ROOT/build/install/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$ROOT/build/llvm-mos-install dev/run.sh build)"; exit 1; }

# Build Csmith on demand (no-op if vendor/csmith/bin/csmith already exists).
"$HERE/fetch-csmith.sh"

# MAME's snes driver needs the 64-byte SPC700 IPL ROM (gitignored Nintendo content).
BIOS="${SNES_ROMPATH:-$ROOT/dev/roms}/s_smp/spc700.rom"
if [ ! -f "$BIOS" ]; then
  echo "MISSING SNES BIOS: $BIOS"
  echo "  MAME's snes driver needs the SPC700 IPL ROM (sha1 97e352553e94242ae823547cd853eecda55c20f0)."
  echo "  Supply it out-of-band (gitignored), or override the location with SNES_ROMPATH=<dir>."
  exit 2
fi
command -v mame >/dev/null || { echo "FATAL: mame not on PATH (the Csmith differential runs host-side)"; exit 1; }

N="${1:-25}"
SEED="${2:-1}"
EXTRA=()
[ -x "$ROOT/build/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ] || EXTRA+=(--no-bsnes)

export FUZZ_ROOT="$ROOT"
export MOS_TOOLCHAIN="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}"
exec python3 "$ROOT/tools/csmith_run.py" --count "$N" --seed "$SEED" "${EXTRA[@]}"
