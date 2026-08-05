#!/usr/bin/env bash
# dev/c65asr/run-c65.sh — execute a bare-metal 65CE02 image on MAME's Commodore 65
# driver (CSG 4510 core) and read back the kernel's checksum from RAM.
#
# ############################################################################
# # DOES NOT WORK — kept as the record of the attempt. MAME's c65 driver does
# # not map the $E000 ROM window ("rom8 / roma / rome all causes bootstrap
# # issues if hooked up" — src/mame/commodore/c65.cpp), so the reset vector is
# # never fetched from our image and the code never runs. The driver is also
# # flagged preliminary. Read docs/howto-testing-65ce02-code.md (Level 3),
# # especially the NOP-sled false-positive trap, before touching this.
# ############################################################################
#
# No Commodore ROM is involved: the c65 driver wants a 128 KiB image in its "ipl"
# region, and we synthesise that image ourselves with our own code in it. MAME
# reports WRONG CHECKSUMS and runs it anyway. CPU $E000-$FFFF maps to image
# offset $1E000-$1FFFF (established by probing the reset vector).
set -euo pipefail

usage() { echo "Usage: dev/c65asr/run-c65.sh <8KiB-image> [frames]"; exit 0; }
[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage
[ $# -ge 1 ] || usage

BIN="$1"; FRAMES="${2:-4000}"
HERE="$(cd "$(dirname "$0")" && pwd)"
[ "$(stat -c%s "$BIN")" -eq 8192 ] || { echo "expected an 8192-byte image, got $(stat -c%s "$BIN")" >&2; exit 1; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

python3 - "$BIN" "$WORK/910111.bin" <<'PY'
import sys
blob = open(sys.argv[1], 'rb').read()
rom = bytearray(b'\x00' * 0x20000)
rom[0x1E000:0x1E000 + len(blob)] = blob        # CPU $E000-$FFFF
open(sys.argv[2], 'wb').write(bytes(rom))
PY

( cd "$WORK" && zip -q c65.zip 910111.bin )
mkdir -p "$HOME/mame/roms"
cp "$WORK/c65.zip" "$HOME/mame/roms/c65.zip"

cat > "$WORK/read.lua" <<LUA
local frames = 0
local mem = nil
emu.add_machine_frame_notifier(function()
  frames = frames + 1
  if mem == nil then mem = manager.machine.devices[":maincpu"].spaces["program"] end
  local flag = mem:read_u8(0x0402)
  if flag == 0x5A then
    local lo, hi = mem:read_u8(0x0400), mem:read_u8(0x0401)
    print(string.format("C65RESULT=0x%02X%02X frames=%d", hi, lo, frames))
    manager.machine:exit()
  elseif frames >= $FRAMES then
    local pc = manager.machine.devices[":maincpu"].state["PC"].value
    print(string.format("C65TIMEOUT frames=%d PC=%04X flag=%02X", frames, pc, flag))
    manager.machine:exit()
  end
end)
LUA

timeout 900 mame c65 -video none -sound none -window -skip_gameinfo -nothrottle \
  -autoboot_script "$WORK/read.lua" 2>&1 | grep -E 'C65RESULT|C65TIMEOUT' || {
    echo "C65ERROR: no verdict line" >&2; exit 2; }
