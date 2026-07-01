// Gouraud Triangle Tumbler — #69 of the compiler stress-test demo battery.
// Renders the verified, portable barycentric edge-function rasteriser (examples/65816/gouraud.h — the
// same header the host oracle tools/gouraud-sim.c and the corpus slice run) into a NEAR 2bpp bitmap
// canvas (BG3), so it builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> full 5-way).
//
// A spinning equilateral triangle whose three vertices carry three brightnesses is FILLED and
// colour-interpolated per pixel: three signed cross-product edge functions decide inside/outside, and
// their values are the barycentric weights that shade the face across four bands. #16 (wireframe) drew
// Bresenham *lines* only — never a filled, interpolated face. The gate (corpus_result) exercises the
// per-pixel barycentric DIVIDE; the on-screen fill steps the same edge functions incrementally for
// speed (both share gs_edge — the int32 cross product).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/gouraud.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define TRI_CX      64
#define TRI_CY      64
#define TRI_R       32

// BG3 2bpp palette (CGRAM 0..3): indigo backdrop, then a crimson -> orange -> gold face ramp.
static const uint16_t bg3_pal[4] = {
  SNES_RGB(2, 2, 7), SNES_RGB(21, 4, 11), SNES_RGB(30, 16, 4), SNES_RGB(31, 30, 18),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint8_t      rot;
} App;

volatile uint16_t corpus_result;  // Gouraud gate CRC (read from WRAM by the differential gate)

// Rasterise triangle (v0,v1,v2) into the canvas by INCREMENTAL edge functions: compute the three edge
// values + interpolation numerator at the bbox origin (gs_edge -> __mulsi3), then step them per pixel
// with adds only. Inside = all three edges share the winding sign; the band is the numerator compared to
// area thresholds (85/170 of full-scale) — the same barycentric split the gate does with a divide, here
// as a compare so the on-screen fill stays fast. noinline caps register pressure.
// The hot per-pixel steppers (e0,e1,e2 + their dx/dy) are int16: for a radius-<=40 triangle the edge
// function stays well inside +-32767, so the bbox sweep is native 16-bit adds/compares (fast). Only a
// COVERED pixel promotes to the int32 barycentric numerator + band split — the same shading the gate
// computes with a divide. (The int32 gate is the differential arbiter; this fill is the witness.)
__attribute__((noinline))
static void draw_tri(BitmapCanvas *cv, const GVert *vin) {
  GVert v0 = vin[0], v1 = vin[1], v2 = vin[2];
  int32_t area = gs_edge(v0.x, v0.y, v1.x, v1.y, v2.x, v2.y);
  if (area == 0) return;
  if (area < 0) { GVert t = v1; v1 = v2; v2 = t; area = -area; }   // force positive winding

  int16_t minx = v0.x, maxx = v0.x, miny = v0.y, maxy = v0.y;
  if (v1.x < minx) minx = v1.x; if (v1.x > maxx) maxx = v1.x;
  if (v2.x < minx) minx = v2.x; if (v2.x > maxx) maxx = v2.x;
  if (v1.y < miny) miny = v1.y; if (v1.y > maxy) maxy = v1.y;
  if (v2.y < miny) miny = v2.y; if (v2.y > maxy) maxy = v2.y;
  if (minx < 0) minx = 0; if (maxx > CANVAS_W - 1) maxx = CANVAS_W - 1;
  if (miny < 0) miny = 0; if (maxy > CANVAS_H - 1) maxy = CANVAS_H - 1;

  int16_t A0dx = (int16_t)(v1.y - v2.y), A0dy = (int16_t)(v2.x - v1.x);   // dE/dx = a.y-b.y, dE/dy = b.x-a.x
  int16_t A1dx = (int16_t)(v2.y - v0.y), A1dy = (int16_t)(v0.x - v2.x);
  int16_t A2dx = (int16_t)(v0.y - v1.y), A2dy = (int16_t)(v1.x - v0.x);
  int16_t e0r = (int16_t)gs_edge(v1.x, v1.y, v2.x, v2.y, minx, miny);   // edge opposite v0 at bbox origin
  int16_t e1r = (int16_t)gs_edge(v2.x, v2.y, v0.x, v0.y, minx, miny);
  int16_t e2r = (int16_t)gs_edge(v0.x, v0.y, v1.x, v1.y, minx, miny);
  // The barycentric numerator is linear in (px,py), so step it in int32 with adds — no per-pixel mul.
  int32_t ndx = (int32_t)A0dx * v0.a + (int32_t)A1dx * v1.a + (int32_t)A2dx * v2.a;
  int32_t ndy = (int32_t)A0dy * v0.a + (int32_t)A1dy * v1.a + (int32_t)A2dy * v2.a;
  int32_t nrow = (int32_t)e0r * v0.a + (int32_t)e1r * v1.a + (int32_t)e2r * v2.a;
  int32_t th1 = area * 85, th2 = area * 170;

  for (int16_t py = miny; py <= maxy; py++) {
    int16_t e0 = e0r, e1 = e1r, e2 = e2r;
    int32_t num = nrow;
    for (int16_t px = minx; px <= maxx; px++) {
      if (e0 >= 0 && e1 >= 0 && e2 >= 0) {                            // inside (positive winding)
        uint8_t col = (uint8_t)(num < th1 ? 1u : (num < th2 ? 2u : 3u));
        canvas_plot(cv, px, py, col);
      }
      e0 = (int16_t)(e0 + A0dx); e1 = (int16_t)(e1 + A1dx); e2 = (int16_t)(e2 + A2dx);
      num += ndx;
    }
    e0r = (int16_t)(e0r + A0dy); e1r = (int16_t)(e1r + A1dy); e2r = (int16_t)(e2r + A2dy);
    nrow += ndy;
  }
  cv->lo = 0; cv->hi = (uint16_t)(CANVAS_NTILES - 1);   // whole canvas dirty this frame
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->rot = 0u;
  text_puts(&a->text, 0, 1, "GOURAUD TRIANGLE");
  text_puts(&a->text, 1, 0, "3 EDGE FNS + BARYCENTRIC INTERP");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "GOURAUD", "EDGE-FUNCTION FILL");
  corpus_result = gouraud_gate_crc();           // self-verify the raster math == host 0x209C
  title_end(&a.screen, &title, 110);
  upq_push_cgram(&a.screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);  // reclaim CGRAM after the title
  for (;;) {
    GVert v[3];
    gs_make_tri(a.rot, TRI_CX, TRI_CY, TRI_R, v);
    canvas_clear(&a.canvas);
    draw_tri(&a.canvas, v);
    a.rot = (uint8_t)(a.rot + 1u);
    display_frame(&a.screen);
  }
}
