// Space Invaders on the snesgfx OOP library.
//
// P0 bring-up: exercise the snesgfx core (Display boot bracket + UploadQueue + VramAlloc + Scene)
// and the new SpriteSet (OAM front-end). Draws a short row of hardware sprites (a proto-fleet) via
// the 544-byte OAM shadow DMA'd each v-blank. The sprite tile is generated at runtime (a solid
// 4bpp block) so this file links standalone under the generic examples build — the real squid/crab/
// octopus art arrives later via gfx4snes-baked .pic/.pal objcopied into ROM (Option B).
//
// Builds default-8-bit AND +mos-a16 (no far pointers). sentinel==0x42 once set up (smoke gate).
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/sprite_set.h"

#define SPR_CHR 0x4000          // sprite tile VRAM base (word) — OBSEL namebase 2 ($4000/$2000)

static uint8_t  spr_tile[32];   // one runtime 4bpp 8x8 tile, staged for DMA to OBJ VRAM
static const uint16_t spr_pal[4] = {   // sprite palette group 0 -> CGRAM 128..
  0x0000,                 // index 0 = transparent (backdrop shows through)
  SNES_RGB(31, 31, 31),   // 1 = white
  SNES_RGB(0, 31, 0),     // 2 = green
  SNES_RGB(31, 0, 0),     // 3 = red
};

volatile unsigned char sentinel;       // smoke-test proof channel (read from WRAM)

// A solid colour-index-1 8x8 4bpp tile: plane0 = 0xFF per row, planes 1/2/3 = 0
// (4bpp layout: bytes [p0,p1] x 8 rows, then [p2,p3] x 8 rows).
static void make_tile(void) {
  for (uint8_t r = 0; r < 8; r++) { spr_tile[2 * r] = 0xFF; spr_tile[2 * r + 1] = 0x00; }
  for (uint8_t i = 16; i < 32; i++) spr_tile[i] = 0x00;
}

int main(void) {
  static Display   d;
  static SpriteSet sprites;

  display_init(&d);                                   // boot bracket (force-blank, zero PPU, BG mode 1)
  sprite_set_init(&sprites, /*size_pair*/ 0, SPR_CHR);
  display_add(&d, (Drawable *)&sprites);              // reserve: OBSEL + enable OBJ

  make_tile();
  upq_push_vram(&d.q, SPR_CHR, spr_tile, 0x00, sizeof spr_tile, VMAIN_INC_HIGH_1);  // tile -> OBJ VRAM
  sprite_set_palette(&sprites, &d.q, /*group*/ 0, spr_pal, sizeof spr_pal);          // palette -> CGRAM 128

  for (uint8_t i = 0; i < 5; i++)                     // a proto-fleet row of 5 sprites
    sprite_set_put(&sprites, i, (int16_t)(80 + i * 24), 96, /*tile*/ 0, /*attr*/ 0x30, /*large*/ 0);

  sentinel = 0x42;
  for (;;) display_frame(&d);                         // wait v-blank, emit OAM, flush DMA, show
}
