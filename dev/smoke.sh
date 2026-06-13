#!/usr/bin/env bash
# dev/smoke.sh — boot the M0 SNES smoke ROM in MAME headless and assert it ran.
#
# Reads the `sentinel` address from build/hello.map, boots build/hello.sfc in MAME's
# `snes` driver under dev/smoke.lua, and exits 0 iff the Lua prints "SMOKE: PASS".
# MAME's own exit code is unreliable (it exits 0 even on a failed assert), so the
# verdict is read from stdout. Runs INSIDE the dev container (/work = repo root);
# drive it from the host with: dev/run.sh smoke.
set -euo pipefail

usage() {
  echo "Usage: dev/run.sh smoke   # boots build/hello.sfc in MAME, asserts sentinel==0x42"
  echo "Env: SMOKE_WANT (default 0x42), SMOKE_SETTLE (frames before sampling, default 60)"
  exit 0
}
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
ROM="$ROOT/build/hello.sfc"
MAP="$ROOT/build/hello.map"
LUA="$ROOT/dev/smoke.lua"
ROMPATH="${SNES_ROMPATH:-$ROOT/dev/roms}"
BIOS="$ROMPATH/s_smp/spc700.rom"
LOG=/tmp/snes-smoke.log
SCRATCH=/tmp/mame-scratch
mkdir -p "$SCRATCH"

[ -f "$ROM" ] || { echo "no $ROM — run 'dev/run.sh build' first"; exit 1; }
[ -f "$MAP" ] || { echo "no $MAP — run 'dev/run.sh build' first"; exit 1; }

# MAME's snes driver requires the 64-byte SPC700 APU IPL ROM (Nintendo content;
# never committed — see .gitignore). Without it MAME aborts before our assert with
# "Required files are missing". Exit 2 (distinct from a 1 = assertion failure) so
# CI/dev can tell "missing BIOS prereq" from "the ROM ran but produced the wrong byte".
if [ ! -f "$BIOS" ]; then
  echo "MISSING SNES BIOS: $BIOS"
  echo "  MAME's snes driver needs the SPC700 IPL ROM (sha1 97e352553e94242ae823547cd853eecda55c20f0)."
  echo "  Supply it out-of-band (it is gitignored): e.g."
  echo "    mkdir -p $ROMPATH/s_smp && cp <your>/spc700.rom $ROMPATH/s_smp/"
  echo "  Override the location with SNES_ROMPATH=<dir>."
  exit 2
fi

echo "==> MAME version: $(mame -version 2>/dev/null | head -1 || echo '?')"

# Derive the sentinel address from the linker map (don't hardcode — survives relayout).
# llvm-mos map line: "<VMA> <LMA> <size> <align>  sentinel"; take VMA, map it into the
# SNES WRAM mirror ($7E0000+) for an unambiguous 65816 program-space read.
zp=$(grep -E '\bsentinel\b' "$MAP" | awk '{print $1}' | head -1 || true)
[ -n "$zp" ] || { echo "could not find 'sentinel' in $MAP"; exit 1; }
addr=$(printf '0x%X' $(( 0x7E0000 + 0x$zp )))

echo "==> smoke: ROM=$(basename "$ROM")  sentinel@\$$zp -> WRAM $addr  (expect ${SMOKE_WANT:-0x42})"

# Headless MAME. SDL offscreen/dummy => no window or audio device needed.
# -skip_gameinfo => no "press any key" warning screen. -seconds_to_run is a hang
# backstop; smoke.lua self-exits (manager.machine:exit) well before it. cfg/nvram
# pointed at scratch so the run never writes into the mounted repo. The pipe can't
# abort the script (`|| true`) — the verdict comes only from grepping the log.
env SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy \
    SMOKE_ADDR="$addr" SMOKE_WANT="${SMOKE_WANT:-0x42}" SMOKE_SETTLE="${SMOKE_SETTLE:-60}" \
  mame snes -cart "$ROM" \
    -rompath "$ROMPATH" \
    -autoboot_script "$LUA" \
    -skip_gameinfo \
    -video none -sound none -nothrottle \
    -seconds_to_run 3 \
    -cfg_directory "$SCRATCH" -nvram_directory "$SCRATCH" \
  2>&1 | tee "$LOG" || true

echo
if grep -q '^SMOKE: PASS' "$LOG"; then
  echo "==> smoke PASS"
  exit 0
fi
echo "==> smoke FAIL"
grep '^SMOKE:' "$LOG" || echo "    (no SMOKE: line — MAME never reached the assert; see $LOG)"
exit 1
