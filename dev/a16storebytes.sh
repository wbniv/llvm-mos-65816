#!/usr/bin/env bash
# Absolute s16 stores: host == default/a16/xy16 on MAME == a16 on bsnes-jg.
set -euo pipefail
ROOT=/work
SRC="$ROOT/examples/65816/a16storebytes.c"
ORACLE="$ROOT/build/a16storebytes-host"
if [ ! -x "$ROOT/build/jgxcheck" ] || [ ! -d "$ROOT/vendor/bsnes-jg/Database" ]; then
  echo "FATAL: bsnes-jg is required (run dev/run.sh xcheck first)" >&2
  exit 1
fi
/usr/bin/cc -O2 -DHOST_MAIN "$SRC" -o "$ORACLE"
expected="$("$ORACLE")"
python3 "$ROOT/tools/a16_fuzz.py" check --src "$SRC" --expected "$expected" --name a16storebytes
