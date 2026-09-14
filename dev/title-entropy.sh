#!/usr/bin/env bash
# dev/title-entropy.sh — entropy-sweep robustness gate for a demo's TITLE window.
#
# WHY THIS EXISTS
# ---------------
# Every other picture gate in the tree runs at JGX_ENTROPY=0, where bsnes-jg powers the SNES on with
# a zeroed PPU. That hides a whole class of defect: a ROM that never writes a PPU control register
# it depends on renders correctly at entropy 0 and differently on every real power-on. The web
# player runs bsnes-jg's OWN default (Low entropy = every $2101..$2133 register seeded from
# random()), so the viewer is the one who sees it.
#
# mandel-oop was the witness (TODO M2 / plan 2026-07-26-121, "Title-window entropy root cause"):
# snesgfx/m7title.h's m7splash_begin() runs BEFORE display_init(), i.e. before the boot path's only
# snes_ppu_reset_blank(), so CGWSEL $2130's colour-window "clip to black" field was whatever the
# power-on left — clipping the main screen always (a black title card), inside/outside a random
# window (black bands across the glyphs), or not at all (the correct picture), run to run.
#
# WHAT IT ASSERTS
#   For each frame: render once at JGX_ENTROPY=0 (the deterministic reference) and RUNS times at
#   JGX_ENTROPY=1 (the player's setting). Every entropy-1 picture must hash identically to the
#   entropy-0 one. Any mismatch = a PPU/CGRAM/OAM/VRAM state the ROM reads before writing.
#
# Usage: dev/title-entropy.sh <rom.sfc> [--runs N] [--frames 60,100,120,200]
set -euo pipefail

usage() { sed -n '2,25p' "$0"; }
case "${1-}" in -h|--help|"") usage; exit 0;; esac

ROM=$1; shift
RUNS=20
FRAMES=60,100,120,200
while [ $# -gt 0 ]; do
  case "$1" in
    --runs)   RUNS=$2; shift 2;;
    --frames) FRAMES=$2; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "title-entropy: unknown argument $1" >&2; exit 2;;
  esac
done

ROOT=$(cd "$(dirname "$0")/.." && pwd)
JGX=${JGX:-$ROOT/build/jgxcheck}
DB=${JGX_DB:-$ROOT/vendor/bsnes-jg/Database}
[ -x "$JGX" ] || { echo "FATAL: no jgxcheck at $JGX (run: dev/run.sh mandel-oop once to build it)"; exit 1; }
[ -f "$ROM" ] || { echo "FATAL: no such ROM: $ROM"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0

echo "==> title-entropy: $(basename "$ROM") — $RUNS entropy-1 runs per frame vs the entropy-0 reference"
for F in ${FRAMES//,/ }; do
  # The WRAM assert arguments are irrelevant here (this gate reads the PICTURE), so they are the
  # mandel-oop defaults and a SMOKE FAIL at a pre-corpus frame is expected and ignored.
  JGX_ENTROPY=0 "$JGX" "$ROM" "$DB" 897 2 204F "$F" "$TMP/ref.png" >/dev/null 2>&1 || true
  [ -s "$TMP/ref.png" ] || { echo "  frame $F: FAIL — entropy-0 render produced no PNG"; fail=1; continue; }
  REF=$(sha256sum "$TMP/ref.png" | cut -c1-12)
  bad=0
  for ((i = 0; i < RUNS; i++)); do
    rm -f "$TMP/run.png"
    JGX_ENTROPY=1 "$JGX" "$ROM" "$DB" 897 2 204F "$F" "$TMP/run.png" >/dev/null 2>&1 || true
    got=$(sha256sum "$TMP/run.png" 2>/dev/null | cut -c1-12 || true)
    [ "$got" = "$REF" ] || bad=$((bad + 1))
  done
  if [ "$bad" -eq 0 ]; then
    printf '  frame %4s: PASS  %d/%d entropy-1 runs == entropy-0 %s\n' "$F" "$RUNS" "$RUNS" "$REF"
  else
    printf '  frame %4s: FAIL  %d/%d entropy-1 runs differ from entropy-0 %s\n' "$F" "$bad" "$RUNS" "$REF"
    fail=1
  fi
done

[ "$fail" -eq 0 ] && echo "TITLE-ENTROPY: PASS" || echo "TITLE-ENTROPY: FAIL"
exit "$fail"
