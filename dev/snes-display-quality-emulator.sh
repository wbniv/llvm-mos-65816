#!/usr/bin/env bash
# Slow release gate: ROM self-checks plus per-frame force-blank-bleed scan.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
site=${SITE:-${1:-}}

if [[ -z "$site" ]]; then
    echo "usage: SITE=/path/to/site $0 [--only slug[,slug...]]" >&2
    exit 2
fi
if [[ $# -gt 0 && "$1" != --* ]]; then shift; fi

exec "$repo_root/dev/verify-web-roms.sh" --site "$site" "$@"
