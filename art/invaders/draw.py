#!/usr/bin/env python3
# Authoring source for the Space Invaders sprite sheet (art/invaders/sprites.png).
# Emits an 8-bit indexed PNG of 8x8 cells in tile order; dev/gen-invaders-art.sh then runs gfx4snes
# on it to produce the committed examples/snes/invaders.{pic,pal} (4bpp tiles + palette), which
# dev/build.sh objcopies into bank-$00 ROM and links (Option B). Edit the cells here, rerun
# dev/gen-invaders-art.sh, and the committed binaries + the page screenshot update reproducibly.
#
# Tile order (the T_* enum in invaders.c): 0-9 squidA,squidB,crabA,crabB,octoA,octoB,player,bullet,
# bomb,ufo ; 10 shield block ; 11-20 digits 0-9.
# Palette indices: 0 transparent, 1 white, 2 green, 3 cyan, 4 yellow, 5 red, 6 dark-red.
from PIL import Image

PAL = [(0,0,0),(248,248,248),(40,248,40),(40,248,248),(248,248,40),(248,40,40),(140,0,0)]

# Each sprite cell: 8 rows of 8 chars. '.'=transparent; digit = palette index.
CELLS = [
 ["..2..2..","...22...","..2222..",".22..22.",".222222.","..2..2..",".2.22.2.","2.2..2.2"],  # squid A
 ["..2..2..","2.2222.2","2.2222.2","22222222",".222222.","..2222..",".2.22.2.","2......2"],  # squid B
 ["..3...3.","...3.3..","..33333.",".33.3.33","3333333.","3.33333.","3.3...3.",".3...3.."],  # crab A
 ["..3...3.","3..3.3..","3.33333.","333.3.33","33333333",".3.333.3","..3...3.","..3...3."],  # crab B
 [".444444.","44444444","44.44.44","44444444","..4..4..",".44..44.","4.4..4.4","4......4"],  # octo A
 [".444444.","44444444","44.44.44","44444444",".4.44.4.","4.4444.4","4......4",".4....4."],  # octo B
 ["...11...","...11...","..1111..",".111111.","11111111","11111111","11111111","11111111"],  # player
 ["...11...","...11...","...11...","...11...","...11...","........","........","........"],  # bullet
 ["...5....","....5...","...5....","..5.....","...5....","....5...","...5....","..5....."],  # bomb
 ["........",".555555.","55555555","51515151","66666666",".6....6.","........","........"],  # UFO
 ["02222220","22222222","22222222","22222222","22222222","22222222","22222222","22222222"],  # shield block
]

# 3x5 white digit glyphs -> centred 8x8 cells (cols 2-4, rows 1-5).
DIGITS = {
 0:["111","101","101","101","111"], 1:["010","110","010","010","111"],
 2:["111","001","111","100","111"], 3:["111","001","111","001","111"],
 4:["101","101","111","001","001"], 5:["111","100","111","001","111"],
 6:["111","100","111","101","111"], 7:["111","001","010","010","010"],
 8:["111","101","111","101","111"], 9:["111","101","111","001","111"],
}
for d in range(10):
    cell = [list("........") for _ in range(8)]
    for r, row in enumerate(DIGITS[d]):
        for c, ch in enumerate(row):
            if ch == '1': cell[1 + r][2 + c] = '1'
    CELLS.append(["".join(rw) for rw in cell])

W, H = 8 * len(CELLS), 8
img = Image.new("P", (W, H), 0)
flat = []
for c in PAL: flat += list(c)
flat += [0, 0, 0] * (256 - len(PAL))
img.putpalette(flat)
px = img.load()
for i, cell in enumerate(CELLS):
    ox = i * 8
    for y, row in enumerate(cell):
        for x, ch in enumerate(row):
            px[ox + x, y] = 0 if ch == '.' else int(ch)
img.save("art/invaders/sprites.png")
print("wrote art/invaders/sprites.png  (%dx%d, %d cells)" % (W, H, len(CELLS)))
