#!/usr/bin/env bash
# Fail-closed SNES ROM publication: biohack.net and indri.studio are one release unit.
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BIOHACK=${BIOHACK_SITE:-/home/will/biohack.net}
INDRI=${INDRI_SITE:-/home/will/indri.studio}
SLUG=
ROM=
PREVIEW=
PUBLISH=0

usage() {
  cat <<'EOF'
Usage: dev/publish-snes-rom-both-sites.sh --slug SLUG --rom FILE [--preview PNG] [--publish]

Default mode is read-only: require matching, publish-ready artifacts on both sites.
--publish copies the supplied ROM (and optional preview), builds both sites, commits only the
slug-specific files, pushes both repositories, tags both releases, and verifies both live URLs.

Site roots may be overridden with BIOHACK_SITE and INDRI_SITE.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --slug) SLUG=$2; shift 2 ;;
    --rom) ROM=$2; shift 2 ;;
    --preview) PREVIEW=$2; shift 2 ;;
    --publish) PUBLISH=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "FATAL: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$SLUG" in
  ''|*[!a-z0-9-]*) echo "FATAL: --slug must contain only lowercase letters, digits, and hyphens" >&2; exit 2 ;;
esac
[ -n "$ROM" ] || { echo "FATAL: --rom is required" >&2; exit 2; }
[ -f "$ROM" ] || { echo "FATAL: ROM not found: $ROM" >&2; exit 1; }
[ "$(stat -c %s "$ROM")" -gt 0 ] || { echo "FATAL: ROM is empty: $ROM" >&2; exit 1; }
if [ -n "$PREVIEW" ]; then [ -f "$PREVIEW" ] || { echo "FATAL: preview not found: $PREVIEW" >&2; exit 1; }; fi

SOURCE_SHA=$(sha256sum "$ROM" | cut -d' ' -f1)
CONTRACT="$ROOT/dev/natural-rom-contracts/$SLUG.contract"
if [ -f "$CONTRACT" ]; then
  RECEIPT="$ROOT/build/$SLUG.natural-pass"
  [ -f "$RECEIPT" ] || {
    echo "FATAL: $SLUG is a natural-source demo but has no pass receipt: $RECEIPT" >&2
    exit 1
  }
  source_rel=$(awk -F= '$1 == "source" { print substr($0, index($0, "=") + 1); exit }' "$CONTRACT")
  evidence=$(awk -F= '$1 == "evidence" { print substr($0, index($0, "=") + 1); exit }' "$CONTRACT")
  [ -f "$ROOT/$source_rel" ] || { echo "FATAL: contracted source not found: $source_rel" >&2; exit 1; }
  receipt_value() { awk -F= -v key="$1" '$1 == key { print substr($0, index($0, "=") + 1); exit }' "$RECEIPT"; }
  [ "$(receipt_value slug)" = "$SLUG" ] &&
  [ "$(receipt_value status)" = NATURAL_PASS ] &&
  [ "$(receipt_value rom_sha256)" = "$SOURCE_SHA" ] &&
  [ "$(receipt_value source)" = "$source_rel" ] &&
  [ "$(receipt_value source_sha256)" = "$(sha256sum "$ROOT/$source_rel" | cut -d' ' -f1)" ] &&
  [ "$(receipt_value contract_sha256)" = "$(sha256sum "$CONTRACT" | cut -d' ' -f1)" ] &&
  [ "$(receipt_value evidence)" = "$evidence" ] || {
    echo "FATAL: stale or invalid natural-source pass receipt for $SLUG" >&2
    exit 1
  }
  echo "NATURAL CONTRACT: PASS — $evidence"
fi

BIO_ROM="$BIOHACK/public/play/roms/$SLUG.sfc"
BIO_PREVIEW="$BIOHACK/public/play/preview/$SLUG.png"
BIO_MANIFEST="$BIOHACK/public/play/roms/manifest.json"
BIO_META="$BIOHACK/src/content/snes/$SLUG.json"
INDRI_ROM="$INDRI/public/apps/llvm-mos-65816/play/roms/$SLUG.sfc"
INDRI_PREVIEW="$INDRI/public/apps/llvm-mos-65816/play/preview/$SLUG.png"
INDRI_MANIFEST="$INDRI/public/apps/llvm-mos-65816/play/roms/manifest.json"
INDRI_META="$INDRI/src/data/snes-demos.ts"

for repo in "$BIOHACK" "$INDRI"; do
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null
done
for file in "$BIO_MANIFEST" "$BIO_META" "$INDRI_MANIFEST" "$INDRI_META"; do
  [ -f "$file" ] || { echo "FATAL: missing publication metadata: $file" >&2; exit 1; }
done
jq -e --arg slug "$SLUG" '.roms[] | select(.id == $slug)' "$BIO_MANIFEST" >/dev/null || {
  echo "FATAL: biohack manifest has no $SLUG entry" >&2; exit 1;
}
jq -e --arg slug "$SLUG" '.roms[] | select(.id == $slug)' "$INDRI_MANIFEST" >/dev/null || {
  echo "FATAL: indri manifest has no $SLUG entry" >&2; exit 1;
}
grep -Fq "\"slug\": \"$SLUG\"" "$INDRI_META" || {
  echo "FATAL: indri page registry has no $SLUG entry" >&2; exit 1;
}

if [ "$PUBLISH" -eq 1 ]; then
  cp "$ROM" "$BIO_ROM"
  cp "$ROM" "$INDRI_ROM"
  if [ -n "$PREVIEW" ]; then
    cp "$PREVIEW" "$BIO_PREVIEW"
    cp "$PREVIEW" "$INDRI_PREVIEW"
  fi
fi

for file in "$BIO_ROM" "$BIO_PREVIEW" "$INDRI_ROM" "$INDRI_PREVIEW"; do
  [ -f "$file" ] || { echo "FATAL: missing paired publication artifact: $file" >&2; exit 1; }
done
for file in "$BIO_ROM" "$INDRI_ROM"; do
  have=$(sha256sum "$file" | cut -d' ' -f1)
  [ "$have" = "$SOURCE_SHA" ] || { echo "FATAL: $file SHA-256 $have != $SOURCE_SHA" >&2; exit 1; }
done

echo "PAIR: PASS — $SLUG exists on both sites at SHA-256 $SOURCE_SHA"
[ "$PUBLISH" -eq 1 ] || {
  echo "biohack page: https://biohack.net/snes/$SLUG/"
  echo "biohack ROM:  https://biohack.net/play/roms/$SLUG.sfc"
  echo "indri page:   https://indri.studio/apps/llvm-mos-65816/snes/$SLUG/"
  echo "indri ROM:    https://indri.studio/apps/llvm-mos-65816/play/roms/$SLUG.sfc"
  exit 0
}

pnpm --dir "$BIOHACK" build
pnpm --dir "$INDRI" build

git -C "$BIOHACK" add \
  "public/play/roms/$SLUG.sfc" "public/play/preview/$SLUG.png" \
  public/play/roms/manifest.json "src/content/snes/$SLUG.json"
git -C "$INDRI" add \
  "public/apps/llvm-mos-65816/play/roms/$SLUG.sfc" \
  "public/apps/llvm-mos-65816/play/preview/$SLUG.png" \
  public/apps/llvm-mos-65816/play/roms/manifest.json src/data/snes-demos.ts
git -C "$BIOHACK" diff --cached --check
git -C "$INDRI" diff --cached --check

git -C "$BIOHACK" diff --cached --quiet || \
  git -C "$BIOHACK" commit -m "feat(snes): publish $SLUG"
git -C "$INDRI" diff --cached --quiet || \
  git -C "$INDRI" commit -m "feat(snes): publish $SLUG"
git -C "$BIOHACK" push
git -C "$INDRI" push

(cd "$BIOHACK" && task bump)
(cd "$INDRI" && task publish)

LIVE_DIR=$(mktemp -d)
trap 'rm -rf "$LIVE_DIR"' EXIT
BIO_PAGE="https://biohack.net/snes/$SLUG/"
BIO_URL="https://biohack.net/play/roms/$SLUG.sfc"
INDRI_PAGE="https://indri.studio/apps/llvm-mos-65816/snes/$SLUG/"
INDRI_URL="https://indri.studio/apps/llvm-mos-65816/play/roms/$SLUG.sfc"
for attempt in $(seq 1 30); do
  if curl -fsSL "$BIO_PAGE" -o "$LIVE_DIR/bio.html" &&
     curl -fsSL "$INDRI_PAGE" -o "$LIVE_DIR/indri.html" &&
     curl -fsSL "$BIO_URL" -o "$LIVE_DIR/bio.sfc" &&
     curl -fsSL "$INDRI_URL" -o "$LIVE_DIR/indri.sfc" &&
     printf '%s  %s\n%s  %s\n' "$SOURCE_SHA" "$LIVE_DIR/bio.sfc" \
       "$SOURCE_SHA" "$LIVE_DIR/indri.sfc" | sha256sum -c -; then
    echo "PUBLISH: PASS — both live pages and ROMs verified"
    echo "biohack page: $BIO_PAGE"
    echo "biohack ROM:  $BIO_URL"
    echo "indri page:   $INDRI_PAGE"
    echo "indri ROM:    $INDRI_URL"
    exit 0
  fi
  [ "$attempt" -eq 30 ] || sleep 10
done
echo "FATAL: paired live verification did not converge" >&2
exit 1
