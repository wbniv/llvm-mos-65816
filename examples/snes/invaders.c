// Space Invaders on the snesgfx OOP library.
//
// Renders the verified, portable simulation (invaders_logic.h) as hardware sprites through snesgfx:
// a Display (boot bracket + v-blank-gated DMA queue), one SpriteSet (the 544-byte OAM front-end),
// and a Game/App object. It runs the DETERMINISTIC attract sequence (a scripted AI — no joypad) and
// latches corpus_result = the rolling state CRC at frame INV_FRAMES, matching the host oracle
// (tools/invaders-sim.c) and the corpus slice exactly: host == default@MAME == a16@MAME ==
// a16@bsnes-jg == 0x3DAC. No far pointers, so it builds default + a16 + xy16 (the full 5-way bar).
//
// Sprite tiles are generated at runtime from compact 1bpp shapes (recognizable squid/crab/octopus/
// ship/UFO) so the file links standalone today; the polished gfx4snes 16x16 art (Option B: PNG ->
// .pic/.pal -> objcopy into ROM .rodata) drops in next without changing the CRC (it is state-based).
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/sprite_set.h"
#include "invaders_logic.h"

#define SPR_CHR   0x4000        // sprite tile VRAM base (word) — OBSEL namebase 2
#define ATTR      0x20          // OAM attr: priority 2, palette group 0, tile# < 256
// OAM slot map (disjoint compile-time ranges, no runtime contention)
#define SLOT_PLAYER 0
#define SLOT_SHOT   1
#define SLOT_BOMB0  2
#define SLOT_UFO    6
#define SLOT_FLEET  8           // 8 .. 8+55-1 = 62
// tile indices in VRAM
enum { T_SQUID = 0, T_CRAB = 2, T_OCTO = 4, T_PLAYER = 6, T_BULLET = 7, T_BOMB = 8, T_UFO = 9, T_COUNT = 10 };

// 1bpp 8x8 shapes (bit7 = leftmost). Two animation frames for each alien.
static const uint8_t shapes[T_COUNT][8] = {
  /* squid A */ { 0x3C,0x7E,0xDB,0xFF,0x24,0x5A,0xA5,0x00 },
  /* squid B */ { 0x3C,0x7E,0xDB,0xFF,0x42,0x24,0x5A,0x00 },
  /* crab  A */ { 0x81,0x42,0x7E,0xDB,0xFF,0xBD,0xA5,0x00 },
  /* crab  B */ { 0x81,0x5A,0xFF,0xDB,0xFF,0x7E,0x24,0x42 },
  /* octo  A */ { 0x3C,0x7E,0xFF,0xDB,0xFF,0x24,0x5A,0x81 },
  /* octo  B */ { 0x3C,0x7E,0xFF,0xDB,0xFF,0x42,0xA5,0x42 },
  /* player */  { 0x18,0x18,0x3C,0x7E,0xFF,0xFF,0xFF,0xFF },
  /* bullet */  { 0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00 },
  /* bomb   */  { 0x18,0x30,0x18,0x30,0x18,0x30,0x18,0x00 },
  /* ufo    */  { 0x00,0x3C,0x7E,0xFF,0x7E,0x24,0x00,0x00 },
};
// per-tile colour index (into sprite palette group 0)
static const uint8_t tile_color[T_COUNT] = { 2,2, 3,3, 4,4, 1, 1, 5, 5 };
// sprite palette group 0 -> CGRAM 128.. (index 0 = transparent)
static const uint16_t pal[6] = {
  0x0000, SNES_RGB(31,31,31), SNES_RGB(0,31,0), SNES_RGB(0,31,31), SNES_RGB(31,31,0), SNES_RGB(31,0,0),
};
static const uint16_t backdrop = 0x0000;     // CGRAM 0 — black (set for determinism; bsnes randomizes)
static const uint8_t row_tile[INV_ROWS] = { T_SQUID, T_CRAB, T_CRAB, T_OCTO, T_OCTO };

static uint8_t tilebuf[T_COUNT * 32];        // 4bpp tiles, staged for one DMA to OBJ VRAM

// Expand each 1bpp shape into a 4bpp tile coloured by tile_color[t]
// (4bpp: bytes [p0,p1] x 8 rows, then [p2,p3] x 8 rows; a set bit takes the colour's bit in each plane).
static void build_tiles(void) {
  for (uint8_t t = 0; t < T_COUNT; t++) {
    uint8_t c = tile_color[t];
    uint8_t *o = &tilebuf[t * 32];
    for (uint8_t r = 0; r < 8; r++) {
      uint8_t row = shapes[t][r];
      o[2 * r]      = (c & 1) ? row : 0;
      o[2 * r + 1]  = (c & 2) ? row : 0;
      o[16 + 2 * r] = (c & 4) ? row : 0;
      o[16 + 2 * r + 1] = (c & 8) ? row : 0;
    }
  }
}

// Draw the whole simulation state into the OAM shadow (typed, static-dispatch — no per-entity vtable).
// noinline: bounds +mos-a16 register pressure (handoff §4) — the fleet loop holds many live 16-bit
// values, and inlining the whole snesgfx + render chain into main() overruns the allocator.
__attribute__((noinline))
static void render(const inv_state *s, SpriteSet *spr) {
  sprite_set_put(spr, SLOT_PLAYER, s->player_x, (uint8_t)INV_PLAYER_Y, T_PLAYER, ATTR, 0);

  if (s->pbul_live) sprite_set_put(spr, SLOT_SHOT, s->pbul_x, (uint8_t)s->pbul_y, T_BULLET, ATTR, 0);
  else              sprite_set_hide(spr, SLOT_SHOT);

  for (uint8_t i = 0; i < INV_NBOMB; i++) {
    uint8_t sl = (uint8_t)(SLOT_BOMB0 + i);
    if (s->bomb_live[i]) sprite_set_put(spr, sl, s->bomb_x[i], (uint8_t)s->bomb_y[i], T_BOMB, ATTR, 0);
    else                 sprite_set_hide(spr, sl);
  }

  if (s->ufo_live) sprite_set_put(spr, SLOT_UFO, s->ufo_x, (uint8_t)INV_UFO_Y, T_UFO, ATTR, 0);
  else             sprite_set_hide(spr, SLOT_UFO);

  for (uint8_t r = 0; r < INV_ROWS; r++)
    for (uint8_t c = 0; c < INV_COLS; c++) {
      uint8_t sl = (uint8_t)(SLOT_FLEET + r * INV_COLS + c);
      if (inv_alive(s, r, c))
        sprite_set_put(spr, sl, inv_alien_x(s, c), (uint8_t)inv_alien_y(s, r),
                       (uint8_t)(row_tile[r] + s->anim), ATTR, 0);
      else
        sprite_set_hide(spr, sl);
    }
}

// The application is an object: it owns the Display, the SpriteSet, the sim, and the attract CRC state.
typedef struct {
  Display   screen;
  SpriteSet sprites;
  inv_state sim;
  uint16_t  roll;
  uint16_t  frame;
} Game;

volatile uint16_t corpus_result;   // differential proof channel (read from WRAM)

static void game_init(Game *g) {
  display_init(&g->screen);
  sprite_set_init(&g->sprites, /*size_pair*/ 0, SPR_CHR);
  display_add(&g->screen, (Drawable *)&g->sprites);
  build_tiles();
  upq_push_cgram(&g->screen.q, 0, &backdrop, 0x00, 2);                               // backdrop black
  upq_push_vram(&g->screen.q, SPR_CHR, tilebuf, 0x00, sizeof tilebuf, VMAIN_INC_HIGH_1);
  sprite_set_palette(&g->sprites, &g->screen.q, /*group*/ 0, pal, sizeof pal);
  inv_init(&g->sim);
  g->roll = 0xFFFF;
  g->frame = 0;
}

// One attract frame: advance the deterministic sim, fold the rolling CRC, latch at INV_FRAMES.
// noinline for the same a16 register-pressure reason (inv_step is already noinline in the header).
__attribute__((noinline))
static void game_step(Game *g) {
  if (g->frame < (uint16_t)INV_FRAMES) {
    inv_step(&g->sim);
    g->roll = inv_fold(g->roll, &g->sim);
    if (++g->frame == (uint16_t)INV_FRAMES)
      corpus_result = (uint16_t)(g->roll ^ inv_state_crc(&g->sim));   // == host oracle == 0x3DAC
  }
}

int main(void) {
  static Game g;
  game_init(&g);
  for (;;) {
    game_step(&g);
    render(&g.sim, &g.sprites);
    display_frame(&g.screen);     // wait v-blank, emit OAM, flush DMA, release force-blank on frame 1
  }
}
