#!/usr/bin/env bash
# scaffold.sh — set up the shared bsnes-jg WASM player + one ROM on an Astro static
# site, so a /<slug> page can boot it. Site-agnostic mechanical bits only; the page
# (src/pages/<slug>.astro) is written by the skill/agent from page-template.astro.
#
# Writes under <site>/public/play/ :
#   app.js  cores/bsnes_jg.{js,wasm}  cores/PROVENANCE.json   (the engine, copied once)
#   roms/<slug>.sfc                                            (the ROM)
#   preview/<slug>.png                                         (optional canvas preview)
#   roms/manifest.json                                         (adds/updates the <slug> entry)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"   # so the bundled engine resolves wherever the skill lives

usage() {
  cat <<'EOF'
Usage: scaffold.sh --rom PATH.sfc --slug SLUG [options]

  --rom PATH        the .sfc ROM                                   (required)
  --slug SLUG       URL path + manifest id, e.g. "blossom"         (required)
  --site DIR        site repo root                                 (default: cwd)
  --title TITLE     manifest title                                 (default: SLUG)
  --preview PNG     a 256x224 PNG shown on the canvas while loading (recompressed)
  --player-src DIR  bsnes-jg engine dir to copy app.js + cores/ from
                    (default: the engine/ bundled in this skill — self-contained)
  --selfcheck "OFF LEN WANT FRAMES LABEL"
                    optional in-browser fidelity check (OFF/WANT hex). LABEL may have spaces.
  -h, --help        this help

Prints the public paths it wrote; then write src/pages/SLUG.astro per SKILL.md.
EOF
}

ROM= SLUG= SITE="$PWD" TITLE= PREVIEW= SELFCHECK=
PLAYER_SRC="$SCRIPT_DIR/engine"   # bundled, self-contained; override to re-sync from a newer build
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --rom)        ROM="$2"; shift 2 ;;
    --slug)       SLUG="$2"; shift 2 ;;
    --site)       SITE="$2"; shift 2 ;;
    --title)      TITLE="$2"; shift 2 ;;
    --preview)    PREVIEW="$2"; shift 2 ;;
    --player-src) PLAYER_SRC="$2"; shift 2 ;;
    --selfcheck)  SELFCHECK="$2"; shift 2 ;;
    *) echo "scaffold.sh: unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

[ -n "$ROM" ]  && [ -n "$SLUG" ] || { echo "scaffold.sh: --rom and --slug are required" >&2; usage; exit 2; }
[ -f "$ROM" ] || { echo "scaffold.sh: ROM not found: $ROM" >&2; exit 2; }
[ -d "$SITE/src/pages" ] || { echo "scaffold.sh: $SITE is not an Astro site (no src/pages/)" >&2; exit 2; }
case "$SLUG" in *[!a-z0-9-]*) echo "scaffold.sh: slug must be [a-z0-9-]: $SLUG" >&2; exit 2 ;; esac
TITLE="${TITLE:-$SLUG}"

PLAY="$SITE/public/play"
mkdir -p "$PLAY/cores" "$PLAY/roms" "$PLAY/preview"

echo "scaffold: $SLUG -> $PLAY"

# 1. engine — copy each asset once (idempotent; a re-sync of the source updates them via the page's
#    content-hash cache-bust, so over-write to keep the core current).
for f in app.js cores/bsnes_jg.js cores/bsnes_jg.wasm cores/PROVENANCE.json; do
  if [ -f "$PLAYER_SRC/$f" ]; then
    cp "$PLAYER_SRC/$f" "$PLAY/$f"; echo "  engine  play/$f"
  elif [ ! -f "$PLAY/$f" ]; then
    echo "scaffold.sh: engine asset missing: $PLAYER_SRC/$f (set --player-src)" >&2; exit 2
  fi
done

# 2. ROM
cp "$ROM" "$PLAY/roms/$SLUG.sfc"
echo "  rom     play/roms/$SLUG.sfc ($(stat -c%s "$PLAY/roms/$SLUG.sfc") bytes)"

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
  echo "  preview play/preview/$SLUG.png"
fi

# 4. manifest (create or update; replace any existing entry for this slug)
python3 - "$PLAY/roms/manifest.json" "$SLUG" "$TITLE" "$SELFCHECK" <<'PY'
import json, os, sys
path, slug, title, sc = sys.argv[1:5]
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
m["roms"] = [r for r in m["roms"] if r.get("id") != slug] + [entry]
json.dump(m, open(path,"w"), indent=2); open(path,"a").write("\n")
print("  manifest play/roms/manifest.json (%d rom(s))" % len(m["roms"]))
PY

echo "OK. Next: write $SITE/src/pages/$SLUG.astro from page-template.astro (set SLUG/TITLE/keys/instructions; brand to the site)."
