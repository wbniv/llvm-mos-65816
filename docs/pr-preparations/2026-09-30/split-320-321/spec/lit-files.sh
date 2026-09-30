#!/usr/bin/env bash
# Run llvm-lit on selected test files of the split worktree's checkout.
#
# usage: lit-files.sh TEST_PATH...   (paths relative to the source root)
# Mounts the split source and build as configured (register-exhaustion-src,
# 0029-cross-target-build) in the dev container, with ulimit -c 0,
# ulimit -v 2000000, a timeout and three lit workers.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
SPLIT=/home/will/llvm-mos-65816/build/split-320-321
args=(); for t in "$@"; do args+=("/work/build/register-exhaustion-src/$t"); done
cd /home/will/llvm-mos-65816
exec dev/container.sh -v "$SPLIT/source":/work/build/register-exhaustion-src \
  -v "$SPLIT/build":/work/build/0029-cross-target-build -- \
  sh -c 'ulimit -c 0; ulimit -v 2000000; exec timeout 1200 /work/build/0029-cross-target-build/bin/llvm-lit -j3 -v "$@"' _ "${args[@]}" </dev/null
