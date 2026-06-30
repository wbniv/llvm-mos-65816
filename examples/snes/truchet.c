// #29b — the on-SNES PACKED-BITFIELD Truchet / "10 PRINT" maze.
//
// A 16x16 grid of Truchet cells drawn as diagonal segments ('\' or '/') into a 128x128 BitmapCanvas.
// Every cell's state lives in a 16-bit BITFIELD struct (examples/65816/truchet.h): orient:1, style:1,
// hue:3, phase:2, mark:1, energy:4. A decaying "wave" (tr_step) propagates through the grid, and each
// redraw EXTRACTS the per-cell bitfields (orient -> diagonal direction, energy -> colour) to plot it —
// so the bitfield insert/extract codegen (mask/and/ora/shift, no libcalls) runs continuously on screen.
// The classic 10-PRINT maze, but every glyph is a packed-bitfield read.
//
// corpus_result carries the differential gate hash (tr_gate_crc, a far-pointer-free 16x14 fold of the
// EXTRACTED fields after 24 wave steps — so the corpus slice is a full 5-way test) == the host oracle
// tools/truchet-sim == 0xB3E6.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/truchet.h"

#define CANVAS_CHR  0x0000     // BG3 char base (word)
#define CANVAS_MAP  0x4000     // BG3 tilemap base (word)
#define BOX_COL     8          // 16-tile canvas box at cols 8..23 (screen px 64..191)
#define BOX_ROW     6          // rows 6..21 (screen px 48..175)
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define GW 16                  // display grid width  (16 cells x 8 px = 128 = CANVAS_W)
#define GH 16                  // display grid height
#define STEP_EVERY 6           // vblanks between wave steps + canvas redraws (keeps DMA/CPU in pace)

// BG3 2bpp palette: 0 = black, 1/2/3 = the three energy-band diagonal colours (rewritten each frame to
// cycle hues, so the maze flows). Index 1 is also the HUD text colour (kept bright).
static uint16_t pal[4] = {
  SNES_RGB(0, 0, 0), SNES_RGB(31, 31, 31), SNES_RGB(10, 20, 31), SNES_RGB(31, 12, 24),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  Cell         dg[GW * GH];    // the display grid — packed bitfields
  uint8_t      pcyc;
} App;

volatile uint16_t corpus_result;   // bitfield-gate proof channel (tr_gate_crc)

// Five fixed ripple sources (corners + centre), re-lit periodically so the wave never dies.
static const uint8_t SRC[5][2] = { {0,0}, {GW-1,0}, {0,GH-1}, {GW-1,GH-1}, {GW/2,GH/2} };

// Re-light the ripple sources to full energy (an INSERT into each cell's `energy` field). Called every
// few wave steps so expanding colour rings keep flowing through the maze instead of decaying to a freeze.
static void pulse_sources(App *a) {
  for (uint8_t k = 0; k < 5; k++)
    a->dg[(uint16_t)SRC[k][1] * GW + SRC[k][0]].energy = 15u;
}

// Seed the display grid: one tr_make (six bitfield inserts) per cell, then light the ripple sources.
static void seed_grid(App *a) {
  tr_rng = 0xACE1u;
  for (uint16_t i = 0; i < (uint16_t)(GW * GH); i++) a->dg[i] = tr_make(tr_rand());
  pulse_sources(a);
}

// Redraw the whole maze: for each cell EXTRACT orient + energy (bitfield reads) and plot its diagonal in
// the matching energy-band colour. style picks a thin (single) vs crossed (both diagonals) glyph.
static void draw_maze(App *a) {
  canvas_clear(&a->canvas);
  for (uint8_t cy = 0; cy < GH; cy++) {
    for (uint8_t cx = 0; cx < GW; cx++) {
      Cell c = a->dg[(uint16_t)cy * GW + cx];
      uint8_t e = (uint8_t)c.energy;                         // bitfield extract
      uint8_t col = (uint8_t)((e >= 11u) ? 3u : (e >= 5u) ? 2u : 1u);
      int16_t x = (int16_t)((uint16_t)cx * 8), y = (int16_t)((uint16_t)cy * 8);
      if (c.orient) canvas_line(&a->canvas, (int16_t)(x + 7), y, x, (int16_t)(y + 7), col);   // '/'
      else          canvas_line(&a->canvas, x, y, (int16_t)(x + 7), (int16_t)(y + 7), col);   // '\'
      if (c.style)  // crossed glyph: add the opposite diagonal faintly
        canvas_line(&a->canvas, c.orient ? x : (int16_t)(x + 7), y,
                    c.orient ? (int16_t)(x + 7) : x, (int16_t)(y + 7), 1);
    }
  }
}

// Cycle the three diagonal colours through a hue rotation (CGRAM), keeping index 1 bright for HUD text.
static void cycle_palette(App *a) {
  a->pcyc = (uint8_t)(a->pcyc + 1);
  uint8_t r2, g2, b2, r3, g3, b3;
  tr_palette((uint8_t)(a->pcyc >> 4), 11u, &r2, &g2, &b2);
  tr_palette((uint8_t)((a->pcyc >> 4) + 3u), 15u, &r3, &g3, &b3);
  pal[2] = SNES_RGB(r2, g2, b2);
  pal[3] = SNES_RGB(r3, g3, b3);
  upq_push_cgram(&a->screen.q, 0, pal, 0x00, (uint8_t)sizeof pal);
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, pal, 0x00, (uint8_t)sizeof pal);
  seed_grid(a);
  draw_maze(a);
  text_puts(&a->text, 0, 2, "TRUCHET  PACKED BITFIELDS");
  text_puts(&a->text, 1, 1, "6 FIELDS PACKED IN ONE UINT16");
  a->pcyc = 0;
}

int main(void) {
  static App a;
  app_init(&a);

  // Title overlay — play it FULLY first (the bitfield gate is slow, ~4 s; running it between
  // begin/end would freeze the screen on the parked title). Tear it down, THEN fold the proof: the
  // maze is already on screen and just holds a few seconds before the ripples start. == oracle 0xB3E6.
  static TitleLayer title;
  title_begin16(&a.screen, &title, "TRUCHET", "BITFIELDS");
  title_end(&a.screen, &title, 90);
  corpus_result = tr_gate_crc();

  uint8_t t = 0, s = 0;
  for (;;) {
    cycle_palette(&a);
    if (++t >= STEP_EVERY) {
      t = 0;
      if (++s >= 3u) { s = 0; pulse_sources(&a); }   // re-light sources -> continuous expanding rings
      tr_step(a.dg, (uint8_t)GW, (uint8_t)GH);   // wave: bitfield insert/extract across the grid
      draw_maze(&a);                              // redraw: bitfield extract per cell
    }
    display_frame(&a.screen);
  }
}
