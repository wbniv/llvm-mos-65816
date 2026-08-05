#!/usr/bin/env bash
# dev/c65asr/run-xemu.sh — execute a bare-metal 65CE02 image on xemu's Commodore 65
# target and read the kernel's checksum back out of a memory dump.
#
# No Commodore ROM is involved. xemu's c65_load_rom() reads *any* file that is
# exactly 0x20000 bytes into `memory + 0x20000` with no checksum or version
# check, so we hand it a 128 KiB image containing our own code and let the CPU
# reset through it. Unlike MAME's c65 driver (incomplete memory model, see
# docs/howto-testing-65ce02-code.md), xemu boots the real machine correctly.
#
# The payload is placed at BOTH candidate file offsets for CPU $E000 —
# 0x0E000 (ROM_C64_KERNAL_REMAP 0x20000) and 0x1E000 (ROM_E000_REMAP 0x30000) —
# together with both vector sets, so it runs whichever window the reset mapping
# selects. Belt and braces beats guessing.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: dev/c65asr/run-xemu.sh <8KiB-image> [seconds] [xc65-binary]

Prints: XEMU_RESULT=0xNNNN   (the checksum the kernel wrote to $0400)
        XEMU_NORUN           (sentinel at $0402 never set — code did not run)
EOF
  exit 0
}
[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage
[ $# -ge 1 ] || usage

BIN="$1"; SECS="${2:-25}"; XC65="${3:-/tmp/xemu/build/bin/xc65.native}"
[ -x "$XC65" ] || { echo "no xc65 binary at $XC65 (build xemu first)" >&2; exit 1; }
[ "$(stat -c%s "$BIN")" -eq 8192 ] || { echo "expected an 8192-byte image" >&2; exit 1; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

python3 - "$BIN" "$WORK/rom.bin" <<'PY'
import sys
blob = open(sys.argv[1], 'rb').read()          # CPU $E000-$FFFF, vectors last 6 bytes
rom = bytearray(b'\x00' * 0x20000)
for base in (0x0E000, 0x1E000):                # both candidate reset mappings
    rom[base:base + len(blob)] = blob
open(sys.argv[2], 'wb').write(bytes(rom))
PY

# -skipconfigfile MUST be the first option (xemu rejects it anywhere else).
# -sleepless runs flat out; SIGINT after $SECS makes xemu take its normal exit
# path, which is what writes -dumpmem. Exit 130 is therefore the success case.
set +e
SDL_VIDEODRIVER=dummy timeout -s INT "$SECS" \
  "$XC65" -skipconfigfile -headless -sleepless -besure \
          -rom "$WORK/rom.bin" -dumpmem "$WORK/mem.bin" >"$WORK/log" 2>&1
set -e

[ -s "$WORK/mem.bin" ] || { echo "XEMU_NODUMP (no memory dump written)"; tail -5 "$WORK/log" >&2; exit 2; }

python3 - "$WORK/mem.bin" <<'PY'
import sys
m = open(sys.argv[1], 'rb').read()
flag = m[0x0402]
if flag != 0x5A:
    print("XEMU_NORUN flag=0x%02X dumpsize=%d" % (flag, len(m)))
    sys.exit(3)
print("XEMU_RESULT=0x%02X%02X" % (m[0x0401], m[0x0400]))
PY
