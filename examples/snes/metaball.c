// Union Type-Pun Metaballs (Fast Inverse Sqrt) — #45 of the compiler stress-test demo battery.
// A field of merging blobs whose 1/dist falloff is the Quake fast-inverse-sqrt bit hack
// (examples/65816/metaball.h — the same q_rsqrt the host oracle tools/metaball-sim.c and the corpus
// slice run), which reads a float's storage AS an integer via a union, mangles the bits with the magic
// constant 0x5f3759df, and reads it back AS a float. No far pointers -> builds default-8-bit AND
// +mos-a16 AND +mos-xy16, so it earns the full 5-way differential bar.
//
// Codegen under test: union type-punning (float<->uint32 aliased reinterpret) + single-precision
// soft-float. The field is computed progressively (a band of cell-rows per frame) because soft-float
// is expensive; the gate CRC runs once at startup behind the title card.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/metaball.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define CELL        8
#define NCELL       (CANVAS_W / CELL)     // 16
#define NCOL        4
#define BAND        4                     // cell-rows recomputed per frame

// BG3 2bpp palette (CGRAM 0..3): background -> gooey teal -> green -> hot core.
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(1, 2, 6), SNES_RGB(7, 20, 27), SNES_RGB(14, 30, 18), SNES_RGB(31, 31, 22),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  int16_t      bx[MB_NB], by[MB_NB];      // blob centres (px)
  int16_t      vx[MB_NB], vy[MB_NB];      // blob velocities
  uint8_t      row;                        // progressive cell-row cursor
} App;

volatile uint16_t corpus_result;  // fast-inverse-sqrt bit-pun fold (read from WRAM by the gate)

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Map metaball field intensity (sum of 1/dist) to a 2bpp colour (0..3).
static uint8_t mb_color(float acc) {
  if (acc >= 2.6f) return 3u;   // hot core
  if (acc >= 1.5f) return 2u;
  if (acc >= 0.75f) return 1u;  // isosurface halo
  return 0u;
}

// Advance a band of cell-rows this frame; when the cursor wraps, step the blobs. noinline caps pressure.
__attribute__((noinline))
static void field_step(App *a) {
  for (uint8_t b = 0; b < BAND; b++) {
    uint8_t cy = (uint8_t)(a->row + b);
    if (cy >= NCELL) break;
    int16_t py = (int16_t)(cy * CELL + CELL / 2);
    for (uint8_t cx = 0; cx < NCELL; cx++) {
      int16_t px = (int16_t)(cx * CELL + CELL / 2);
      float acc = mb_field(px, py, a->bx, a->by);   // 4x q_rsqrt (union type-pun inside)
      cell_fill(&a->canvas, cx, cy, mb_color(acc));
    }
  }
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);
  a->row = (uint8_t)(a->row + BAND);
  if (a->row >= NCELL) {
    a->row = 0;
    for (uint8_t k = 0; k < MB_NB; k++) {           // bounce the blobs
      a->bx[k] = (int16_t)(a->bx[k] + a->vx[k]);
      a->by[k] = (int16_t)(a->by[k] + a->vy[k]);
      if (a->bx[k] < 8 || a->bx[k] > 119) a->vx[k] = (int16_t)(-a->vx[k]);
      if (a->by[k] < 8 || a->by[k] > 119) a->vy[k] = (int16_t)(-a->vy[k]);
    }
  }
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  static const int16_t ix[MB_NB] = { 40, 88, 56, 96 };
  static const int16_t iy[MB_NB] = { 48, 40, 92, 84 };
  static const int16_t ivx[MB_NB] = { 3, -2, 2, -3 };
  static const int16_t ivy[MB_NB] = { 2, 3, -3, 2 };
  for (uint8_t k = 0; k < MB_NB; k++) {
    a->bx[k] = ix[k]; a->by[k] = iy[k]; a->vx[k] = ivx[k]; a->vy[k] = ivy[k];
  }
  a->row = 0u;
  text_puts(&a->text, 0, 1, "TYPE-PUN METABALLS");
  text_puts(&a->text, 1, 0, "FAST INV SQRT  UNION FLOAT<->U32");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "METABALLS", "FAST INV SQRT");
  corpus_result = metaball_gate_crc();          // self-verify the type-pun rsqrt == host 0xAEBE
  title_end(&a.screen, &title, 110);
  for (;;) {
    field_step(&a);
    display_frame(&a.screen);
  }
}
