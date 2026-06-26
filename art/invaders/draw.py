#!/usr/bin/env python3
# Authoring source for the Space Invaders sprite sheet (art/invaders/sprites.png).
# Emits an 8-bit indexed PNG of ten 8x8 cells in tile order; dev/gen-invaders-art.sh then runs
# gfx4snes on it to produce the committed examples/snes/invaders.{pic,pal} (4bpp tiles + palette),
# which dev/build.sh objcopies into bank-$00 ROM and links (Option B). Edit the cells here, rerun
# dev/gen-invaders-art.sh, and the committed binaries (and the screenshot) update reproducibly.
#
# Palette indices: 0 transparent, 1 white, 2 green, 3 cyan, 4 yellow, 5 red, 6 dark-red.
from PIL import Image

PAL = [(0,0,0),(248,248,248),(40,248,40),(40,248,248),(248,248,40),(248,40,40),(140,0,0)]

# Each cell: 8 rows of 8 chars. '.'=transparent; digit = palette index.
CELLS = [
 # squid A / B (green)
 ["..2..2..","...22...","..2222..",".22..22.",".222222.","..2..2..",".2.22.2.","2.2..2.2"],
 ["..2..2..","2.2222.2","2.2222.2","22222222",".222222.","..2222..",".2.22.2.","2......2"],
 # crab A / B (cyan)
 ["..3...3.","...3.3..","..33333.",".33.3.33","3333333.","3.33333.","3.3...3.",".3...3.."],
 ["..3...3.","3..3.3..","3.33333.","333.3.33","33333333",".3.333.3","..3...3.","..3...3."],
 # octopus A / B (yellow)
 [".444444.","44444444","44.44.44","44444444","..4..4..",".44..44.","4.4..4.4","4......4"],
 [".444444.","44444444","44.44.44","44444444",".4.44.4.","4.4444.4","4......4",".4....4."],
 # player ship (white)
 ["...11...","...11...","..1111..",".111111.","11111111","11111111","11111111","11111111"],
 # player bullet (white)
 ["...11...","...11...","...11...","...11...","...11...","........","........","........"],
 # alien bomb (red)
 ["...5....","....5...","...5....","..5.....","...5....","....5...","...5....","..5....."],
 # UFO (red body, dark-red underside)
 ["........",".555555.","55555555","51515151","66666666",".6....6.","........","........"],
]

W, H = 8*len(CELLS), 8
img = Image.new("P", (W, H), 0)
flat = []
for c in PAL: flat += list(c)
flat += [0,0,0]*(256-len(PAL))
img.putpalette(flat)
px = img.load()
for i, cell in enumerate(CELLS):
    ox = i*8
    for y, row in enumerate(cell):
        for x, ch in enumerate(row):
            px[ox+x, y] = 0 if ch == '.' else int(ch)
img.save("art/invaders/sprites.png")
print("wrote art/invaders/sprites.png  (%dx%d, %d cells)" % (W, H, len(CELLS)))
