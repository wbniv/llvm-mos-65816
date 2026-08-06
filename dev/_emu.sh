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
#   emu_verdict RC "PASS detail"       print the closing verdict line: `RESULT: FAIL` when RC!=0,
#                                      else `RESULT: PASS — <detail>`. Under JG_ONLY it rewrites any
#                                      "both emulators …" claim in <detail> to name only bsnes-jg, so
#                                      a MAME-skipped run never claims a MAME result it did not produce.
#                                      Always returns 0 (the caller still does `exit $rc`).
#
#   JG_ONLY=1 (env)                    bsnes-jg-only pass: require_bios + run_assert become no-ops
#                                      (the MAME leg is skipped), so a caller runs its deterministic
#                                      bsnes-jg leg alone — no MAME, no SPC700 BIOS, load-insensitive.
#                                      Used by dev/xcheck-suite.sh; see the step-6 second-emulator plan.
#   SMOKE_SETTLE / SMOKE_SECONDS (env) slow-kernel tuning. SMOKE_SETTLE = ticks (~frames) smoke.lua
#                                      waits before sampling; SMOKE_SECONDS = MAME's -seconds_to_run
#                                      backstop (default 3). A heavy kernel whose main() stores its
#                                      result late (e.g. k_trig32 ~600 frames) raises BOTH.
set -euo pipefail

_EMU_ROOT=/work
_EMU_LUA="$_EMU_ROOT/dev/smoke.lua"
_EMU_SCRATCH=/tmp/mame-scratch

require_bios() {
  # bsnes-jg-only pass (JG_ONLY=1): the bsnes-jg core needs no SPC700 IPL, so skip the
  # MAME BIOS gate. Still set ROMPATH + scratch (harmless, matches the normal path) but
  # never fail on a missing BIOS — the deterministic bsnes-jg leg carries the verdict.
  if [ "${JG_ONLY:-}" = "1" ]; then
    ROMPATH="${SNES_ROMPATH:-$_EMU_ROOT/dev/roms}"
    mkdir -p "$_EMU_SCRATCH"
    return 0
  fi
  ROMPATH="${SNES_ROMPATH:-$_EMU_ROOT/dev/roms}"
  local bios="$ROMPATH/s_smp/spc700.rom"
  # MAME's snes driver requires the 64-byte SPC700 APU IPL ROM (Nintendo content;
  # never committed — see .gitignore). Without it MAME aborts before our assert with
  # "Required files are missing". Exit 2 lets callers tell "missing BIOS prereq" from
  # a 1 = "ran but produced the wrong bytes".
  if [ -x "$_EMU_ROOT/dev/fetch-spc700.sh" ] &&
     ! SNES_ROMPATH="$ROMPATH" "$_EMU_ROOT/dev/fetch-spc700.sh" --check >/dev/null 2>&1; then
    # Normally dev/run.sh fetches on the host before starting this container. Keep
    # the shared gate self-healing too for direct/container callers that provide AWS.
    SNES_ROMPATH="$ROMPATH" "$_EMU_ROOT/dev/fetch-spc700.sh" || true
  fi
  if [ ! -f "$bios" ] ||
     ! SNES_ROMPATH="$ROMPATH" "$_EMU_ROOT/dev/fetch-spc700.sh" --check >/dev/null 2>&1; then
    echo "MISSING SNES BIOS: $bios"
    echo "  MAME's snes driver needs the SPC700 IPL ROM (sha1 97e352553e94242ae823547cd853eecda55c20f0)."
    echo "  Fetch it on the host with dev/fetch-spc700.sh, or supply it out-of-band."
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
  # bsnes-jg-only pass (JG_ONLY=1): skip the MAME leg entirely — each test's own
  # bsnes-jg block still runs. Return 0 so the caller's `|| rc=1` is a no-op; the
  # verdict comes from the deterministic bsnes-jg check, not MAME.
  if [ "${JG_ONLY:-}" = "1" ]; then
    echo "SMOKE: SKIP (JG_ONLY — MAME leg skipped; bsnes-jg leg still runs)"
    return 0
  fi
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
  # SMOKE_SECONDS (default 3) parameterizes that backstop in EMULATED seconds: a heavy
  # realistic kernel (e.g. k_trig32's libfixmath software-32-bit-divide sweep, ~600 frames
  # to reach main()'s store) needs both a larger SMOKE_SETTLE and a backstop past it, since
  # at ~60 fps -seconds_to_run S caps the run at ~60*S frames. Existing callers set neither
  # and keep the historical 3 s / 60-tick behavior byte-for-byte.
  # cfg/nvram to scratch so nothing is written into the mounted repo. `|| true` so a
  # nonzero mame exit can't abort the caller — the verdict comes only from the log.
  env SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy \
      SMOKE_ADDR="$addr" SMOKE_WANT="$expect" SMOKE_LEN="$len" SMOKE_SETTLE="${SMOKE_SETTLE:-60}" \
    mame snes -cart "$rom" \
      -rompath "$ROMPATH" \
      -autoboot_script "$_EMU_LUA" \
      -skip_gameinfo \
      -video none -sound none -nothrottle \
      -seconds_to_run "${SMOKE_SECONDS:-3}" \
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

# emu_verdict RC "PASS detail" — the shared closing verdict line.
# RC!=0 → "RESULT: FAIL"; else "RESULT: PASS — <detail>". Under JG_ONLY the MAME leg
# did not run, so rewrite any "both emulators …" agreement claim in <detail> to name
# only bsnes-jg. Always returns 0; the caller still does its own `exit $rc`.
emu_verdict() {
  local rc="$1" detail="$2"
  if [ "$rc" -ne 0 ]; then echo "RESULT: FAIL"; return 0; fi
  if [ "${JG_ONLY:-}" = "1" ]; then
    # Cover every "both emulators …" phrasing the 45 tests use (agree / on both /
    # read 0xNN / "(both emulators)" / trailing ", both emulators"). Order: specific
    # → general. A novel future phrasing just falls through unrewritten (cosmetic,
    # never a regression) — new tests should say "both emulators agree".
    detail="$(printf '%s' "$detail" | sed -E \
      -e 's/both emulators read ([0-9A-Fx]+)/bsnes-jg reads \1 (MAME skipped)/g' \
      -e 's/(;?[[:space:]]*)both emulators agree/\1bsnes-jg confirmed (MAME skipped)/g' \
      -e 's/on both emulators/on bsnes-jg (MAME skipped)/g' \
      -e 's/\(both emulators\)/(bsnes-jg only; MAME skipped)/g' \
      -e 's/,?[[:space:]]+both emulators/, bsnes-jg only (MAME skipped)/g')"
  fi
  echo "RESULT: PASS — $detail"
  return 0
}
