#!/usr/bin/env bash
# Run an ad-hoc command inside the dev container the same way dev/run.sh does:
# repo mounted at /work, running AS THE HOST USER. A plain `docker run` without
# --user runs as root and leaves root-owned files under build/, which then
# breaks the next host-side build or install with "Operation not permitted"
# (seen 2026-09-22: 60 such files across build/llvm-mos{,-install}).
#
# usage: dev/container.sh [-v HOST:CONTAINER ...] -- CMD [ARGS...]
#        dev/container.sh --fix-owner        # chown root-owned files under build/ back to you
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$HERE")"; IMAGE=llvm-mos-65816-dev
usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; }
[ $# -eq 0 ] && { usage; exit 0; }
case "$1" in -h|--help) usage; exit 0;; esac
source "$HERE/docker-user.sh"
container_identity="$(docker_container_identity)"
if [ "$1" = "--fix-owner" ]; then
  if [ "$container_identity" = "0:0" ] && [ "$(id -u)" != 0 ]; then
    echo "Rootless Docker cannot repair files owned by host root; use an explicit administrator operation." >&2
    exit 1
  fi
  mapfile -t bad < <(find "$ROOT/build" -user root 2>/dev/null)
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) root-owned files under build/: ${#bad[@]}"
  [ ${#bad[@]} -eq 0 ] && exit 0
  docker run --rm -v "$ROOT":/work "$IMAGE" sh -c 'find /work/build -user root -exec chown -h '"$(id -u):$(id -g)"' {} +'
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) repaired; remaining: $(find "$ROOT/build" -user root 2>/dev/null | wc -l)"
  exit 0
fi
mounts=(-v "$ROOT":/work)
while [ $# -gt 0 ]; do
  case "$1" in
    -v) mounts+=(-v "$2"); shift 2;;
    --) shift; break;;
    *) echo "unexpected argument: $1 (put the command after --)" >&2; exit 2;;
  esac
done
[ $# -gt 0 ] || { echo "no command given after --" >&2; exit 2; }
# Core dumps are off: batch runs expect compiler aborts, and the host stores
# every dump in root-owned /var/lib/systemd/coredump.
exec docker run --rm "${mounts[@]}" --user "$container_identity" --ulimit core=0 \
  -e HOME=/work/build -w /work "$IMAGE" "$@"
