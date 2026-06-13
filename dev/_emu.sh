# dev/_emu.sh — shared MAME headless assertion helpers (sourced, not executed).
#
# Sourced by dev/smoke.sh and dev/corpus.sh. Runs INSIDE the dev container
# (/work = repo root, mame on PATH). The sourcing script owns `set -euo pipefail`;
# this file only defines functions and a couple of constants.
#
#   require_bios                       verify the SPC700 IPL is present; sets $ROMPATH.
#                                      Returns 2 (distinct from a 1 assert failure) if missing.
#   run_assert ROM MAP SYMBOL EXPECT   derive SYMBOL's WRAM address + byte length from MAP,
#                                      boot ROM headless in MAME under smoke.lua, assert the
#                                      SYMBOL bytes == EXPECT. Prints the SMOKE: line; returns
#                                      0 on PASS, 1 on FAIL.
set -euo pipefail

_EMU_ROOT=/work
_EMU_LUA="$_EMU_ROOT/dev/smoke.lua"
_EMU_SCRATCH=/tmp/mame-scratch

require_bios() {
  ROMPATH="${SNES_ROMPATH:-$_EMU_ROOT/dev/roms}"
  local bios="$ROMPATH/s_smp/spc700.rom"
  # MAME's snes driver requires the 64-byte SPC700 APU IPL ROM (Nintendo content;
  # never committed — see .gitignore). Without it MAME aborts before our assert with
  # "Required files are missing". Exit 2 lets callers tell "missing BIOS prereq" from
  # a 1 = "ran but produced the wrong bytes".
  if [ ! -f "$bios" ]; then
    echo "MISSING SNES BIOS: $bios"
    echo "  MAME's snes driver needs the SPC700 IPL ROM (sha1 97e352553e94242ae823547cd853eecda55c20f0)."
    echo "  Supply it out-of-band (gitignored): mkdir -p $ROMPATH/s_smp && cp <your>/spc700.rom $ROMPATH/s_smp/"
    echo "  Override the location with SNES_ROMPATH=<dir>."
    return 2
  fi
  mkdir -p "$_EMU_SCRATCH"
  return 0
}

# Print "<VMA-hex> <Size-hex>" for the symbol whose name is the last field of its
# linker-map line (cols: VMA LMA Size Align Out In Symbol). Empty if not found.
_emu_map_lookup() {
  awk -v s="$2" '$NF == s { print $1, $3; exit }' "$1"
}

run_assert() {
  local rom="$1" map="$2" sym="$3" expect="$4"
  local vma size addr len log

  read -r vma size < <(_emu_map_lookup "$map" "$sym") || true
  if [ -z "${vma:-}" ]; then
    echo "SMOKE: FAIL symbol '$sym' not found in $(basename "$map")"
    return 1
  fi
  # WRAM mirror: low-RAM globals live below $2000, mapped into $7E0000-$7E1FFF.
  addr=$(printf '0x%X' $(( 0x7E0000 + 0x$vma )))
  len=$(( 0x$size ))
  [ "$len" -ge 1 ] || len=1

  log="$_EMU_SCRATCH/assert-$(basename "$rom").log"
  # Headless MAME. SDL offscreen/dummy => no window/audio device. -skip_gameinfo =>
  # no warnings screen. -seconds_to_run is a hang backstop; smoke.lua self-exits first.
  # cfg/nvram to scratch so nothing is written into the mounted repo. `|| true` so a
  # nonzero mame exit can't abort the caller — the verdict comes only from the log.
  env SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy \
      SMOKE_ADDR="$addr" SMOKE_WANT="$expect" SMOKE_LEN="$len" SMOKE_SETTLE="${SMOKE_SETTLE:-60}" \
    mame snes -cart "$rom" \
      -rompath "$ROMPATH" \
      -autoboot_script "$_EMU_LUA" \
      -skip_gameinfo \
      -video none -sound none -nothrottle \
      -seconds_to_run 3 \
      -cfg_directory "$_EMU_SCRATCH" -nvram_directory "$_EMU_SCRATCH" \
    >"$log" 2>&1 || true

  local line
  line="$(grep -m1 '^SMOKE:' "$log" || true)"
  if [ -z "$line" ]; then
    echo "SMOKE: FAIL (no SMOKE: line — MAME never reached the assert; see $log)"
    return 1
  fi
  echo "$line"
  case "$line" in
    "SMOKE: PASS"*) return 0 ;;
    *) return 1 ;;
  esac
}
