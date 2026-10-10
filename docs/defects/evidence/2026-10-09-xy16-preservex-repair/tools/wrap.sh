#!/usr/bin/env bash
# Run a command with REPO bound at /work in a private mount namespace (host
# binaries; no container). Extra binds: WRAP_BINDS="src:dst src:dst".
set -euo pipefail
case "${1-}" in -h|--help) sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
REPO=${WRAP_REPO:-/home/will/llvm-mos-65816}
args=(--ro-bind /usr /usr --symlink usr/lib /lib --symlink usr/lib64 /lib64
      --symlink usr/bin /bin --symlink usr/sbin /sbin --ro-bind /etc /etc
      --proc /proc --dev /dev --bind /home /home --bind /tmp /tmp
      --bind "$REPO" /work)
for b in ${WRAP_BINDS:-}; do args+=(--bind "${b%%:*}" "${b#*:}"); done
exec bwrap "${args[@]}" --chdir /work -- "$@"
