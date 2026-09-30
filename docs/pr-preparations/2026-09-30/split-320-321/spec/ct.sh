#!/usr/bin/env bash
# Run a shell snippet in the dev container with B=build/bin, L=llc dir, cwd newtests.
# usage: ct.sh 'SNIPPET'
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,3p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
cd /home/will/llvm-mos-65816
exec dev/container.sh -- bash -c "ulimit -c 0; B=/work/build/split-320-321/build/bin; L=/work/build/split-320-321/llc; cd /work/build/split-320-321/newtests; $1" </dev/null
