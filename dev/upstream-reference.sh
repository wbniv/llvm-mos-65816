#!/usr/bin/env bash
# Run tools from a revision-pinned, unpatched upstream compiler snapshot.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REVISION="${MOS_UPSTREAM_REFERENCE_REVISION:-742d554bf08042b8df93d791c335260fadd16643}"
REFERENCE="$ROOT/build/upstream-reference/$REVISION"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# == 0 ]]; then
  cat <<'USAGE'
Usage: dev/upstream-reference.sh TOOL [ARGS...]
       dev/upstream-reference.sh --verify

Run a saved upstream tool in its recorded build container. Paths in ARGS are
relative to the repository root, mounted at /work. Absolute /work paths also work.
MOS_UPSTREAM_REFERENCE_REVISION selects another saved revision.

Example:
  dev/upstream-reference.sh clang --target=mos -mcpu=mos6502 -Os \
    -mllvm -verify-machineinstrs -c examples/65816/rcundef2.c -o build/check.o
USAGE
  exit 0
fi

if [[ ! -f "$REFERENCE/manifest.json" ]]; then
  echo "Missing upstream reference: $REFERENCE (see docs/upstream-reference-build.md)" >&2
  exit 1
fi

if [[ "$1" == "--verify" ]]; then
  cd "$REFERENCE"
  exec sha256sum --check --quiet SHA256SUMS
fi

TOOL="$1"
shift
if [[ "$TOOL" == */* || ! -x "$REFERENCE/bin/$TOOL" ]]; then
  echo "No saved upstream tool named: $TOOL" >&2
  exit 1
fi

IMAGE="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["container_image_id"])' "$REFERENCE/manifest.json")"
exec docker run --rm --network none --user "$(id -u):$(id -g)" \
  --ulimit core=0 -v "$ROOT:/work" \
  -v "$REFERENCE:/work/build/upstream-reference/$REVISION:ro" -w /work \
  "$IMAGE" "/work/build/upstream-reference/$REVISION/bin/$TOOL" "$@"
