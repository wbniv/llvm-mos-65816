// 3-D Grid Voxel Life — #72 of the compiler stress-test demo battery.
// Renders the verified, portable 3-D cellular automaton (examples/65816/grid3d.h — the same header the
// host oracle tools/grid3d-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so it
// builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// A life-like automaton runs in a TRUE 3-D array uint8 grid[6][6][6], accessed as grid[z][y][x] so the
// COMPILER generates the plane/row stride arithmetic (z*36 + y*6 + x, non-power-of-2). The live voxels
// tumble as a rotating cube, depth-shaded. Every prior grid demo was 1-D or hand-indexed y*W+x; this is
// the first that leans on the compiler's multi-dimensional GEP lowering (26 reads per cell).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "sincos.h"
#include "../65816/grid3d.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define VOX_SCALE   3             // voxel spacing (centred coord (2x-5)*SCALE)
#define VOX_DIST    64            // camera distance (> cube radius so z stays > 0)
#define VOX_FOV     150
#define VOX_CX      64
#define VOX_CY      64
#define STEP_EVERY  10            // advance the automaton every N frames

// BG3 2bpp palette (CGRAM 0..3): dark backdrop + a 3-level depth ramp (far -> near = teal -> cyan -> white).
static const uint16_t bg3_pal[4] = {
  SNES_RGB(1, 2, 6), SNES_RGB(10, 20, 24), SNES_RGB(18, 27, 30), SNES_RGB(30, 31, 28),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint8_t      ax, ay;           // tumble angles
  uint8_t      frame;
} App;

volatile uint16_t corpus_result;  // 3-D grid gate CRC (read from WRAM by the differential gate)

#define SIN(a) (SINCOS[(uint8_t)(a)])
#define COS(a) (SINCOS[(uint8_t)((a) + 64u)])

static inline void plot2(BitmapCanvas *cv, int16_t x, int16_t y, uint8_t c) {
  canvas_plot(cv, x, y, c); canvas_plot(cv, (int16_t)(x + 1), y, c);
  canvas_plot(cv, x, (int16_t)(y + 1), c); canvas_plot(cv, (int16_t)(x + 1), (int16_t)(y + 1), c);
}

// Project + draw every live voxel of g3_a as a depth-shaded 2x2 block, rotated by (ax,ay).
__attribute__((noinline))
static void draw_voxels(App *a) {
  int16_t cay = COS(a->ay), say = SIN(a->ay), cax = COS(a->ax), sax = SIN(a->ax);
  for (uint8_t z = 0; z < G3D; z++)
    for (uint8_t y = 0; y < G3D; y++)
      for (uint8_t x = 0; x < G3D; x++) {
        if (!g3_a[z][y][x]) continue;                      // <-- multi-dim read
        int16_t vx = (int16_t)(((int16_t)(2 * x) - (G3D - 1)) * VOX_SCALE);
        int16_t vy = (int16_t)(((int16_t)(2 * y) - (G3D - 1)) * VOX_SCALE);
        int16_t vz = (int16_t)(((int16_t)(2 * z) - (G3D - 1)) * VOX_SCALE);
        int16_t rx = (int16_t)(((int32_t)vx * cay - (int32_t)vz * say) >> 8);   // rotate about Y
        int16_t rz = (int16_t)(((int32_t)vx * say + (int32_t)vz * cay) >> 8);
        int16_t ry = (int16_t)(((int32_t)vy * cax - (int32_t)rz * sax) >> 8);   // rotate about X
        int16_t rz2 = (int16_t)(((int32_t)vy * sax + (int32_t)rz * cax) >> 8);
        int16_t zc = (int16_t)(rz2 + VOX_DIST);
        if (zc < 8) zc = 8;
        int16_t sx = (int16_t)(VOX_CX + (int16_t)(((int32_t)rx * VOX_FOV) / zc));
        int16_t sy = (int16_t)(VOX_CY + (int16_t)(((int32_t)ry * VOX_FOV) / zc));
        uint8_t col = (uint8_t)(zc < VOX_DIST - 4 ? 3u : (zc < VOX_DIST + 6 ? 2u : 1u));  // depth shade
        plot2(&a->canvas, sx, sy, col);
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
  a->ax = 20u; a->ay = 0u; a->frame = 0u;
  g3_seed();
  text_puts(&a->text, 0, 3, "VOXEL LIFE");
  text_puts(&a->text, 1, 0, "3-D GRID Z Y X  MOORE-26 CA");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "VOXEL LIFE", "3-D GRID Z Y X");
  corpus_result = grid3d_gate_crc();            // self-verify the 3-D indexing == host 0xFCDE
  title_end(&a.screen, &title, 110);
  g3_seed();                                    // reset the CA after the gate consumed it
  upq_push_cgram(&a.screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);  // reclaim CGRAM after the title
  for (;;) {
    canvas_clear(&a.canvas);
    draw_voxels(&a);
    a.ax = (uint8_t)(a.ax + 1u);
    a.ay = (uint8_t)(a.ay + 2u);
    if (++a.frame >= STEP_EVERY) {              // advance the automaton
      a.frame = 0u;
      g3_step(g3_a, g3_b);
      for (uint16_t i = 0; i < (uint16_t)(G3D * G3D * G3D); i++) ((uint8_t *)g3_a)[i] = ((uint8_t *)g3_b)[i];
    }
    display_frame(&a.screen);
  }
}
