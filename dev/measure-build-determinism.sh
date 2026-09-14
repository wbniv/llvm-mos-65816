#!/usr/bin/env bash
# Phase 0 reproducer for docs/plans/2026-09-14-eliminate-build-nondeterminism.md.
#
# Rebuilds the same demo N times from identical source with the SAME installed toolchain,
# hashes every output ROM, and counts distinct hashes — once per "arm", where an arm is a
# system-load condition. The plan's leading hypothesis is that the single observed
# divergence was load-dependent, so a quiet run alone cannot settle it; this script runs a
# quiet baseline and one or more loaded arms at the same N so the two are comparable.
#
# Arms:
#   quiet    nothing else started by this script
#   docker   concurrent Docker containers (CPU spin + disk IO + /dev/shm churn) plus
#            short-lived container create/teardown churn, standing in for the Docker-backed
#            dev/run.sh gates that were live during the original sighting
#   generic  host-side CPU/IO/memory pressure, the stress-ng substitute
#
# Per demo x arm it reports N, the number of distinct output hashes, and — if >1 — the
# 1-based index of the first build whose hash differed from build 1, plus the flip count.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"

usage() {
  cat <<'USAGE'
Usage: dev/measure-build-determinism.sh [OPTIONS]

Measure build determinism of the installed toolchain under several load conditions.

Options:
  --n N            builds per demo per arm (default: 100)
  --demos "a b c"  demo basenames under examples/snes (default: dither newton lsystem
                   mandel-oop gouraud msquares)
  --arms "x y"     arms to run, any of: quiet docker generic (default: "quiet docker")
  --out DIR        results directory (default: $TMPDIR-or-/tmp/build-determinism)
  -h, --help       show this help and exit

Exit status is 0 whether or not a divergence was found; read the summary table.
USAGE
}

N=100
DEMOS="dither newton lsystem mandel-oop gouraud msquares"
ARMS="quiet docker"
OUT="${TMPDIR:-/tmp}/build-determinism"

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --n)     N="$2"; shift 2 ;;
    --demos) DEMOS="$2"; shift 2 ;;
    --arms)  ARMS="$2"; shift 2 ;;
    --out)   OUT="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

CLANG="${CLANG:-$ROOT/build/llvm-mos-install/bin/mos-clang}"
INSTALL="${INSTALL:-$ROOT/build/install}"
DEV_IMAGE="${MOS_DEV_IMAGE:-llvm-mos-65816-dev}"

[ -x "$CLANG" ] || { echo "FATAL: no mos-clang at $CLANG" >&2; exit 1; }
[ -e "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: no SDK at $INSTALL/bin/mos-snes.cfg" >&2; exit 1; }

mkdir -p "$OUT"
WORK="$OUT/work"
rm -rf "$WORK"; mkdir -p "$WORK"

# --- load sources ------------------------------------------------------------------
LOAD_PIDS=()
LOAD_CONTAINERS="$WORK/containers"
: > "$LOAD_CONTAINERS"

stop_load() {
  local pid cid
  for pid in "${LOAD_PIDS[@]:-}"; do
    [ -n "$pid" ] || continue
    kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
  done
  LOAD_PIDS=()
  if [ -s "$LOAD_CONTAINERS" ]; then
    while IFS= read -r cid || [ -n "$cid" ]; do
      [ -n "$cid" ] && docker rm -f "$cid" >/dev/null 2>&1 || true
    done < "$LOAD_CONTAINERS"
    : > "$LOAD_CONTAINERS"
  fi
  rm -f /dev/shm/bnd-load.* 2>/dev/null || true
  rm -f "$WORK"/ioload.* 2>/dev/null || true
}
trap 'stop_load' EXIT INT TERM

start_generic_load() {
  local i
  for i in $(seq 1 "$(nproc)"); do
    ( while :; do :; done ) & LOAD_PIDS+=("$!")
  done
  for i in 1 2 3 4; do
    ( while :; do
        dd if=/dev/zero of="$WORK/ioload.$i" bs=1M count=256 conv=fsync 2>/dev/null || true
        rm -f "$WORK/ioload.$i"
      done ) & LOAD_PIDS+=("$!")
  done
  for i in 1 2; do
    ( while :; do
        dd if=/dev/zero of="/dev/shm/bnd-load.$i" bs=1M count=512 2>/dev/null || true
        rm -f "/dev/shm/bnd-load.$i"
      done ) & LOAD_PIDS+=("$!")
  done
}

start_docker_load() {
  local i cid
  command -v docker >/dev/null 2>&1 || { echo "FATAL: docker not available for the docker arm" >&2; exit 1; }
  docker image inspect "$DEV_IMAGE" >/dev/null 2>&1 || { echo "FATAL: docker image $DEV_IMAGE missing" >&2; exit 1; }
  # Long-lived containers: CPU spin + disk IO + page-cache churn, inside the real dev image.
  for i in 1 2 3 4; do
    cid="$(docker run --rm -d "$DEV_IMAGE" bash -c \
      'for j in 1 2; do ( while :; do :; done ) & done
       while :; do dd if=/dev/zero of=/tmp/io bs=1M count=256 conv=fsync 2>/dev/null; rm -f /tmp/io; done')"
    echo "$cid" >> "$LOAD_CONTAINERS"
  done
  # Container create/teardown churn: what a loop of dev/run.sh invocations actually does to
  # the host (image-layer IO, overlayfs mount/unmount, containerd/dockerd CPU).
  ( while :; do
      docker run --rm "$DEV_IMAGE" bash -c 'ls -R /usr/lib >/dev/null 2>&1' >/dev/null 2>&1 || true
    done ) & LOAD_PIDS+=("$!")
}

start_load() {
  case "$1" in
    quiet)   : ;;
    generic) start_generic_load ;;
    docker)  start_docker_load ;;
    *) echo "FATAL: unknown arm '$1'" >&2; exit 2 ;;
  esac
}

# --- per-demo flags: mirror dev/build.sh's marker-in-the-source detection ------------
demo_flags() {  # $1 = source path; prints extra argv, newline-separated
  local src="$1"
  if grep -q 'mos-a16-only' "$src"; then
    printf '%s\n' -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16
  else
    printf '%s\n' -mcpu=mosw65816
  fi
}

demo_cfg() {    # $1 = source path
  local src="$1"
  if   grep -q 'snes-far-platform'     "$src"; then echo "$INSTALL/bin/mos-snes-far.cfg"
  elif grep -q 'snes-gallery-platform' "$src"; then echo "$INSTALL/bin/mos-snes-gallery.cfg"
  else echo "$INSTALL/bin/mos-snes.cfg"; fi
}

# --- main --------------------------------------------------------------------------
RESULTS="$OUT/hashes.tsv"
: > "$RESULTS"

echo "==> toolchain: $CLANG"
echo "==> N=$N  arms='$ARMS'  demos='$DEMOS'"
echo "==> results: $RESULTS"

for arm in $ARMS; do
  echo
  echo "==> arm '$arm' — starting load"
  start_load "$arm"
  [ "$arm" = quiet ] || sleep 5     # let the load actually ramp before the first build
  echo "    load average at arm start: $(cut -d' ' -f1-3 /proc/loadavg)"
  start_epoch=$(date -u +%s)
  for i in $(seq 1 "$N"); do
    for demo in $DEMOS; do
      src="$ROOT/examples/snes/$demo.c"
      [ -e "$src" ] || { echo "FATAL: missing $src" >&2; exit 1; }
      mapfile -t flags < <(demo_flags "$src")
      cfg="$(demo_cfg "$src")"
      rom="$WORK/$arm-$demo-$i.sfc"
      if ! "$CLANG" --config "$cfg" "${flags[@]}" -Os -o "$rom" "$src" >/dev/null 2>&1; then
        printf '%s\t%s\t%s\t%s\n' "$arm" "$demo" "$i" "BUILD-FAILED" >> "$RESULTS"
        rm -f "$rom"
        continue
      fi
      h="$(sha256sum "$rom" | cut -c1-16)"
      printf '%s\t%s\t%s\t%s\n' "$arm" "$demo" "$i" "$h" >> "$RESULTS"
      # Keep build 1 as the reference and every build whose hash differs from it, so a flip
      # leaves its bytes behind for diffing (cmp/objdump); discard the identical majority.
      refvar="ref_${arm//-/_}_${demo//-/_}"
      if [ -z "${!refvar:-}" ]; then
        declare "$refvar=$h"
        mv "$rom" "$OUT/$arm-$demo-ref.sfc"
      elif [ "$h" != "${!refvar}" ]; then
        mv "$rom" "$OUT/$arm-$demo-$i-DIVERGENT.sfc"
        echo "    !! $arm/$demo build $i diverged: $h vs ${!refvar} -> $OUT/$arm-$demo-$i-DIVERGENT.sfc"
      else
        rm -f "$rom"
      fi
    done
    if [ $((i % 20)) -eq 0 ]; then
      echo "    [$arm] $i/$N passes  ($(( $(date -u +%s) - start_epoch ))s, load $(cut -d' ' -f1 /proc/loadavg))"
    fi
  done
  echo "    load average at arm end:   $(cut -d' ' -f1-3 /proc/loadavg)"
  stop_load
  echo "==> arm '$arm' done in $(( $(date -u +%s) - start_epoch ))s"
done

echo
echo "==> summary (arm, demo, N, distinct hashes, first differing index, differing builds)"
awk -F'\t' '
  { key=$1 "\t" $2
    if (!(key in n)) { order[++k]=key; first[key]=$4 }
    n[key]++
    if (!((key SUBSEP $4) in seen)) { seen[key,$4]=1; distinct[key]++ }
    if ($4 != first[key]) { diff[key]++; if (!(key in firstdiff)) firstdiff[key]=$3 }
  }
  END {
    printf "%-8s %-12s %5s %9s %11s %9s\n", "ARM","DEMO","N","DISTINCT","FIRST-DIFF","N-DIFF"
    for (i=1;i<=k;i++) { key=order[i]; split(key,p,"\t")
      printf "%-8s %-12s %5d %9d %11s %9d\n", p[1],p[2],n[key],distinct[key],
        (key in firstdiff ? firstdiff[key] : "-"), (key in diff ? diff[key] : 0)
    }
  }' "$RESULTS"
