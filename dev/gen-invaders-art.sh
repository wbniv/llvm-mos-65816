#!/usr/bin/env bash
# dev/gen-invaders-art.sh — regenerate the committed Space Invaders sprite binaries (Option B).
#
#   art/invaders/draw.py  ->  art/invaders/sprites.png  --(gfx4snes)-->  examples/snes/invaders.{pic,pal}
#
# gfx4snes is the foundry pvsneslib-core tool (PNG/BMP -> SNES 4bpp tiles + BGR555 palette); install
# it once with `sudo apt install pvsneslib-core` (the foundry apt repo is already configured), or
# point PVSNESLIB_HOME at an extracted copy. Routine `dev/build.sh` does NOT need it — it just
# objcopies the committed binaries into ROM; only regenerating the art does.
#
# After running, `git diff examples/snes/invaders.{pic,pal}` shows what changed.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/gen-invaders-art.sh   # PNG art -> gfx4snes -> committed .pic/.pal"; exit 0;; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PVS="${PVSNESLIB_HOME:-/usr/lib/pvsneslib}"
GFX="$PVS/devkitsnes/tools/gfx4snes"
[ -x "$GFX" ] || { echo "FATAL: gfx4snes not at $GFX (sudo apt install pvsneslib-core, or set PVSNESLIB_HOME)"; exit 1; }
command -v python3 >/dev/null || { echo "FATAL: python3 required for the art source"; exit 1; }

cd "$ROOT"
echo "==> drawing art/invaders/sprites.png"
python3 art/invaders/draw.py

echo "==> gfx4snes: sprites.png -> 8x8 4bpp tiles + palette"
"$GFX" -i art/invaders/sprites.png -t png -s 8 -u 16 -o 16 -p -R

mv -f art/invaders/sprites.pic examples/snes/invaders.pic
mv -f art/invaders/sprites.pal examples/snes/invaders.pal
rm -f art/invaders/sprites.inc art/invaders/sprites_data.as
echo "==> wrote examples/snes/invaders.pic ($(stat -c%s examples/snes/invaders.pic) B) + invaders.pal ($(stat -c%s examples/snes/invaders.pal) B)"
