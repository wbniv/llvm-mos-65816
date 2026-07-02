#!/usr/bin/env bash
# dev/publish-web-roms.sh — HOST-side orchestrator for a bulk rebuild + sync of the web demo ROMs.
#
# After a shared change that affects every demo (e.g. the title-card font swap), this rebuilds every
# ROM currently published on the site and copies the fresh .sfc files into the site's play/roms dir.
# It does NOT deploy — review the git diff in the site repo, then deploy per the site (task release).
#
#   dev/publish-web-roms.sh [--site DIR]        # default site: ~/SRC/biohack.net
#
# Steps: (1) list slugs from <site>/public/play/roms/*.sfc → build/web-roms.list
#        (2) dev/run.sh rebuild-web-roms @… (one container, no gate)
#        (3) cp build/<slug>.sfc → <site>/public/play/roms/<slug>.sfc
# Preview PNGs + manifest self-check hashes are title-neutral, so they are left untouched.
# Verify one representative demo separately with the full gate: dev/run.sh <demo>.
set -euo pipefail

SITE="${HOME}/SRC/biohack.net"
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) echo "Usage: dev/publish-web-roms.sh [--site DIR]"; exit 0;;
    --site)    SITE="$2"; shift 2;;
    *)         echo "unknown arg: $1" >&2; exit 2;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
ROMS="$SITE/public/play/roms"
[ -d "$ROMS" ] || { echo "FATAL: no roms dir at $ROMS (wrong --site?)" >&2; exit 1; }

mkdir -p "$ROOT/build"
LIST="$ROOT/build/web-roms.list"
# shellcheck disable=SC2010
ls "$ROMS"/*.sfc | xargs -n1 basename | sed 's/\.sfc$//' | sort > "$LIST"
n=$(wc -l < "$LIST")
echo "==> $(date -u +%Y-%m-%dT%H:%M:%SZ) rebuilding $n web ROMs from $ROMS"

# Build all ROMs in one container (no gate). List file is under build/ → visible at /work/build in-container.
"$HERE/run.sh" rebuild-web-roms "@/work/build/web-roms.list"

echo "==> syncing fresh ROMs into the site"
copied=0; missing=""
while IFS= read -r slug; do
  if [ -f "$ROOT/build/$slug.sfc" ]; then
    cp "$ROOT/build/$slug.sfc" "$ROMS/$slug.sfc"; copied=$((copied+1))
  else
    missing="$missing $slug"
  fi
done < "$LIST"

echo "==> copied $copied/$n ROMs into $ROMS"
[ -n "$missing" ] && echo "==> MISSING (not built):$missing"
echo "==> next: review 'git -C $SITE status public/play/roms', verify one demo (dev/run.sh <demo>),"
echo "         commit the ROMs, then deploy per the site (cd $SITE && task release)."
