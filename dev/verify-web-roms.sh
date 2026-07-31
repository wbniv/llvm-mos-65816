#!/usr/bin/env bash
# dev/verify-web-roms.sh — assert EVERY published web ROM against the manifest, before deploying.
#
# The site's roms/manifest.json already carries each demo's in-browser fidelity self-check
# (off/len/want/frames) — the same assertion the WASM player runs. That makes it a ready-made
# acceptance test for a bulk rebuild: replay each ROM headlessly in bsnes-jg and require the WRAM
# gate value to match. A rebuild that changed any demo's result shows up here rather than in a
# visitor's browser.
#
# Each ROM is also scanned for force-blank bleed (JGX_BLANKSCAN — a one-frame black band at the top
# of the picture, the signature of a DMA that overran v-blank while force-blanked).
#
# The bleed scan requires the spike to sit on a QUIESCENT baseline, because a demo that wipes or
# rebuilds its picture produces local maxima that are not bleed: lsystem's canvas_clear() reaches
# VRAM over 4 frames (CANVAS_FLUSH_TILES caps the flush) while its regrowth restarts from the trunk,
# and the frame where those two fronts cross is a local max by construction. Consequence to know
# about: a genuine bleed landing INSIDE a wipe/fade/scene change is not reported. Suppressions are
# always printed with their window spread, never silent.
# See docs/plans/2026-07-30-blankscan-quiescence-gate.md.
#
# Host-side; uses the prebuilt build/jgxcheck harness. Exits non-zero if any demo fails.
#
#   dev/verify-web-roms.sh                 # verify ~/biohack.net
#   dev/verify-web-roms.sh --site DIR
#   dev/verify-web-roms.sh --only huffman,maze
set -euo pipefail

case "${1-}" in -h|--help)
  cat <<'USAGE'
Usage: dev/verify-web-roms.sh [--site DIR] [--only slug[,slug...]]

Replays every ROM in <site>/public/play/roms against its manifest.json self-check in bsnes-jg and
scans each for force-blank bleed. Exits 1 if any demo mismatches or shows a black-band spike.

  --site DIR   site checkout (default: ~/biohack.net)
  --only LIST  comma-separated slugs instead of the whole manifest
USAGE
  exit 0;; esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="$HOME/biohack.net"
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --site) SITE="$2"; shift 2;;
    --only) ONLY="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

JGX="$ROOT/build/jgxcheck"
DB="$ROOT/vendor/bsnes-jg/Database"
MANIFEST="$SITE/public/play/roms/manifest.json"

[ -x "$JGX" ]      || { echo "FATAL: no jgxcheck at $JGX (run: dev/run.sh xcheck)"; exit 1; }
[ -d "$DB" ]       || { echo "FATAL: no bsnes-jg Database at $DB"; exit 1; }
[ -f "$MANIFEST" ] || { echo "FATAL: no manifest at $MANIFEST"; exit 1; }

# id<TAB>off<TAB>len<TAB>want<TAB>frames
ROWS=$(ONLY="$ONLY" python3 - "$MANIFEST" <<'PY'
import json, os, sys
only = {s for s in os.environ.get("ONLY", "").split(",") if s}
for r in json.load(open(sys.argv[1]))["roms"]:
    sc = r.get("selfcheck")
    if not sc or (only and r["id"] not in only):
        continue
    print("\t".join([r["id"], str(sc["off"]), str(sc["len"]), str(sc["want"]), str(sc["frames"])]))
PY
)

pass=0; fail=0; missing=0; failed=""
while IFS=$'\t' read -r id off len want frames; do
  [ -n "$id" ] || continue
  rom="$SITE/public/play/roms/$id.sfc"
  if [ ! -f "$rom" ]; then
    printf '  %-16s MISSING %s\n' "$id" "$rom"; missing=$((missing+1)); continue
  fi
  out=$(JGX_BLANKSCAN=1 "$JGX" "$rom" "$DB" "$off" "$len" "$want" "$frames" 2>&1 || true)
  # `|| true`: a grep that matches nothing exits 1, and under `set -e` that kills the run mid-way
  # with no summary — which is exactly how an earlier version of this script silently stopped at
  # demo 33 of 113 and looked like a clean pass.
  # Match the VERDICT line explicitly, not "BLANKSCAN: <anything>". jgxcheck also prints
  # informational lines BEFORE the verdict (e.g. "BLANKSCAN: frame 1154 spike 149 ignored — …"),
  # and `BLANKSCAN: [A-Z]*` matches those with an empty capture, so `head -1` yielded a bare
  # "BLANKSCAN: " and failed a demo that had passed both checks.
  smoke=$(printf '%s' "$out" | grep -oE 'SMOKE: (PASS|FAIL)' | head -1 || true)
  blank=$(printf '%s' "$out" | grep -oE 'BLANKSCAN: (PASS|FAIL)' | head -1 || true)
  if [ "$smoke" = "SMOKE: PASS" ] && [ "$blank" = "BLANKSCAN: PASS" ]; then
    printf '  %-16s PASS  (%s frames, want %s)\n' "$id" "$frames" "$want"
    pass=$((pass+1))
  else
    printf '  %-16s FAIL  %s %s\n' "$id" "${smoke:-no-smoke}" "${blank:-no-blankscan}"
    printf '%s\n' "$out" | grep -E 'SMOKE|BLANKSCAN' | sed 's/^/                     /' || true
    printf '%s\n' "$out" | tail -3 | sed 's/^/                     /' || true
    fail=$((fail+1)); failed="$failed $id"
  fi
done <<< "$ROWS"

echo
echo "verify-web-roms: $pass passed, $fail failed, $missing missing"
if [ "$fail" -ne 0 ]; then echo "FAILED:$failed"; exit 1; fi
if [ "$missing" -ne 0 ]; then echo "some ROMs missing from $SITE"; exit 1; fi
echo "ALL PASS — safe to publish"
