// Marching-Squares Iso-Contours — #71 of the compiler stress-test demo battery.
// Renders the verified, portable marching-squares extractor (examples/65816/msquares.h — the same header
// the host oracle tools/msquares-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3),
// so it builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// A scalar field (a sum of moving parabolic metaball domes) is sampled on a grid; each cell's four
// corners are thresholded into a 4-bit CASE index, a 16-entry const table says which edges the contour
// crosses, and each crossing is placed by linear edge interpolation (a divide) — the classic marching
// squares. The iso-contour is drawn as bright outlines around dim-filled blobs that merge and split.
// #45 rendered the metaball FIELD; extracting its iso-contour is a distinct case-table + lerp loop.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/msquares.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define GN          32            // grid cells per side (each CELL px -> 128px canvas)
#define CELL        4
#define GV          (GN + 1)      // value-grid points per side

// BG3 2bpp palette (CGRAM 0..3): dark backdrop, dim blob fill, mid, bright contour outline.
static const uint16_t bg3_pal[4] = {
  SNES_RGB(1, 2, 6), SNES_RGB(6, 10, 22), SNES_RGB(10, 18, 28), SNES_RGB(28, 31, 20),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint16_t     t;
  int16_t      vg[GV * GV];        // precomputed field value grid (int16; field max ~4800 fits)
} App;

volatile uint16_t corpus_result;  // marching-squares gate CRC (read from WRAM by the differential gate)

// Sample the field into vg[], then march each cell: fill fully-inside cells dim + draw the iso-contour
// segments via edge interpolation. noinline caps register pressure.
// Fill the value grid WITHOUT a per-point multiply: for each ball, dx^2 across a row is a quadratic in
// the step index, so it advances by first-differences (`d2 += delta; delta += 2*CELL^2`). Only one small
// multiply per ball per row (the dy^2 term and the initial dx first-difference). Cross-checked against
// ms_field on the host (tools/msquares-sim.c gate) — the gate itself uses ms_field, so this fast path is
// NOT differential-covered; it must match ms_field exactly (the incremental-raster blind-spot lesson).
static void fill_field(App *a, const int16_t *cx, const int16_t *cy) {
  for (uint16_t i = 0; i < (uint16_t)(GV * GV); i++) a->vg[i] = 0;
  for (uint8_t b = 0; b < MS_NB; b++) {
    for (uint8_t gy = 0; gy < GV; gy++) {
      int16_t dy = (int16_t)((int16_t)(gy * CELL) - cy[b]);
      int32_t dy2 = (int32_t)dy * dy;
      int16_t dx0 = (int16_t)(0 - cx[b]);
      int32_t dx2 = (int32_t)dx0 * dx0;
      int32_t delta = 2 * (int32_t)dx0 * CELL + (int32_t)CELL * CELL;   // first difference at gx=0
      const int32_t dd = 2 * (int32_t)CELL * CELL;                      // constant second difference
      int16_t *row = &a->vg[(uint16_t)gy * GV];
      for (uint8_t gx = 0; gx < GV; gx++) {
        int32_t bump = (int32_t)MS_R2 - dx2 - dy2;
        if (bump > 0) row[gx] = (int16_t)(row[gx] + bump);
        dx2 += delta; delta += dd;                                     // step dx^2 with adds only
      }
    }
  }
}

__attribute__((noinline))
static void contour_frame(App *a) {
  int16_t cx[MS_NB], cy[MS_NB];
  ms_centers(a->t, cx, cy);
  fill_field(a, cx, cy);
  for (uint8_t gy = 0; gy < GN; gy++)
    for (uint8_t gx = 0; gx < GN; gx++) {
      int32_t vtl = a->vg[(uint16_t)gy * GV + gx];
      int32_t vtr = a->vg[(uint16_t)gy * GV + gx + 1];
      int32_t vbr = a->vg[(uint16_t)(gy + 1) * GV + gx + 1];
      int32_t vbl = a->vg[(uint16_t)(gy + 1) * GV + gx];
      uint8_t cs = (uint8_t)(((vtl >= MS_ISO) << 3) | ((vtr >= MS_ISO) << 2)
                           | ((vbr >= MS_ISO) << 1) |  (vbl >= MS_ISO));
      if (cs == 15u) {                                   // fully inside -> dim blob fill
        int16_t bx = (int16_t)(gx * CELL), by = (int16_t)(gy * CELL);
        for (int16_t yy = 0; yy < CELL; yy++)
          for (int16_t xx = 0; xx < CELL; xx++)
            canvas_plot(&a->canvas, (int16_t)(bx + xx), (int16_t)(by + yy), 1);
      }
      for (uint8_t s = 0; s < 4u; s += 2u) {             // draw the contour segment(s)
        uint8_t ea = MS_SEG[cs][s], eb = MS_SEG[cs][s + 1u];
        if (ea == 0xFFu) continue;
        int16_t ax, ay, bx2, by2;
        ms_edge_point(ea, gx, gy, vtl, vtr, vbr, vbl, &ax, &ay);
        ms_edge_point(eb, gx, gy, vtl, vtr, vbr, vbl, &bx2, &by2);
        canvas_line(&a->canvas, (int16_t)(ax >> 2), (int16_t)(ay >> 2),
                    (int16_t)(bx2 >> 2), (int16_t)(by2 >> 2), 3);   // >>2: sub-cell(16) -> px(4)
      }
    }
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->t = 0u;
  text_puts(&a->text, 0, 1, "MARCHING SQUARES");
  text_puts(&a->text, 1, 0, "16-CASE EDGE LUT + EDGE INTERP");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "CONTOURS", "MARCHING SQUARES");
  corpus_result = msquares_gate_crc();          // self-verify the contour math == host 0x33EB
  title_end(&a.screen, &title, 110);
  upq_push_cgram(&a.screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);  // reclaim CGRAM after the title
  for (;;) {
    canvas_clear(&a.canvas);
    contour_frame(&a);
    a.t += 1u;                                  // drift the field
    display_frame(&a.screen);
  }
}
