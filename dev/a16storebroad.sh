#!/usr/bin/env bash
# Compare near-store value sources and arithmetic with the host and both cores.
set -euo pipefail
ROOT=/work
SRC="$ROOT/examples/65816/a16storebroad.c"
ORACLE="$ROOT/build/a16storebroad-host"
if [ ! -x "$ROOT/build/jgxcheck" ] || [ ! -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "FATAL: bsnes-jg is required (run dev/run.sh xcheck first)" >&2
  exit 1
fi
/usr/bin/cc -O2 -DHOST_MAIN "$SRC" -o "$ORACLE"
expected="$("$ORACLE")"
python3 "$ROOT/tools/a16_fuzz.py" check --src "$SRC" --expected "$expected" --name a16storebroad
