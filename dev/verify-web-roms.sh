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

# A `live-record` self-check (the gallery's "verify the artwork on screen" button) is not a scalar
# compare, so it cannot be replayed as one: the ROM publishes WHICH work is on screen alongside what
# it repacked that work to, and the assertion is `ok == 1 && z == oracle[work]` against a table the
# host compressor produced. Replay it in two halves — jgxcheck asserts the record reached its ready
# state within `frames` (that is the scalar part, and it is what bounds the wait), and a post-check
# reads the 5-byte record out of the same run's WRAM dump and does the oracle lookup.
#
# Headless, this deterministically lands on the FIRST work: the machine starts at frame 0 with the
# record zeroed, exactly as the browser's `?verify=1` path does. Reproducible, not display-dependent.
#
# id<TAB>off<TAB>len<TAB>want<TAB>frames<TAB>mode<TAB>base
ROWS=$(ONLY="$ONLY" python3 - "$MANIFEST" <<'PY'
import json, os, sys
only = {s for s in os.environ.get("ONLY", "").split(",") if s}
for r in json.load(open(sys.argv[1]))["roms"]:
    sc = r.get("selfcheck")
    if not sc or (only and r["id"] not in only):
        continue
    if sc.get("mode") == "live-record":
        base = int(str(sc["off"]), 16)
        # the scalar half: poll `state` until it reaches `ready`
        row = [r["id"], hex(base + sc["record"]["state"]), "1", str(sc["ready"]),
               str(sc["frames"]), "live-record", hex(base)]
    else:
        row = [r["id"], str(sc["off"]), str(sc["len"]), str(sc["want"]), str(sc["frames"]),
               "scalar", "-"]
    print("\t".join(row))
PY
)

# Post-check for a live-record row: given the jgxcheck WRAM dump line, resolve the record and assert
# it against the manifest's host oracle. Prints one PASS/FAIL line; exits non-zero on FAIL.
record_check() {  # record_check <id> <output>
  MANIFEST="$MANIFEST" python3 - "$1" <<'PY'
import json, os, re, sys
sc = next(r["selfcheck"] for r in json.load(open(os.environ["MANIFEST"]))["roms"]
          if r["id"] == sys.argv[1])
rec, dump = sc["record"], os.environ.get("JGXOUT", "")
m = re.search(r"jgxcheck: WRAM @0x[0-9A-Fa-f]+:((?: [0-9A-Fa-f]{2})+)", dump)
if not m:
    print("no WRAM dump in jgxcheck output"); sys.exit(1)
b = [int(x, 16) for x in m.group(1).split()]
state, work = b[rec["state"]], b[rec["work"]]
z, ok = b[rec["z"][0]] | (b[rec["z"][0] + 1] << 8), b[rec["ok"]]
name = (sc.get("titles") or [])[work] if work < len(sc.get("titles") or []) else f"work {work}"
if state != sc["ready"]:
    print(f"record never reached ready (state={state})"); sys.exit(1)
want = sc["oracle"][work]
if ok != 1:
    print(f"{name}: the ROM's own byte-compare rejected its repack (ok=0)"); sys.exit(1)
if z != want:
    print(f"{name}: repacked {z} B, host oracle says {want} B"); sys.exit(1)
print(f"{name}: repacked on-SNES to {z} B == host oracle")
PY
}

pass=0; fail=0; missing=0; failed=""
while IFS=$'\t' read -r id off len want frames mode base; do
  [ -n "$id" ] || continue
  rom="$SITE/public/play/roms/$id.sfc"
  if [ ! -f "$rom" ]; then
    printf '  %-16s MISSING %s\n' "$id" "$rom"; missing=$((missing+1)); continue
  fi
  if [ "$mode" = "live-record" ]; then
    # JGX_POLL: `frames` is the player's budget, not a rendezvous — stop the instant the record
    # reaches `ready`, exactly as the browser's chunked poll does. Without it a fixed frame count
    # would have to land inside the ~530-frame ready window of a ~9100-frame cycle.
    out=$(JGX_BLANKSCAN=1 JGX_POLL=1 JGX_WRAM_DUMP="$base" JGX_WRAM_DUMP_LEN=5 \
            "$JGX" "$rom" "$DB" "$off" "$len" "$want" "$frames" 2>&1 || true)
    detail=$(JGXOUT="$out" record_check "$id" 2>&1) || {
      printf '  %-16s FAIL  live-record: %s\n' "$id" "$detail"
      fail=$((fail+1)); failed="$failed $id"; continue
    }
  else
    out=$(JGX_BLANKSCAN=1 "$JGX" "$rom" "$DB" "$off" "$len" "$want" "$frames" 2>&1 || true)
    detail=""
  fi
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
    if [ -n "$detail" ]; then
      printf '  %-16s PASS  (%s frames, %s)\n' "$id" "$frames" "$detail"
    else
      printf '  %-16s PASS  (%s frames, want %s)\n' "$id" "$frames" "$want"
    fi
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
