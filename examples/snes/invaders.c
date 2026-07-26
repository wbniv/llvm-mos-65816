// Space Invaders on the snesgfx OOP library.
//
// Renders the verified, portable simulation (invaders_logic.h) as hardware sprites through snesgfx:
// a Display (boot bracket + v-blank-gated DMA queue), one SpriteSet (the 544-byte OAM front-end),
// and a Game/App object. It runs the DETERMINISTIC attract sequence (a scripted AI — no joypad) and
// latches corpus_result = the rolling state CRC at frame INV_FRAMES, matching the host oracle
// (tools/invaders-sim.c) and the corpus slice exactly: host == default@MAME == a16@MAME ==
// a16@bsnes-jg == 0x3DAC. No far pointers, so it builds default + a16 + xy16 (the full 5-way bar).
//
// Sprite art is authored in art/invaders/sprites.png, converted by gfx4snes to committed
// examples/snes/invaders.{pic,pal}, objcopied into bank-$00 ROM .rodata by dev/build.sh and linked
// (Option B — no compiled C arrays). The 4bpp tiles arrive via INV_TILES / palette via INV_PAL.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/sprite_set.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/controller.h"
#include "invaders_logic.h"
#include "invaders_art.h"

#define SPR_CHR   0x4000        // sprite tile VRAM base (word) — OBSEL namebase 2
#define ATTR      0x20          // OAM attr: priority 2, palette group 0, tile# < 256
// OAM slot map (disjoint compile-time ranges, no runtime contention)
#define SLOT_PLAYER 0
#define SLOT_SHOT   1
#define SLOT_BOMB0  2
#define SLOT_UFO    6
#define SLOT_FLEET  8           // 8 .. 8+55-1 = 62
#define SLOT_SHIELD 63          // 63 .. 94  (4 shields x 8 blocks)
#define SLOT_SCORE  95          // 95 .. 99  (5 score digits)
#define SLOT_LIVES  100         // 100 .. 104 (life icons)
// tile indices in VRAM (match the gfx4snes sheet / art/invaders/draw.py cell order)
enum { T_SQUID = 0, T_CRAB = 2, T_OCTO = 4, T_PLAYER = 6, T_BULLET = 7, T_BOMB = 8, T_UFO = 9,
       T_SHIELD = 10, T_DIGIT0 = 11 };
#define SH_BLOCKS (SH_COLS * SH_ROWS)

static const uint16_t backdrop = 0x0000;     // CGRAM 0 — black (set for determinism; bsnes randomizes)
static const uint8_t row_tile[INV_ROWS] = { T_SQUID, T_CRAB, T_CRAB, T_OCTO, T_OCTO };

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

  // shields: 4 bunkers, each SH_COLS x SH_ROWS blocks; hide a block when its bit is cleared
  for (uint8_t sh = 0; sh < INV_SHIELDS; sh++)
    for (uint8_t b = 0; b < SH_BLOCKS; b++) {
      uint8_t sl = (uint8_t)(SLOT_SHIELD + sh * SH_BLOCKS + b);
      if (s->shield[sh] & (uint8_t)(1u << b))
        sprite_set_put(spr, sl, (int16_t)(SH_X(sh) + (b % SH_COLS) * SH_BLK),
                       (uint8_t)(INV_SH_Y + (b / SH_COLS) * SH_BLK), T_SHIELD, ATTR, 0);
      else
        sprite_set_hide(spr, sl);
    }

  // HUD: 5-digit score (top-left, most-significant first)
  uint16_t sc = s->score;
  for (uint8_t d = 0; d < 5; d++) {
    uint8_t digit = (uint8_t)(sc % 10); sc = (uint16_t)(sc / 10);
    sprite_set_put(spr, (uint8_t)(SLOT_SCORE + (4 - d)), (int16_t)(8 + (4 - d) * 8), 8,
                   (uint8_t)(T_DIGIT0 + digit), ATTR, 0);
  }
  // HUD: lives as little ship icons (top-right)
  for (uint8_t i = 0; i < 5; i++) {
    uint8_t sl = (uint8_t)(SLOT_LIVES + i);
    if (i < s->lives) sprite_set_put(spr, sl, (int16_t)(204 + i * 12), 8, T_PLAYER, ATTR, 0);
    else              sprite_set_hide(spr, sl);
  }
}

// The application is an object: it owns the Display, the SpriteSet, the sim, input, and CRC state.
enum { MODE_ATTRACT = 0, MODE_PLAY = 1 };
typedef struct {
  Display    screen;
  SpriteSet  sprites;
  Controller pad;
  inv_state  sim;
  uint16_t   roll;
  uint16_t   frame;
  uint8_t    mode;
} Game;

volatile uint16_t corpus_result;   // differential proof channel (read from WRAM)

static void game_init(Game *g) {
  display_init(&g->screen);
  sprite_set_init(&g->sprites, /*size_pair*/ 0, SPR_CHR);
  display_add(&g->screen, (Drawable *)&g->sprites);
  upq_push_cgram(&g->screen.q, 0, &backdrop, 0x00, 2);                               // backdrop black
  upq_push_vram(&g->screen.q, SPR_CHR, INV_TILES, 0x00, INV_TILES_LEN, VMAIN_INC_HIGH_1);  // gfx4snes tiles
  sprite_set_palette(&g->sprites, &g->screen.q, /*group*/ 0, INV_PAL, (uint8_t)INV_PAL_LEN); // gfx4snes palette
  controller_init(&g->pad);
  inv_init(&g->sim);
  g->roll = 0xFFFF;
  g->frame = 0;
  g->mode = MODE_ATTRACT;
}

// One frame. ATTRACT: the deterministic scripted sim (the gate path) — fold + latch the CRC at
// INV_FRAMES, then keep playing the demo; START hands control to the player. PLAY: the pad drives
// the player (D-pad to move, A/B/Y to fire), SELECT returns to attract. noinline bounds a16 pressure.
__attribute__((noinline))
static void game_update(Game *g) {
  controller_poll(&g->pad);
  if (g->mode == MODE_ATTRACT) {
    inv_step(&g->sim);                                       // scripted AI (deterministic)
    if (g->frame < (uint16_t)INV_FRAMES) {
      g->roll = inv_fold(g->roll, &g->sim);
      if (++g->frame == (uint16_t)INV_FRAMES)
        corpus_result = (uint16_t)(g->roll ^ inv_state_crc(&g->sim));   // == host oracle == 0x3DAC
    }
    if (controller_pressed(&g->pad) & JOY_START) { inv_init(&g->sim); g->mode = MODE_PLAY; }
  } else {
    uint16_t h = controller_held(&g->pad);
    int8_t  mv = (h & JOY_LEFT) ? (int8_t)-1 : (h & JOY_RIGHT) ? (int8_t)1 : (int8_t)0;
    uint8_t fr = (controller_pressed(&g->pad) & (JOY_A | JOY_B | JOY_Y)) ? 1u : 0u;
    inv_step2(&g->sim, mv, fr);
    if (controller_pressed(&g->pad) & JOY_SELECT) { inv_init(&g->sim); g->mode = MODE_ATTRACT; }
  }
}

int main(void) {
  static Game g;
  game_init(&g);
  /* Title on BG2 (OBJ chr lives at 0x4000.., the default title regions 0x1000/0x5000 are free).
     The immediate complete teardown restores the OBJ layer masked by title_begin and shuts down
     title HDMA without delaying the deterministic attract gate. */
  static TitleLayer title;
  title_begin16(&g.screen, &title, "SPACE INVADERS", "SPRITES + OAM");
  title_end_now(&g.screen, &title);
  for (;;) {
    game_update(&g);
    render(&g.sim, &g.sprites);
    display_frame(&g.screen);     // wait v-blank, emit OAM, flush DMA, release force-blank on frame 1
  }
}
