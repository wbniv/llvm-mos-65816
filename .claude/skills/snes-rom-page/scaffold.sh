#!/usr/bin/env bash
# scaffold.sh — add one SNES ROM to an Astro site that consumes the
# @wbniv/bsnes-jg-player npm package. Mechanical bits only: engine sync (via the
# package's own CLI), ROM copy, preview recompress, manifest entry. The page
# content (biohack: src/content/snes/<slug>.json; indri: gallery registry entry)
# is written by the skill/agent per SKILL.md.
#
# Writes under <site>/<playdir>/ :
#   app.js  cores/*  ENGINE_VERSION      (bsnes-jg-player sync — engine, drift-stamped)
#   roms/<slug>.sfc                      (the ROM)
#   preview/<slug>.png                   (optional canvas preview, recompressed)
#   roms/manifest.json                   (adds/updates the <slug> entry)
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scaffold.sh --rom PATH.sfc --slug SLUG [options]

  --rom PATH        the .sfc ROM                                   (required)
  --slug SLUG       URL path + manifest id, e.g. "blossom"         (required)
  --site DIR        site repo root                                 (default: cwd)
  --playdir REL     play dir under the site root                   (default: public/play)
  --title TITLE     manifest title                                 (default: SLUG)
  --preview PNG     a 256x224 PNG shown on the canvas while loading (recompressed)
  --selfcheck "OFF LEN WANT FRAMES LABEL"
                    optional in-browser fidelity check (OFF/WANT hex). LABEL may have spaces.
  --touchnav "LX LY LW LH RX RY RW RH"
                    optional canvas tap rects (logical px) mapped to pad Left/Right
  -h, --help        this help

The engine comes from the site's installed @wbniv/bsnes-jg-player package
(node_modules), synced + drift-stamped by its own CLI. Install it first:
  pnpm add @wbniv/bsnes-jg-player     # or the git URL until the first npm publish
EOF
}

ROM= SLUG= SITE="$PWD" PLAYDIR="public/play" TITLE= PREVIEW= SELFCHECK= TOUCHNAV=
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --rom)       ROM="$2"; shift 2 ;;
    --slug)      SLUG="$2"; shift 2 ;;
    --site)      SITE="$2"; shift 2 ;;
    --playdir)   PLAYDIR="$2"; shift 2 ;;
    --title)     TITLE="$2"; shift 2 ;;
    --preview)   PREVIEW="$2"; shift 2 ;;
    --selfcheck) SELFCHECK="$2"; shift 2 ;;
    --touchnav)  TOUCHNAV="$2"; shift 2 ;;
    *) echo "scaffold.sh: unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

[ -n "$ROM" ]  && [ -n "$SLUG" ] || { echo "scaffold.sh: --rom and --slug are required" >&2; usage; exit 2; }
[ -f "$ROM" ] || { echo "scaffold.sh: ROM not found: $ROM" >&2; exit 2; }
[ -d "$SITE/src/pages" ] || { echo "scaffold.sh: $SITE is not an Astro site (no src/pages/)" >&2; exit 2; }
case "$SLUG" in *[!a-z0-9-]*) echo "scaffold.sh: slug must be [a-z0-9-]: $SLUG" >&2; exit 2 ;; esac
TITLE="${TITLE:-$SLUG}"

SYNC="$SITE/node_modules/@wbniv/bsnes-jg-player/bin/sync.mjs"
[ -f "$SYNC" ] || {
  echo "scaffold.sh: @wbniv/bsnes-jg-player is not installed in $SITE." >&2
  echo "  cd $SITE && pnpm add @wbniv/bsnes-jg-player" >&2
  exit 2
}

PLAY="$SITE/$PLAYDIR"
mkdir -p "$PLAY/roms" "$PLAY/preview"
echo "scaffold: $SLUG -> $PLAY"

# 1. engine — the package CLI copies app.js + cores/* and writes ENGINE_VERSION
node "$SYNC" sync "$PLAY"

# 2. ROM
cp "$ROM" "$PLAY/roms/$SLUG.sfc"
echo "  rom     $PLAYDIR/roms/$SLUG.sfc ($(stat -c%s "$PLAY/roms/$SLUG.sfc") bytes)"

# 3. preview (lossless recompress — bsnes PNG dumps are uncompressed ~172 KB)
if [ -n "$PREVIEW" ]; then
  [ -f "$PREVIEW" ] || { echo "scaffold.sh: preview not found: $PREVIEW" >&2; exit 2; }
  cp "$PREVIEW" "$PLAY/preview/$SLUG.png"
  python3 - "$PLAY/preview/$SLUG.png" <<'PY' 2>/dev/null || true
import sys
try:
    from PIL import Image
    p=sys.argv[1]; Image.open(p).convert("RGB").save(p,"PNG",optimize=True,compress_level=9)
except Exception: pass
PY
  echo "  preview $PLAYDIR/preview/$SLUG.png"
fi

# 4. manifest (create or update; replace any existing entry for this slug)
python3 - "$PLAY/roms/manifest.json" "$SLUG" "$TITLE" "$SELFCHECK" "$TOUCHNAV" <<'PY'
import json, os, sys
path, slug, title, sc, tn = sys.argv[1:6]
m = {"_comment":"Demo ROMs + their in-browser fidelity self-checks for the bsnes-jg WASM player. "
                "A selfcheck powers on, runs `frames` frames, reads `len` LE bytes of WRAM at `off`, "
                "and asserts == `want` — matching the headless gate proves this wasm build is the trusted core.",
     "roms":[]}
if os.path.exists(path):
    try: m = json.load(open(path))
    except Exception: pass
m.setdefault("roms", [])
entry = {"id": slug, "title": title}
if sc.strip():
    p = sc.split(None, 4)
    if len(p) >= 4:
        entry["selfcheck"] = {"off":p[0], "len":int(p[1]), "want":p[2], "frames":int(p[3]),
                              "label": p[4] if len(p) > 4 else ""}
if tn.strip():
    v = [int(x) for x in tn.split()]
    if len(v) == 8:
        entry["touchNav"] = {"left": v[:4], "right": v[4:]}
m["roms"] = [r for r in m["roms"] if r.get("id") != slug] + [entry]
json.dump(m, open(path,"w"), indent=2); open(path,"a").write("\n")
print("  manifest %s (%d rom(s))" % (path, len(m["roms"])))
PY

echo "OK. Next (per SKILL.md): biohack -> write src/content/snes/$SLUG.json; indri -> append the gallery registry entry."
