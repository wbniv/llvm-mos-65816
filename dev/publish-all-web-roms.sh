#!/usr/bin/env bash
# Rebuild the paired web-ROM set, verify both site manifests, and deploy both sites.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/dev/task-progress.sh"
publish_started=$SECONDS
phase() { printf '\nPUBLISH phase %s/8: %s | elapsed %ss\n' "$1" "$2" "$((SECONDS-publish_started))" >&2; }
BIOHACK="${BIOHACK_SITE:-$HOME/biohack.net}"
INDRI="${INDRI_SITE:-$HOME/indri.studio}"
RESUME=0

usage() {
  cat <<'EOF'
Usage: task publish-all-web-roms [-- --resume --biohack-site DIR --indri-site DIR]

Rebuild every ROM listed by both paired site manifests, verify the new ROMs against both
manifests in bsnes-jg, build both sites, commit the ROMs/manifests, trigger both deployments,
and verify every live ROM SHA-256. Both site checkouts must be clean and on their release branches.

BIOHACK_SITE and INDRI_SITE may also select the two site checkouts.
--resume reuses the completed batch build, permits only ROM/manifest changes in
the site checkouts, and reruns both manifest verification gates before publishing.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --resume) RESUME=1; shift ;;
    --biohack-site) BIOHACK="${2:?--biohack-site needs a directory}"; shift 2 ;;
    --indri-site) INDRI="${2:?--indri-site needs a directory}"; shift 2 ;;
    *) echo "FATAL: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

phase 1 'prepare inventory'
BIO_MANIFEST="$BIOHACK/public/play/roms/manifest.json"
BIO_ROMS="$BIOHACK/public/play/roms"
INDRI_MANIFEST="$INDRI/public/apps/llvm-mos-65816/play/roms/manifest.json"
INDRI_ROMS="$INDRI/public/apps/llvm-mos-65816/play/roms"

for path in "$BIO_MANIFEST" "$INDRI_MANIFEST" "$BIO_ROMS" "$INDRI_ROMS"; do
  [ -e "$path" ] || { echo "FATAL: required paired-site path is missing: $path" >&2; exit 1; }
done

check_repo() {
  local repo="$1" branch="$2" remote="$3"
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null
  [ "$(git -C "$repo" branch --show-current)" = "$branch" ] || {
    echo "FATAL: $repo must be on $branch" >&2; return 1;
  }
  [ "$(git -C "$repo" remote get-url origin)" = "$remote" ] || {
    echo "FATAL: $repo origin is not the expected $remote" >&2; return 1;
  }
  if [ "$RESUME" = 1 ]; then
    python3 - "$repo" "$4" <<'PY'
import json, pathlib, subprocess, sys
repo, manifest = sys.argv[1:]
data = json.loads((pathlib.Path(repo) / manifest).read_text())
romdir = str(pathlib.PurePosixPath(manifest).parent)
allowed = {manifest} | {f"{romdir}/{r['id']}.sfc" for r in data['roms']}
status = subprocess.check_output(['git', '-C', repo, 'status', '--porcelain=v1', '-z'])
for entry in status.split(b'\0'):
    if not entry:
        continue
    state, path = entry[:2], entry[3:].decode()
    if state not in (b' M', b'M ', b'MM') or path not in allowed:
        raise SystemExit(f'FATAL: --resume refuses unrelated or non-modification change in {repo}: {entry!r}')
PY
  else
    [ -z "$(git -C "$repo" status --porcelain)" ] || {
    echo "FATAL: $repo has local changes; commit or stash them before bulk publication" >&2
    return 1
  }
  fi
}
check_repo "$BIOHACK" master git@github.com:wbniv/biohack.net.git public/play/roms/manifest.json
check_repo "$INDRI" main git@github.com:wbniv/indri.studio.git public/apps/llvm-mos-65816/play/roms/manifest.json

# Both sites must publish the same inventory. Existing ROMs may differ because
# each site can have an older release; both receive the same verified rebuild.
mapfile -t BIO_IDS < <(python3 - "$BIO_MANIFEST" <<'PY'
import json, sys
print("\n".join(sorted(r["id"] for r in json.load(open(sys.argv[1]))["roms"])))
PY
)
mapfile -t INDRI_IDS < <(python3 - "$INDRI_MANIFEST" <<'PY'
import json, sys
print("\n".join(sorted(r["id"] for r in json.load(open(sys.argv[1]))["roms"])))
PY
)
[ "${#BIO_IDS[@]}" -gt 0 ] && [ "${BIO_IDS[*]}" = "${INDRI_IDS[*]}" ] || {
  echo "FATAL: paired manifests do not list the same ROM IDs" >&2; exit 1;
}
SLUGS=("${BIO_IDS[@]}")
for slug in "${SLUGS[@]}"; do
  [ -f "$BIO_ROMS/$slug.sfc" ] && [ -f "$INDRI_ROMS/$slug.sfc" ] || {
    echo "FATAL: paired ROM is missing before rebuild: $slug" >&2; exit 1;
  }
  cmp -s "$BIO_ROMS/$slug.sfc" "$INDRI_ROMS/$slug.sfc" || {
    echo "==> paired ROMs differ before rebuild: $slug (will replace both after verification)"
  }
done

mkdir -p "$ROOT/build"
LIST="$ROOT/build/all-web-roms.list"
printf '%s\n' "${SLUGS[@]}" > "$LIST"
phase 2 'rebuild or resume ROMs'
if [ "$RESUME" = 0 ]; then
echo "==> rebuilding ${#SLUGS[@]} paired ROMs"
"$ROOT/dev/run.sh" rebuild-web-roms "@/work/build/all-web-roms.list" \
  2>&1 | tee "$ROOT/build/publish-all-web-roms.log" | {
    rebuild_count=0
    while IFS= read -r line; do
      case "$line" in
        'OK    '*|'FAIL  '*|'SKIP  '*)
          rebuild_count=$((rebuild_count+1))
          task_progress "${#SLUGS[@]}" "$rebuild_count" REBUILD "$line" ;;
      esac
    done
  } || {
    tail -80 "$ROOT/build/publish-all-web-roms.log" >&2
    echo "FATAL: batch rebuild failed; neither site was changed" >&2
    exit 1
  }
else
  echo "==> resuming ${#SLUGS[@]} paired ROMs from the completed batch build"
  for slug in "${SLUGS[@]}"; do
    if ! cmp -s "$ROOT/build/$slug.sfc" "$BIO_ROMS/$slug.sfc" || \
      ! cmp -s "$ROOT/build/$slug.sfc" "$INDRI_ROMS/$slug.sfc"; then
      echo "FATAL: --resume requires both site ROMs to match build/$slug.sfc" >&2
      exit 1
    fi
  done
fi
for slug in "${SLUGS[@]}"; do
  grep -Fq "OK    $slug  " "$ROOT/build/publish-all-web-roms.log" && \
    [ -s "$ROOT/build/$slug.sfc" ] && [ -s "$ROOT/build/$slug.map" ] || {
    echo "FATAL: rebuild did not produce ROM and map for $slug; neither site was changed" >&2
    exit 1
  }
done
tail -5 "$ROOT/build/publish-all-web-roms.log"

# Prepare and verify both candidates before changing either site checkout. The site manifests
# contain different per-demo contracts, so derive each independently from the same ROM set.
candidate="$(mktemp -d "$ROOT/build/publish-all-web-roms.XXXXXX")"
trap 'rm -rf "$candidate"' EXIT
mkdir -p "$candidate/biohack-roms" "$candidate/indri-roms"
cp "$BIO_MANIFEST" "$candidate/biohack-manifest.json"
cp "$INDRI_MANIFEST" "$candidate/indri-manifest.json"
for slug in "${SLUGS[@]}"; do
  ln -s "$ROOT/build/$slug.sfc" "$candidate/biohack-roms/$slug.sfc"
  ln -s "$ROOT/build/$slug.sfc" "$candidate/indri-roms/$slug.sfc"
done

# Recompute each site's own WRAM offsets from its candidate ROM and map. The current Indri gallery
# manifest predates the explicit symbol field, so name its live-record symbol here.
python3 "$ROOT/dev/sync-manifest-offsets.py" \
  --manifest "$candidate/biohack-manifest.json" --rom-dir "$candidate/biohack-roms" \
  --symbol apollo-daylight=apollo_reel_health \
  --symbol svx2-fastrom-video=video_reel_composite_health
python3 "$ROOT/dev/sync-manifest-offsets.py" \
  --manifest "$candidate/indri-manifest.json" --rom-dir "$candidate/indri-roms" \
  --symbol apollo-daylight=apollo_reel_health \
  --symbol svx2-fastrom-video=video_reel_composite_health

echo "==> verifying biohack.net (site 1/2)"
phase 3 'verify biohack.net'
"$ROOT/dev/verify-web-roms.sh" --manifest "$candidate/biohack-manifest.json" \
  --rom-dir "$candidate/biohack-roms" --cache-dir "$ROOT/build/verify-web-roms-cache"
# Both candidate directories point at the same rebuilt ROMs. Replay an Indri check only
# when its self-check contract differs from the one already verified for biohack.net.
mapfile -t indri_only_ids < <(python3 - "$candidate/biohack-manifest.json" "$candidate/indri-manifest.json" <<'PY_IDS'
import json, sys
with open(sys.argv[1]) as f:
    bio = {r["id"]: r.get("selfcheck") for r in json.load(f)["roms"]}
with open(sys.argv[2]) as f:
    indri = json.load(f)["roms"]
for rom in indri:
    check = rom.get("selfcheck")
    if check and check != bio.get(rom["id"]):
        print(rom["id"])
PY_IDS
)
echo "==> verifying indri.studio (site 2/2): ${#indri_only_ids[@]} distinct check(s)"
phase 4 'verify indri.studio'
if [ "${#indri_only_ids[@]}" -gt 0 ]; then
  indri_only=$(IFS=,; echo "${indri_only_ids[*]}")
  "$ROOT/dev/verify-web-roms.sh" --manifest "$candidate/indri-manifest.json" \
    --rom-dir "$candidate/indri-roms" --only "$indri_only" \
    --cache-dir "$ROOT/build/verify-web-roms-cache"
fi

# Only verified candidates enter the site checkouts.
for slug in "${SLUGS[@]}"; do
  cp "$ROOT/build/$slug.sfc" "$BIO_ROMS/$slug.sfc"
  cp "$ROOT/build/$slug.sfc" "$INDRI_ROMS/$slug.sfc"
done
cp "$candidate/biohack-manifest.json" "$BIO_MANIFEST"
cp "$candidate/indri-manifest.json" "$INDRI_MANIFEST"

phase 5 'build both sites'
build_site() {
  local index="$1" name="$2" site="$3" log="$4"
  echo "==> building $name (log: $log)"
  if task_run 2 "$index" BUILD "site $((index+1))/2: $name" \
      pnpm --dir "$site" build >"$log" 2>&1; then
    echo "BUILD $name || PASS"
  else
    local status=$?
    echo "BUILD $name || FAIL (exit $status; log: $log)" >&2
    tail -80 "$log" >&2
    return "$status"
  fi
}
build_site 0 biohack.net "$BIOHACK" "$ROOT/build/publish-biohack-build.log"
build_site 1 indri.studio "$INDRI" "$ROOT/build/publish-indri-build.log"

# Stage only the release payload, then prepare both commits before either deployment is triggered.
phase 6 'prepare release commits'
BIO_PATHS=(public/play/roms/manifest.json)
INDRI_PATHS=(public/apps/llvm-mos-65816/play/roms/manifest.json)
for slug in "${SLUGS[@]}"; do
  BIO_PATHS+=("public/play/roms/$slug.sfc")
  INDRI_PATHS+=("public/apps/llvm-mos-65816/play/roms/$slug.sfc")
done
git -C "$BIOHACK" add -- "${BIO_PATHS[@]}"
git -C "$INDRI" add -- "${INDRI_PATHS[@]}"
git -C "$BIOHACK" diff --cached --check
git -C "$INDRI" diff --cached --check

if git -C "$BIOHACK" diff --cached --quiet && git -C "$INDRI" diff --cached --quiet; then
  echo "==> all paired ROMs are already current; no deployment needed"
  exit 0
fi
if git -C "$BIOHACK" diff --cached --quiet || git -C "$INDRI" diff --cached --quiet; then
  echo "FATAL: only one site has staged release changes; refusing a partial paired release" >&2
  exit 1
fi

stamp="$(date -u +%Y-%m-%d)"
git -C "$BIOHACK" commit -m "snes: rebuild all published ROMs ($stamp)"
git -C "$INDRI" commit -m "snes: rebuild all published ROMs ($stamp)"

# These established tasks tag and push their site's release branch to trigger its live deployment.
bio_rc=0; indri_rc=0
phase 7 'trigger deployments'
(cd "$BIOHACK" && task_run 2 0 DEPLOY biohack.net task bump) || bio_rc=$?
(cd "$INDRI" && task_run 2 1 DEPLOY indri.studio task publish) || indri_rc=$?
if [ "$bio_rc" -ne 0 ] || [ "$indri_rc" -ne 0 ]; then
  echo "FATAL: paired deployment task status: biohack=$bio_rc indri=$indri_rc" >&2
  exit 1
fi

live_tmp="$(mktemp -d)"
phase 8 'verify live ROM hashes'
live_done=0
live_started=$SECONDS
trap 'rm -rf "$candidate" "$live_tmp"' EXIT
for slug in "${SLUGS[@]}"; do
  expected="$(sha256sum "$ROOT/build/$slug.sfc" | awk '{print $1}')"
  verified=0
  for attempt in $(seq 1 30); do
    task_progress "${#SLUGS[@]}" "$live_done" LIVE \
      "$slug | biohack.net | attempt $attempt/30 | elapsed $((SECONDS-live_started))s"
    bio_match=0; indri_match=0
    if task_run 1 0 FETCH "$slug | biohack.net | attempt $attempt/30" \
       curl -fsSL "https://biohack.net/play/roms/$slug.sfc" -o "$live_tmp/bio-$slug.sfc" && \
       [ "$(sha256sum "$live_tmp/bio-$slug.sfc" | awk '{print $1}')" = "$expected" ]; then bio_match=1; fi
    task_progress "${#SLUGS[@]}" "$live_done" LIVE \
      "$slug | indri.studio | attempt $attempt/30 | elapsed $((SECONDS-live_started))s"
    if task_run 1 0 FETCH "$slug | indri.studio | attempt $attempt/30" \
       curl -fsSL "https://indri.studio/apps/llvm-mos-65816/play/roms/$slug.sfc" -o "$live_tmp/indri.sfc" && \
       [ "$(sha256sum "$live_tmp/indri.sfc" | awk '{print $1}')" = "$expected" ]; then indri_match=1; fi
    if [ "$bio_match" = 1 ] && [ "$indri_match" = 1 ]; then
      verified=1
      break
    fi
    if [ "$attempt" -lt 30 ]; then
      task_progress "${#SLUGS[@]}" "$live_done" LIVE "$slug | hash pending; next attempt in 10s"
      sleep 10
    fi
  done
  [ "$verified" -eq 1 ] || { echo "FATAL: live ROM hash did not converge for $slug" >&2; exit 1; }
  echo "  $slug: both live ROM hashes PASS"
  live_done=$((live_done+1))
done
task_progress "${#SLUGS[@]}" "$live_done" LIVE "both sites verified | elapsed $((SECONDS-live_started))s"
echo "PUBLISH: PASS — ${#SLUGS[@]} ROMs deployed and SHA-256 verified on both sites"
