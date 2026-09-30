// Floyd-Steinberg Error-Diffusion Dither — #70 of the compiler stress-test demo battery.
// Renders the verified, portable FS dither (examples/65816/dither.h — the same header the host oracle
// tools/dither-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so it builds
// default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// A smooth drifting gradient is reduced to four grey levels by Floyd-Steinberg error diffusion: each
// pixel's SIGNED quantisation residual is spread to its down-right neighbours (7/16, 3/16, 5/16, 1/16)
// so the next pixels see the accumulated error — the smooth scene resolves into shimmering dither, the
// error visibly flowing. A codegen corner none of the first 69 demos run: forward-carried signed error
// diffusion across a two-row error buffer. Distinct from #7's decay+PRNG fire.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/dither.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define DW          48            // dither grid (each pixel -> a 2x2 canvas block = 96x96, centred)
#define DH          48
#define DBLIT_OFF   16            // centre the 96x96 image in the 128x128 canvas

// BG3 2bpp palette (CGRAM 0..3): a monochrome grey ramp — the classic error-diffusion "camera" look.
static const uint16_t bg3_pal[4] = {
  SNES_RGB(2, 2, 3), SNES_RGB(11, 11, 13), SNES_RGB(21, 21, 23), SNES_RGB(31, 31, 31),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint16_t     t;
  uint8_t      out[DW * DH];       // dithered band indices (0..3)
} App;

volatile uint16_t corpus_result;  // dither gate CRC (read from WRAM by the differential gate)

// Dither one animated frame and blit it as 2x2 blocks into the canvas. noinline caps register pressure.
__attribute__((noinline))
static void dither_frame(App *a) {
  ds_dither(DW, DH, a->t, a->out);
  for (uint8_t y = 0; y < DH; y++)
    for (uint8_t x = 0; x < DW; x++) {
      uint8_t c = a->out[(uint16_t)y * DW + x];
      int16_t px = (int16_t)(((uint16_t)x << 1) + DBLIT_OFF), py = (int16_t)(((uint16_t)y << 1) + DBLIT_OFF);
      canvas_plot(&a->canvas, px,           py,           c);   // 2x2 block
      canvas_plot(&a->canvas, (int16_t)(px + 1), py,           c);
      canvas_plot(&a->canvas, px,           (int16_t)(py + 1), c);
      canvas_plot(&a->canvas, (int16_t)(px + 1), (int16_t)(py + 1), c);
    }
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);   // whole canvas dirty
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->t = 0u;
  text_puts(&a->text, 0, 1, "FLOYD-STEINBERG");
  text_puts(&a->text, 1, 0, "ERROR DIFFUSION  7-3-5-1 / 16");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "DITHER", "ERROR DIFFUSION");
  corpus_result = dither_gate_crc();            // self-verify the FS math == host 0x80C4
  title_end(&a.screen, &title, 110);
  upq_push_cgram(&a.screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);  // reclaim CGRAM after the title
  for (;;) {
    dither_frame(&a);
    a.t += 3u;                                  // drift the source scene
    display_frame(&a.screen);
  }
}
