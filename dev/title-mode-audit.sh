#!/usr/bin/env bash
# Assert that the Mode 7 zoom/spin title is used by every, and only, true Mode 7 demo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

expected=(
  avalanche.c blossom.c buddha.c julia.c
  mandel-display.c mandel-double.c mandel-float.c mandel-oop.c
)

mapfile -t actual < <(
  rg -l '#include "snesgfx/m7title\.h"|m7splash(_begin|_end)?\(' examples/snes/*.c |
    xargs -n1 basename | sort -u
)
mapfile -t wanted < <(printf '%s\n' "${expected[@]}" | sort)

rc=0
if ! diff -u <(printf '%s\n' "${wanted[@]}") <(printf '%s\n' "${actual[@]}"); then
  echo "FAIL  Mode 7 title users differ from the true Mode 7 allowlist"
  rc=1
fi

for f in "${expected[@]}"; do
  path="examples/snes/$f"
  if ! rg -q 'm7splash(_begin)?\(' "$path"; then
    echo "FAIL  $f does not invoke the Mode 7 title"
    rc=1
  fi
  if ! rg -q 'm7_begin\(|REG_BGMODE = BGMODE_7' "$path"; then
    echo "FAIL  $f does not initialize the running demo in Mode 7"
    rc=1
  fi
done

for f in hilbert.c cordic.c; do
  path="examples/snes/$f"
  rg -q '#include "snesgfx/title_layer\.h"' "$path" || {
    echo "FAIL  $f does not use the regular TitleLayer"; rc=1;
  }
  if rg -q 'm7title\.h|m7splash' "$path"; then
    echo "FAIL  $f uses the Mode 7 title but its running demo is BGMODE_1"
    rc=1
  fi
done

rg -q 'title_begin16\([^;]*"SPACE-FILLING", "HILBERT CURVE"' examples/snes/hilbert.c || {
  echo "FAIL  hilbert.c title is not exactly HILBERT CURVE"; rc=1;
}

if [ "$rc" -eq 0 ]; then
  echo "PASS  exactly ${#expected[@]} true Mode 7 demos use the zoom/spin title"
  echo "PASS  Hilbert and Cordic use the regular TitleLayer"
fi
exit "$rc"
