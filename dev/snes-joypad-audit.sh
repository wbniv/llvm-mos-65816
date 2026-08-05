#!/usr/bin/env bash
# Reject new manual joypad polling in ROM sources unless the file carries an
# explicit reviewed exception marker. The HAL itself remains the owner of the
# low-level serial implementation.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
bad=0
while IFS= read -r file; do
  if grep -q 'SNES_MANUAL_JOYPAD_OK' "$file"; then
    continue
  fi
  echo "JOYPAUDIT: manual controller access requires SNES_MANUAL_JOYPAD_OK: ${file#$ROOT/}"
  bad=1
done < <(rg -l -i 'snes_read_pad1[[:space:]]*\(|REG_JOYSER[01]|\$401[67]' \
  "$ROOT/examples/snes" -g '*.c' -g '*.h' -g '*.s' -g '*.S' || true)
if [ "$bad" -ne 0 ]; then
  exit 1
fi
echo "JOYPAUDIT: PASS (ROM sources use automatic joypad latches)"
