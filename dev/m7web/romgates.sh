#!/usr/bin/env bash
# dev/m7web/romgates.sh — plan 121 ROM/timeline gate evidence for mandel-oop, host-side (no Docker):
# gate 1 (host oracle), 4 (three byte-identical captures), 6 (main() audit), 8–16 (entropy-pinned
# framescan + per-frame captures in the browser crop), and 21 (the deployed ROMs against their own
# manifests). Run AFTER `dev/run.sh mandel-oop` has produced build/mandel-oop.sfc.
#
# Usage: dev/m7web/romgates.sh <fresh_off_hex> [deployed_off_hex]
#   fresh_off_hex     corpus_result WRAM offset of build/mandel-oop.sfc (printed by dev/run.sh mandel-oop)
#   deployed_off_hex  the offset both site manifests declare (default: read from the biohack manifest)
#   OUT=<dir>         captures + framescan land here (default build/m7web/rom)
#   BIOHACK_SITE / INDRI_SITE   site checkouts (default ~/biohack.net, ~/indri.studio)
set -euo pipefail
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0; fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$ROOT/build/m7web/rom}"; mkdir -p "$OUT"
BIOHACK="${BIOHACK_SITE:-/home/will/biohack.net}"
INDRI="${INDRI_SITE:-/home/will/indri.studio}"
OFF="$1"
DEP_OFF="${2:-$(python3 -c "import json;print([r for r in json.load(open('$BIOHACK/public/play/roms/manifest.json'))['roms'] if r['id']=='mandel-oop'][0]['selfcheck']['off'])")}"
JGX="$ROOT/build/jgxcheck"; DB="$ROOT/vendor/bsnes-jg/Database"; ROM="$ROOT/build/mandel-oop.sfc"
cd "$ROOT"

echo "## gate 1 — host oracle"
cc -O2 -I examples/65816 -I tools tools/mandel-render.c -o "$OUT/mandel-render"
"$OUT/mandel-render" "$OUT/mandel-host.png" 64 56 15

echo; echo "## gate 4 — three final captures (default entropy)"
for i in 1 2 3; do "$JGX" "$ROM" "$DB" "$OFF" 2 0x204F 5800 "$OUT/cap$i.png"; done
(cd "$OUT" && sha256sum cap1.png cap2.png cap3.png)

echo; echo "## gate 6 — main() audit"
awk '/^int main/,0' examples/snes/mandel-oop.c

echo; echo "## gates 8–16 — entropy-pinned framescan (browser crop, yoff=8)"
JGX_ENTROPY=0 JGX_FRAMESCAN=1 JGX_FRAMESCAN_MAX=9000 "$JGX" "$ROM" "$DB" "$OFF" 2 0x204F 5800 > "$OUT/framescan.txt"
grep -c '^FRAMESCAN: f=' "$OUT/framescan.txt" | sed 's/^/change events: /'
grep '^SMOKE\|^FRAMESCAN: [0-9]' "$OUT/framescan.txt" || true
python3 - "$OUT/framescan.txt" <<'EOF'
import re, sys
ev = []
for l in open(sys.argv[1]):
    m = re.match(r'FRAMESCAN: f=(\d+) hash=(\w+) dom=#(\w+) pct=(-?\d+)', l)
    if m: ev.append((int(m.group(1)), m.group(2), m.group(3), int(m.group(4))))
# Reconstruct every frame: the last event at/before a frame is its state; black := #000000 at >= 99%.
frames = 5800; evi = 0; state = False; runs = []; start = None
for f in range(1, frames + 1):
    while evi < len(ev) and ev[evi][0] == f:
        state = (ev[evi][2] == '000000' and ev[evi][3] >= 99); evi += 1
    if state and start is None: start = f
    if not state and start is not None: runs.append((start, f - 1)); start = None
if start is not None: runs.append((start, frames))
print('all-black intervals (dominant colour #000000 at >=99%):', runs)
print('change events, f=170..340:', [e[0] for e in ev if 170 <= e[0] <= 340])
post = [e[0] for e in ev if e[0] > (runs[-1][1] if runs else 0)]
gaps = [(b - a, a) for a, b in zip(post, post[1:])]
if gaps:
    g = max(gaps); print(f'max gap between change events after the loading field appears: {g[0]} frames (from f={g[1]})')
EOF

echo; echo "## per-frame captures (JGX_ENTROPY=0 JGX_YOFF=8) at the 2026-08-04 table's frames"
for f in 60 120 200 239 245 250 255 260 275 300 450 1200 3000 5800; do
  JGX_ENTROPY=0 JGX_YOFF=8 "$JGX" "$ROM" "$DB" "$OFF" 2 0x204F "$f" "$OUT/f$f.png" > /dev/null 2>&1 || true
done
python3 - "$OUT" <<'EOF'
import sys, zlib, struct, os
def readpng(p):                       # RGB8 non-interlaced (png_write.h output); no PIL needed
    d = open(p, 'rb').read(); i = 8; idat = b''; w = h = 0
    while i < len(d):
        n, = struct.unpack('>I', d[i:i+4]); t = d[i+4:i+8]; c = d[i+8:i+8+n]; i += 12 + n
        if t == b'IHDR': w, h, bd, ct = struct.unpack('>IIBB', c[:10]); assert (bd, ct) == (8, 2)
        elif t == b'IDAT': idat += c
    raw = zlib.decompress(idat); stride = w * 3; rows = []; prev = bytearray(stride); pos = 0
    for y in range(h):
        ft = raw[pos]; pos += 1; line = bytearray(raw[pos:pos+stride]); pos += stride
        for x in range(stride):
            a = line[x-3] if x >= 3 else 0; b = prev[x]; c = prev[x-3] if x >= 3 else 0
            if ft == 1: line[x] = (line[x] + a) & 255
            elif ft == 2: line[x] = (line[x] + b) & 255
            elif ft == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif ft == 4:
                p = a + b - c; pa, pb, pc = abs(p-a), abs(p-b), abs(p-c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        rows.append(bytes(line)); prev = line
    return w, h, rows
out = sys.argv[1]; prevpx = None
print(' frame nonblack%  colours  row0_nb  row223_nb  diff_prev%')
for f in [60, 120, 200, 239, 245, 250, 255, 260, 275, 300, 450, 1200, 3000, 5800]:
    p = f'{out}/f{f}.png'
    if not os.path.exists(p): print(f'{f:6}  (no capture)'); continue
    w, h, rows = readpng(p)
    px = [tuple(r[x*3:x*3+3]) for r in rows for x in range(w)]
    nb = sum(1 for q in px if q != (0, 0, 0)); cols = len(set(px))
    r0 = sum(1 for x in range(w) if tuple(rows[0][x*3:x*3+3]) != (0, 0, 0))
    rl = sum(1 for x in range(w) if tuple(rows[h-1][x*3:x*3+3]) != (0, 0, 0))
    diff = '-' if prevpx is None else f'{100 * sum(1 for a, b in zip(px, prevpx) if a != b) / len(px):.2f}'
    print(f'{f:6} {100*nb/len(px):8.2f}% {cols:8} {r0:8} {rl:10} {diff:>11}')
    prevpx = px
EOF

echo; echo "## gate 21 — deployed ROMs against their manifests ($DEP_OFF, 5800 frames)"
"$JGX" "$BIOHACK/public/play/roms/mandel-oop.sfc" "$DB" "$DEP_OFF" 2 0x204F 5800
"$JGX" "$INDRI/public/apps/llvm-mos-65816/play/roms/mandel-oop.sfc" "$DB" "$DEP_OFF" 2 0x204F 5800
echo "fresh build: corpus_result @ WRAM $OFF; manifests declare $DEP_OFF"
