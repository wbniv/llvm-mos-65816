#!/usr/bin/env bash
# Host-side driver: (re)build the dev image and run a dev/<target>.sh inside it
# against this repo. Usage: dev/run.sh [build|compile|validate]   (default: build)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
IMAGE=llvm-mos-65816-dev
TARGET="${1:-build}"

docker build -t "$IMAGE" "$HERE" >/dev/null
mkdir -p "$ROOT/build"
exec docker run --rm \
  -v "$ROOT":/work \
  --user "$(id -u):$(id -g)" \
  -e HOME=/work/build \
  "$IMAGE" bash "/work/dev/${TARGET}.sh"
