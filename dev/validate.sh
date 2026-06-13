#!/usr/bin/env bash
# Structurally validate the M0 SNES smoke ROM. Runs INSIDE the dev container.
set -euo pipefail
ROOT=/work
ROM="$ROOT/build/hello.sfc"

echo "=== size (expect 32768) ==="; stat -c%s "$ROM"

echo "=== internal header @ \$FFB0-\$FFFF (file 0x7FB0) ==="
xxd -s 0x7FB0 -l 0x50 "$ROM"

echo "=== header fields + vectors ==="
python3 - "$ROM" <<'PY'
import sys
d = open(sys.argv[1], "rb").read()
w = lambda o: d[o] | (d[o+1] << 8)
print(f"title       : {d[0x7FC0:0x7FD5].decode('latin1')!r}")
print(f"map mode    : 0x{d[0x7FD5]:02X} (0x20 = LoROM/slow)")
print(f"rom size    : 0x{d[0x7FD7]:02X}   country: 0x{d[0x7FD9]:02X}")
print(f"checksum    : 0x{w(0x7FDE):04X}  complement: 0x{w(0x7FDC):04X}  (sum={w(0x7FDE)+w(0x7FDC):#06x})")
reset = w(0x7FFC)
print(f"emu RESET   : ${reset:04X} -> _start    emu NMI: ${w(0x7FFA):04X}  emu IRQ: ${w(0x7FFE):04X}")
print(f"reset bytes : {d[reset-0x8000:reset-0x8000+16].hex()}")
PY

echo "=== key symbols (linker map) ==="
grep -E '(\b_start\b|\bmain\b|\bnmi\b|\birq\b|__snes_header|__do_init_stack|\bsentinel\b)' \
  "$ROOT/build/hello.map" | head -20
