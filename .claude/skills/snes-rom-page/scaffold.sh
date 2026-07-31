#!/usr/bin/env bash
# scaffold.sh — set up the shared bsnes-jg WASM player + one ROM on an Astro static
# site, so a /<slug> page can boot it. Site-agnostic mechanical bits only; the page
# (src/pages/<slug>.astro) is written by the skill/agent from page-template.astro.
#
# Writes under <site>/public/play/ :
#   app.js  cores/bsnes_jg.{js,wasm}  cores/PROVENANCE.json   (the engine, gated — see below)
#   roms/<slug>.sfc                                            (the ROM)
#   preview/<slug>.png                                         (optional canvas preview)
#   roms/manifest.json                                         (adds/updates the <slug> entry)
#
# Engine ownership: the bsnes-jg engine is normally synced by the @wbniv/bsnes-jg-player
# package's own CLI, not this scaffold. The engine/ bundled in this skill is a
# self-contained fallback copy. Before overwriting a site's engine, this script compares
# the two PROVENANCE.json "built" stamps and REFUSES to copy — by default — whenever the
# site's engine is already newer, or the comparison can't be made at all (either
# PROVENANCE.json is missing/unreadable). This is the fix for the 2026-07-31 incident
# where an unconditional copy from a stale bundled engine/ silently downgraded a site's
# live player. Pass --force-engine for a deliberate downgrade.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"   # so the bundled engine resolves wherever the skill lives

usage() {
  cat <<'EOF'
Usage: scaffold.sh --rom PATH.sfc --slug SLUG [options]
       scaffold.sh --selftest

  --rom PATH        the .sfc ROM                                   (required)
  --slug SLUG       URL path + manifest id, e.g. "blossom"         (required)
  --site DIR        site repo root                                 (default: cwd)
  --title TITLE     manifest title                                 (default: SLUG)
  --preview PNG     a 256x224 PNG shown on the canvas while loading (recompressed)
  --player-src DIR  bsnes-jg engine dir to copy app.js + cores/ from
                    (default: the engine/ bundled in this skill — self-contained)
  --force-engine    copy the engine even though the provenance gate would refuse (site
                    engine looks newer, or a PROVENANCE.json couldn't be read). Use only
                    for a deliberate downgrade — see "Engine ownership" above.
  --selfcheck "OFF LEN WANT FRAMES LABEL"
                    optional in-browser fidelity check (OFF/WANT hex). LABEL may have spaces.
  --selftest        run the engine-provenance-gate self-test (3 cases, synthetic
                    PROVENANCE files in a tmpdir; touches no site) and exit
  -h, --help        this help

Prints the public paths it wrote; then write src/pages/SLUG.astro per SKILL.md.
EOF
}

# engine_built PROVENANCE_JSON_PATH — helper used only by callers that want the raw
# stamp for a log line; the gate itself (below) does its own read+compare in Python so
# the two never disagree about what counts as "unreadable".
engine_built() {
  [ -f "$1" ] || return 0
  python3 -c 'import json,sys
try:
    print(json.load(open(sys.argv[1])).get("built",""))
except Exception:
    pass' "$1" 2>/dev/null || true
}

# engine_gate BUNDLE_PROVENANCE SITE_PROVENANCE
# Prints exactly "COPY" or "REFUSE" on stdout — nothing else, so callers can capture it
# with $(...). On REFUSE, prints a message naming both stamps + the ownership statement
# + next steps to stderr. Pure read — never touches the filesystem beyond opening the two
# given paths, so it's safe to call against a real site for a dry read of the decision.
engine_gate() {
  python3 - "$1" "$2" <<'PY'
import json, os, sys
from datetime import datetime

bundle_path, site_path = sys.argv[1], sys.argv[2]
OWNER = "  Engine sync is owned by the @wbniv/bsnes-jg-player CLI, not this scaffold."

def read_built(path):
    if not os.path.exists(path):
        return None, "<missing>"
    try:
        v = json.load(open(path)).get("built", "")
    except Exception:
        return None, "<unreadable/no 'built' field>"
    if not v:
        return None, "<unreadable/no 'built' field>"
    try:
        return datetime.fromisoformat(v.replace("Z", "+00:00")), v
    except Exception:
        return None, "<unparseable: %r>" % (v,)

bundle_dt, bundle_disp = read_built(bundle_path)
site_dt, site_disp = read_built(site_path)

def refuse(reason, *guidance):
    print("scaffold.sh: REFUSING engine copy — %s" % reason, file=sys.stderr)
    print("  bundled: %s -> built=%s" % (bundle_path, bundle_disp), file=sys.stderr)
    print("  site:    %s -> built=%s" % (site_path, site_disp), file=sys.stderr)
    print(OWNER, file=sys.stderr)
    for line in guidance:
        print("  " + line, file=sys.stderr)
    print("REFUSE")

if bundle_dt is None:
    refuse("the skill's bundled PROVENANCE is missing or unreadable",
           "The skill's engine/ bundle looks broken — fix/regenerate it, or pass",
           "--force-engine to copy the (unverified) bundle anyway.")
elif os.path.exists(site_path) and site_dt is None:
    refuse("the site's PROVENANCE exists but is unreadable",
           "With the site's stamp unreadable there's no safe way to tell whether copying",
           "would downgrade it. Investigate the site's cores/PROVENANCE.json, or pass",
           "--force-engine to copy anyway.")
elif site_dt is not None and site_dt > bundle_dt:
    refuse("the site's engine is NEWER than this skill's bundle",
           "Copying now would ship a downgrade. Sync the site's engine via the",
           "@wbniv/bsnes-jg-player CLI instead, or pass --force-engine for a deliberate",
           "downgrade.")
else:
    print("COPY")
PY
}

run_selftest() {
  local tmp status=0 out
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  mkprov() { mkdir -p "$(dirname "$1")"; printf '{"built": "%s"}\n' "$2" >"$1"; }

  echo "=== scaffold.sh --selftest: engine provenance gate ==="

  echo "--- case 1: site newer than bundle (expect REFUSE) ---"
  mkprov "$tmp/c1-bundle.json" "2026-06-25T14:34:26Z"
  mkprov "$tmp/c1-site.json"   "2026-07-27T20:31:40Z"
  out="$(engine_gate "$tmp/c1-bundle.json" "$tmp/c1-site.json")"
  if [ "$out" = REFUSE ]; then echo "PASS ($out)"; else echo "FAIL: got '$out', want REFUSE"; status=1; fi

  echo "--- case 2: bundle newer than site (expect COPY) ---"
  mkprov "$tmp/c2-bundle.json" "2026-07-30T00:00:00Z"
  mkprov "$tmp/c2-site.json"   "2026-06-25T14:34:26Z"
  out="$(engine_gate "$tmp/c2-bundle.json" "$tmp/c2-site.json")"
  if [ "$out" = COPY ]; then echo "PASS ($out)"; else echo "FAIL: got '$out', want COPY"; status=1; fi

  echo "--- case 3: bundled PROVENANCE missing (expect REFUSE with guidance) ---"
  mkprov "$tmp/c3-site.json" "2026-07-27T20:31:40Z"
  out="$(engine_gate "$tmp/c3-bundle-does-not-exist.json" "$tmp/c3-site.json")"
  if [ "$out" = REFUSE ]; then echo "PASS ($out)"; else echo "FAIL: got '$out', want REFUSE"; status=1; fi

  echo "--- bonus case: no site engine yet, first publish (expect COPY, not a downgrade) ---"
  mkprov "$tmp/c4-bundle.json" "2026-06-25T14:34:26Z"
  out="$(engine_gate "$tmp/c4-bundle.json" "$tmp/c4-site-does-not-exist.json")"
  if [ "$out" = COPY ]; then echo "PASS ($out)"; else echo "FAIL: got '$out', want COPY"; status=1; fi

  if [ $status -eq 0 ]; then echo "=== selftest: ALL PASS ==="; else echo "=== selftest: FAILURES ==="; fi
  return $status
}

ROM= SLUG= SITE="$PWD" TITLE= PREVIEW= SELFCHECK= FORCE_ENGINE=0
PLAYER_SRC="$SCRIPT_DIR/engine"   # bundled, self-contained; override to re-sync from a newer build

# --selftest and -h/--help must both work before any required-arg validation.
for a in "$@"; do
  case "$a" in
    -h|--help) usage; exit 0 ;;
    --selftest) run_selftest; exit $? ;;
  esac
done

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)    usage; exit 0 ;;
    --rom)        ROM="$2"; shift 2 ;;
    --slug)       SLUG="$2"; shift 2 ;;
    --site)       SITE="$2"; shift 2 ;;
    --title)      TITLE="$2"; shift 2 ;;
    --preview)    PREVIEW="$2"; shift 2 ;;
    --player-src) PLAYER_SRC="$2"; shift 2 ;;
    --force-engine) FORCE_ENGINE=1; shift ;;
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

# 1. engine — gate on PROVENANCE "built" stamps before copying (see file header). This
#    runs before any ROM/preview/manifest write, so a REFUSE leaves the site untouched.
BUNDLE_PROV="$PLAYER_SRC/cores/PROVENANCE.json"
SITE_PROV="$PLAY/cores/PROVENANCE.json"
GATE="$(engine_gate "$BUNDLE_PROV" "$SITE_PROV")"
if [ "$GATE" = REFUSE ]; then
  if [ "$FORCE_ENGINE" = 1 ]; then
    echo "  engine  --force-engine given: copying anyway despite the refusal above" >&2
  else
    exit 2
  fi
fi

for f in app.js cores/bsnes_jg.js cores/bsnes_jg.wasm cores/PROVENANCE.json; do
  if [ -f "$PLAYER_SRC/$f" ]; then
    cp "$PLAYER_SRC/$f" "$PLAY/$f"; echo "  engine  play/$f"
  elif [ ! -f "$PLAY/$f" ]; then
    echo "scaffold.sh: engine asset missing: $PLAYER_SRC/$f (set --player-src)" >&2; exit 2
  fi
done

# 1b. engine sanity — the Fullscreen handler has been silently deleted TWICE by unrelated ROM-rebuild
#     commits, each time leaving a button that only changes colour on hover. The page markup always
#     emits #fullscreen, so a copy without the handler is a broken publish, not a variant. Assert on
#     the INSTALLED file (what actually ships), not the source.
for probe in requestFullscreen fullscreenchange; do
  grep -q "$probe" "$PLAY/app.js" || {
    echo "scaffold.sh: FATAL: play/app.js has no '$probe' — the Fullscreen handler is missing." >&2
    echo "  Restore it in $PLAYER_SRC/app.js (see the DO-NOT-DELETE block near the #verify" >&2
    echo "  listener); publishing now would ship ~111 pages with a dead Fullscreen button." >&2
    exit 2
  }
done
echo "  engine  play/app.js: Fullscreen handler present"

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
