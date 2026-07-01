// Cosmic Zoom Ruler — #59 of the compiler stress-test demo battery.
// Renders the verified, portable powers-of-ten ruler (examples/65816/cosmzoom.h — the same header the
// host oracle tools/cosmzoom-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so it
// builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// A uint64 "scale" grows exponentially (nanometres to the cosmos); it is converted to float to place it
// on a LOGARITHMIC ruler (so exponential growth reads as a linear sweep), and back to uint64 for the
// read-out. The conversions are __floatundisf / __fixunssfdi / __floatdisf / __fixsfdi — 64-bit integer
// <-> float, a codegen corner none of the first 58 demos run (#21/#33 converted only 32-bit ints).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/cosmzoom.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCELL       16
#define NCOL        4
#define BAR_TOP     5              // the zoom bar occupies cell-rows BAR_TOP..BAR_TOP+BAR_H-1
#define BAR_H       6
#define POS_MAX     (18u * 256u)   // cosm_pos range (18 decades * 256)

// BG3 2bpp palette (CGRAM 0..3): empty / near-scale (blue) / filled (gold) / cursor (white).
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(2, 3, 9), SNES_RGB(6, 14, 28), SNES_RGB(31, 22, 6), SNES_RGB(31, 31, 31),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint16_t     frame;
  uint64_t     scale;
  uint8_t      dec_shown;
} App;

volatile uint16_t corpus_result;  // cosmic-zoom gate CRC (read from WRAM by the differential gate)

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Draw the log-scale zoom bar: fill fraction = cosm_pos(scale)/POS_MAX across the 16-cell width.
__attribute__((noinline))
static void draw_bar(App *a) {
  uint16_t pos = cosm_pos(a->scale);                       // 0..POS_MAX  (the 64-bit->float conversion)
  uint16_t cursor = (uint16_t)((uint32_t)pos * NCELL / POS_MAX);   // 0..16 cell column
  for (uint8_t cy = BAR_TOP; cy < (uint8_t)(BAR_TOP + BAR_H); cy++)
    for (uint8_t cx = 0; cx < NCELL; cx++) {
      uint8_t col;
      if (cx == cursor)      col = 3u;                      // white cursor
      else if (cx < cursor)  col = 2u;                      // gold filled
      else                   col = 1u;                      // blue empty track
      cell_fill(&a->canvas, cx, cy, col);
    }
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);
}

// HUD: current decade as "E<dd>" (10^dd), updated only on change.
static void draw_hud(App *a) {
  uint8_t d = cosm_decade(a->scale);
  if (d == a->dec_shown) return;
  a->dec_shown = d;
  char line[21];
  static const char pfx[] = "SCALE = 10 ^ ";
  uint8_t i = 0;
  for (; pfx[i]; i++) line[i] = pfx[i];
  line[i++] = (char)('0' + (d / 10u));
  line[i++] = (char)('0' + (d % 10u));
  while (i < 20u) line[i++] = ' ';
  line[20] = '\0';
  text_puts(&a->text, 1, 0, line);
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->frame = 0u;
  a->scale = 1u;
  a->dec_shown = 0xFFu;
  text_puts(&a->text, 0, 1, "COSMIC ZOOM RULER");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "COSMIC ZOOM", "64-BIT / FLOAT");
  corpus_result = cosm_gate_crc();              // self-verify the conversion math == host 0x502F
  title_end(&a.screen, &title, 110);
  for (;;) {
    a.frame++;
    if ((a.frame & 3u) == 0u) {                 // grow the scale every 4th frame
      a.scale = a.scale + (a.scale >> 2) + 1u;   // ~*1.25
      if (a.scale >= COSM_POW10[18]) a.scale = 1u;
    }
    draw_hud(&a);
    draw_bar(&a);
    display_frame(&a.screen);
  }
}
