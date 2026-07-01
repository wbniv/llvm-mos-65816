// Convex Hull Rubber-Band — #65 of the compiler stress-test demo battery.
// Renders the verified, portable gift-wrap convex hull (examples/65816/hull.h — the same header the host
// oracle tools/hull-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so it builds
// default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// A cloud of points drifts and bounces; each frame the convex hull is recomputed by gift-wrapping — a
// Jarvis march that picks vertices purely from the SIGN of the signed 2-D cross product (the orientation
// predicate) — and drawn as a taut rubber band around the cloud. A codegen corner none of the first 64
// demos run: a computational-geometry orientation test (int32 cross product).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/hull.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define LO          8
#define HI          118

// BG3 2bpp palette (CGRAM 0..3): bg / points (cyan) / hull edges (amber) / hull vertices (white).
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(2, 3, 9), SNES_RGB(6, 26, 30), SNES_RGB(31, 22, 6), SNES_RGB(31, 31, 31),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  HlPt         pt[HL_N];
  int8_t       vx[HL_N], vy[HL_N];
  uint8_t      hull[HL_N];
  uint16_t     rng;
} App;

volatile uint16_t corpus_result;  // convex-hull gate CRC (read from WRAM by the differential gate)

static uint16_t rng16(App *a) {
  uint16_t x = a->rng; x ^= (uint16_t)(x << 7); x ^= (uint16_t)(x >> 9); x ^= (uint16_t)(x << 8);
  a->rng = x; return x;
}

// Move + bounce the points, recompute + draw the hull. noinline caps register pressure.
__attribute__((noinline))
static void step(App *a) {
  for (uint8_t i = 0; i < HL_N; i++) {
    int16_t nx = (int16_t)(a->pt[i].x + a->vx[i]);
    int16_t ny = (int16_t)(a->pt[i].y + a->vy[i]);
    if (nx < LO) { nx = LO; a->vx[i] = (int8_t)(-a->vx[i]); }
    if (nx > HI) { nx = HI; a->vx[i] = (int8_t)(-a->vx[i]); }
    if (ny < LO) { ny = LO; a->vy[i] = (int8_t)(-a->vy[i]); }
    if (ny > HI) { ny = HI; a->vy[i] = (int8_t)(-a->vy[i]); }
    a->pt[i].x = nx; a->pt[i].y = ny;
  }
  uint8_t hc = hl_giftwrap(a->pt, HL_N, a->hull);            // int32 cross-product orientation tests

  canvas_clear(&a->canvas);
  for (uint8_t e = 0; e < hc; e++) {                          // hull edges (rubber band, amber)
    HlPt p0 = a->pt[a->hull[e]], p1 = a->pt[a->hull[(uint8_t)((e + 1u) % hc)]];
    canvas_line(&a->canvas, p0.x, p0.y, p1.x, p1.y, 2u);
  }
  for (uint8_t i = 0; i < HL_N; i++) {                        // the points (cyan crosses)
    int16_t x = a->pt[i].x, y = a->pt[i].y;
    canvas_plot(&a->canvas, x, y, 1u);
    canvas_plot(&a->canvas, (int16_t)(x + 1), y, 1u);
    canvas_plot(&a->canvas, (int16_t)(x - 1), y, 1u);
    canvas_plot(&a->canvas, x, (int16_t)(y + 1), 1u);
    canvas_plot(&a->canvas, x, (int16_t)(y - 1), 1u);
  }
  for (uint8_t e = 0; e < hc; e++) {                          // hull vertices (white)
    HlPt v = a->pt[a->hull[e]];
    canvas_plot(&a->canvas, v.x, v.y, 3u);
    canvas_plot(&a->canvas, (int16_t)(v.x + 1), v.y, 3u);
    canvas_plot(&a->canvas, v.x, (int16_t)(v.y + 1), 3u);
  }
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->rng = 0x1357u;
  for (uint8_t i = 0; i < HL_N; i++) {
    a->pt[i].x = (int16_t)(LO + (rng16(a) % (HI - LO)));
    a->pt[i].y = (int16_t)(LO + (rng16(a) % (HI - LO)));
    a->vx[i] = (int8_t)((rng16(a) & 3u) - 1);
    a->vy[i] = (int8_t)((rng16(a) & 3u) - 1);
    if (a->vx[i] == 0 && a->vy[i] == 0) a->vx[i] = 1;
  }
  text_puts(&a->text, 0, 1, "CONVEX HULL");
  text_puts(&a->text, 1, 0, "GIFT-WRAP  CROSS-PRODUCT ORIENTATION");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "CONVEX HULL", "GIFT-WRAP  CROSS");
  corpus_result = hull_gate_crc();              // self-verify the hull math == host 0xA58C
  title_end(&a.screen, &title, 110);
  for (;;) {
    step(&a);
    display_frame(&a.screen);
  }
}
