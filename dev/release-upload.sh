#!/usr/bin/env bash
# dev/release-upload.sh — publish a packaged toolchain archive to the indri.studio
# /sources mirror (the product page's non-apt direct-download links).
#
# Uploads the relocatable archive(s) produced by dev/package-release.sh from dist/
# to  R2:indri-apt/sources/  (Cloudflare R2 bucket `indri-apt`, the same place the
# x86-64 tarball lives; served as https://apt.indri.studio/sources/<name>). It does
# NOT touch the apt pool/ — that holds aptly-indexed .deb packages only and is the
# indri.studio/apt repo's job.
#
# The R2 remote is the `R2` rclone remote, configured via RCLONE_CONFIG_R2_* env
# (matching indri.studio/apt's .github/workflows/publish.yml):
#   RCLONE_CONFIG_R2_TYPE=s3  RCLONE_CONFIG_R2_PROVIDER=Cloudflare  RCLONE_CONFIG_R2_REGION=auto
#   RCLONE_CONFIG_R2_ACCESS_KEY_ID=…  RCLONE_CONFIG_R2_SECRET_ACCESS_KEY=…  RCLONE_CONFIG_R2_ENDPOINT=…
# (or a saved `R2:` remote in rclone.conf).
#
# Naming: dist/llvm-mos-65816-<date>-<sha>-<archtag>.<ext>
#      -> sources/llvm-mos-65816_0.0.0+git<date>.<sha>_<archtag>.<ext>   (+ .sha256)
# which matches the product-page download links (indri.studio app page).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: dev/release-upload.sh [PLATFORM ...]
  Upload dist/ toolchain archives to R2:indri-apt/sources/ (-> apt.indri.studio/sources/).

  PLATFORM   one or more arch tags as they appear in the dist filename:
             linux-aarch64 | windows-x86_64 | linux-x86_64
             (default: every *.tar.xz/*.zip in dist/ EXCEPT windows, which is gated)

  Env:
    DRY_RUN=1            show what would upload, transfer nothing (rclone --dry-run)
    WINDOWS_VERIFIED=1   allow uploading the windows-x86_64 .zip — REQUIRED, because
                         wine can't run it so its functional check is owed on real
                         Windows (release policy: always test on release). Without it
                         windows is skipped with a notice.
    DIST_DIR=<dir>       source dir (default dist)
    VERSION_BASE=0.0.0   semver base for the /sources name (default 0.0.0)
EOF
}
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
VERSION_BASE="${VERSION_BASE:-0.0.0}"
REMOTE="R2:indri-apt/sources"
BASE_URL="https://apt.indri.studio/sources"

# --- preflight --------------------------------------------------------------
command -v rclone >/dev/null || { echo "FATAL: rclone not installed" >&2; exit 1; }
if ! rclone listremotes 2>/dev/null | grep -qx 'R2:' && [ -z "${RCLONE_CONFIG_R2_TYPE:-}" ]; then
  echo "FATAL: no 'R2' rclone remote. Configure it (rclone.conf) or export the RCLONE_CONFIG_R2_* env" >&2
  echo "  vars (see indri.studio/apt/.github/workflows/publish.yml): TYPE=s3 PROVIDER=Cloudflare REGION=auto" >&2
  echo "  ACCESS_KEY_ID / SECRET_ACCESS_KEY / ENDPOINT." >&2
  exit 1
fi

# --- select artifacts -------------------------------------------------------
shopt -s nullglob
if [ "$#" -gt 0 ]; then
  files=()
  for tag in "$@"; do
    for f in "$DIST_DIR"/llvm-mos-65816-*-"$tag".tar.xz "$DIST_DIR"/llvm-mos-65816-*-"$tag".zip; do files+=("$f"); done
  done
else
  files=("$DIST_DIR"/llvm-mos-65816-*.tar.xz "$DIST_DIR"/llvm-mos-65816-*.zip)
fi
shopt -u nullglob
[ "${#files[@]}" -gt 0 ] || { echo "FATAL: no matching archives in $DIST_DIR (build with task package / package-all first)" >&2; exit 1; }

DRY=(); [[ "${DRY_RUN:-0}" == 1 ]] && DRY=(--dry-run)
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
uploaded=0

for src in "${files[@]}"; do
  base="$(basename "$src")"
  ext="tar.xz"; [[ "$base" == *.zip ]] && ext="zip"
  stem="${base%.$ext}"                         # llvm-mos-65816-<date>-<sha>-<archtag>
  rest="${stem#llvm-mos-65816-}"               # <date>-<sha>-<archtag>
  date="${rest%%-*}"; rest="${rest#*-}"        # <sha>-<archtag>
  sha="${rest%%-*}"; archtag="${rest#*-}"      # <sha> ; <archtag>
  case "$date" in [0-9]*) : ;; *) echo "  WARN: can't parse '$base' (unexpected name) — skipping" >&2; continue ;; esac

  # windows is gated until verified on real Windows (wine can't run it).
  if [[ "$archtag" == windows-* && "${WINDOWS_VERIFIED:-0}" != 1 ]]; then
    echo "  SKIP $base — windows functional check not confirmed (set WINDOWS_VERIFIED=1 to publish)" >&2
    continue
  fi

  version="${VERSION_BASE}+git${date}.${sha}"
  target="llvm-mos-65816_${version}_${archtag}.${ext}"

  # a .sha256 that names the TARGET file (regenerated; the dist one names the dist file)
  if [[ -f "$src.sha256" ]]; then digest="$(cut -d' ' -f1 "$src.sha256")"; else digest="$(sha256sum "$src" | cut -d' ' -f1)"; fi
  printf '%s  %s\n' "$digest" "$target" > "$TMP/$target.sha256"

  echo "==> $base"
  echo "    -> $REMOTE/$target"
  rclone copyto "${DRY[@]}" "$src" "$REMOTE/$target"
  rclone copyto "${DRY[@]}" "$TMP/$target.sha256" "$REMOTE/$target.sha256"
  echo "    url: $BASE_URL/$target"
  uploaded=$((uploaded+1))
done

echo
if [[ "${DRY_RUN:-0}" == 1 ]]; then
  echo "==> DRY_RUN: nothing transferred ($uploaded archive(s) would upload)."
else
  echo "==> uploaded $uploaded archive(s) to $BASE_URL/ . The product page links resolve once the page is redeployed."
fi
