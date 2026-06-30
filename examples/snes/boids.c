// #26 — Reynolds BOIDS flock on the SNES, rendered as hardware sprites.
//
// The flocking math (examples/65816/boids.h) is built on a `vec2 { int16_t x, y; }` VALUE type: the
// steering kernel — v2_add/v2_sub/v2_scale/v2_clampbox plus the three rules separation/alignment/
// cohesion — TAKES and RETURNS `vec2` BY VALUE, and the composition chains those returns. On the
// 16-bit 65816 a 4-byte aggregate return forces the compiler's aggregate-return ABI (small-struct
// register pair vs. an sret hidden pointer), exercised O(N^2) times per frame. That ABI path is
// otherwise UNTESTED by the battery. The vec functions are noinline so the calls survive -Os.
//
// The picture IS the proof: a correct ABI yields a coherent flock — dots that clump, align into
// streams (each boid coloured by its heading octant via one of 8 OBJ palettes, so aligned birds share
// a hue) and avoid collisions. A returned-struct miscompile would scatter the flock into noise or
// freeze the gate CRC. No far pointers — the flock lives in bank-0 WRAM — so the corpus slice
// (boids_sim.c) is a full 5-way differential: corpus_result = boids_gate_crc() == the host oracle
// (tools/boids-sim.c) == 0xA8AB, bit-for-bit, across default / +mos-a16 / +mos-xy16.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/sprite_set.h"
#include "snesgfx/title_layer.h"
#include "../65816/boids.h"

#define NBOIDS    32            // flock size (<= 128 OAM sprites)
#define SPR_CHR   0x4000        // sprite tile VRAM base (word) — OBSEL namebase 2 (as in invaders.c)
#define BOID_TILE 0             // the one boid dot tile lives at OBJ tile 0
#define SPR_PRIO  0x20          // OAM attr: priority 2 (palette group + tile#8 OR'd in per boid)

volatile uint16_t corpus_result;   // differential proof channel (read from WRAM by the gate)

// 8x8 boid sprite: a solid diamond in palette index 1 (the heading hue) — a bright single-colour dot,
// so aligned birds read as same-colour streams. Index 2 (white highlight) sits at the centre 2x2.
static const uint8_t BOID_PIX[64] = {
  0,0,0,1,1,0,0,0,
  0,0,1,1,1,1,0,0,
  0,1,1,1,1,1,1,0,
  1,1,1,2,2,1,1,1,
  1,1,1,2,2,1,1,1,
  0,1,1,1,1,1,1,0,
  0,0,1,1,1,1,0,0,
  0,0,0,1,1,0,0,0,
};

// 8 heading hues (BGR555 5-bit channels) — the rainbow that colours the flock by direction of travel.
static const uint8_t HUE5[8][3] = {
  {31, 0, 0}, {31,16, 0}, {31,31, 0}, { 0,31, 0},
  { 0,31,31}, { 0, 8,31}, {20, 0,31}, {31, 0,24},
};

// Encode an 8x8 palette-index map into a 4bpp SNES tile (16 words: planes 0&1 then planes 2&3).
static void make_tile(uint16_t *out, const uint8_t *px) {
  for (uint8_t r = 0; r < 8; r++) {
    uint8_t p0 = 0, p1 = 0, p2 = 0, p3 = 0;
    for (uint8_t c = 0; c < 8; c++) {
      uint8_t v = px[r * 8 + c], bit = (uint8_t)(0x80u >> c);
      if (v & 1) p0 |= bit; if (v & 2) p1 |= bit;
      if (v & 4) p2 |= bit; if (v & 8) p3 |= bit;
    }
    out[r]     = (uint16_t)(p0 | ((uint16_t)p1 << 8));
    out[r + 8] = (uint16_t)(p2 | ((uint16_t)p3 << 8));
  }
}

typedef struct {
  Display   screen;
  SpriteSet sprites;
  Boid      flock[NBOIDS];
  uint16_t  tile[16];           // the encoded boid tile (DMA source — must outlive the deferred flush)
  uint16_t  objpal[8][3];       // 8 heading palettes (DMA source — likewise persistent, not stack-local)
} App;

static void app_init(App *a) {
  display_init(&a->screen);
  sprite_set_init(&a->sprites, /*size_pair*/ 0, SPR_CHR);
  display_add(&a->screen, (Drawable *)&a->sprites);

  // Encode + queue the one boid tile into OBJ chr VRAM (flushes on the first display_frame).
  make_tile(a->tile, BOID_PIX);
  upq_push_vram(&a->screen.q, SPR_CHR, a->tile, 0x00, sizeof a->tile, VMAIN_INC_HIGH_1);

  // 8 OBJ palette groups: entry 0 transparent, entry 1 = hue, entry 2 = white highlight. The source
  // (a->objpal) is a persistent App member — upq_push_cgram records the pointer and DMAs it on the
  // first display_frame, AFTER app_init returns, so a stack-local would be read after it died.
  for (uint8_t g = 0; g < 8; g++) {
    a->objpal[g][0] = 0;
    a->objpal[g][1] = SNES_RGB(HUE5[g][0], HUE5[g][1], HUE5[g][2]);
    a->objpal[g][2] = SNES_RGB(31, 31, 31);
    sprite_set_palette(&a->sprites, &a->screen.q, g, a->objpal[g], sizeof a->objpal[g]);
  }

  // Seed the VISUAL flock as a tight central cluster (gate flock is separate, so this is free to
  // differ): boids_init scatters across the whole world and needs ~150 heavy steps to coalesce, which
  // on-target (slow O(N^2) steps) looks like a half-formed cloud for a long time. Starting clustered
  // reads as a cohesive swirling flock from the first frame.
  uint16_t s = 0x0B0D;
  for (uint8_t i = 0; i < NBOIDS; i++) {
    s = boid_xs16(s); a->flock[i].pos.x = (int16_t)(BOID_WORLD_W / 2 + (int16_t)((s & 1023) - 512));
    s = boid_xs16(s); a->flock[i].pos.y = (int16_t)(BOID_WORLD_H / 2 + (int16_t)((s & 1023) - 512));
    s = boid_xs16(s); a->flock[i].vel.x = (int16_t)((int16_t)(s & 63) - 32);
    s = boid_xs16(s); a->flock[i].vel.y = (int16_t)((int16_t)(s & 63) - 32);
  }
}

// One frame: advance the flock one step then draw every boid as a sprite coloured by heading octant.
// noinline bounds +mos-a16 register pressure (handoff §4) — the O(N^2) steering chain holds many live
// 16-bit values, and inlining the whole snesgfx + steering chain into main() overruns the allocator.
__attribute__((noinline))
static void app_frame(App *a) {
  boids_step(a->flock, NBOIDS);
  for (uint8_t i = 0; i < NBOIDS; i++) {
    int16_t x = (int16_t)(a->flock[i].pos.x >> 4);    // Q12.4 -> px
    uint8_t y = (uint8_t)(a->flock[i].pos.y >> 4);
    uint8_t oct = boid_heading_oct(a->flock[i].vel);
    uint8_t attr = (uint8_t)(SPR_PRIO | (uint8_t)(oct << 1));   // palette group = heading octant
    sprite_set_put(&a->sprites, i, x, y, BOID_TILE, attr, 0);
  }
}

int main(void) {
  static App a;
  app_init(&a);

  // Cinematic title card (BG2). corpus_result is computed once behind the card — the gate flock is
  // independent of the visual flock, so the proof is stable long before any snapshot deadline.
  static TitleLayer title;
  title_begin16(&a.screen, &title, "BOIDS", "STRUCT-BY-VALUE");
  corpus_result = boids_gate_crc();          // == host oracle == 0xA8AB
  title_end(&a.screen, &title, 110);
  // Snap to full brightness. title_end leaves the demo fading IN one step per display_frame, but each
  // app_frame spans several PPU frames (the heavy O(N^2) steering), so that ramp would keep the flock
  // dim for seconds. Snap bright=btgt=ON so it renders at full brightness from the first frame.
  a.screen.bright = INIDISP_ON;
  a.screen.btgt   = INIDISP_ON;

  for (;;) {
    app_frame(&a);
    display_frame(&a.screen);                // wait v-blank, emit OAM, flush DMA
  }
}
