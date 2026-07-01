// Median Denoiser — #57 of the compiler stress-test demo battery.
// Renders the verified, portable 3x3 median filter (examples/65816/medfilt.h — the same header the host
// oracle tools/medfilt-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so it
// builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// A source image is corrupted with salt-and-pepper noise every frame; a sweeping wipe reveals the
// MEDIAN-FILTERED result on one side and the raw noisy input on the other, so you watch the speckle get
// removed. The median-of-9 is a 19-comparator branchless sorting network: each compare-exchange is
// min/max (the select idiom (a<b)?a:b), i.e. G_UMIN/G_UMAX lowered by MOSLegalizerInfo.cpp:272; the
// noise-removed difference uses abs (G_ABS @281). A codegen corner none of the first 56 demos run.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/medfilt.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCELL       16
#define NCOL        4

// BG3 2bpp palette (CGRAM 0..3): dark -> blue -> teal -> white ramp.
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(2, 2, 6), SNES_RGB(6, 12, 26), SNES_RGB(10, 26, 24), SNES_RGB(31, 31, 31),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint16_t     frame;
  uint16_t     rng;
  uint8_t      noisy[NCELL][NCELL];   // regenerated each frame
} App;

volatile uint16_t corpus_result;  // median-filter gate CRC (read from WRAM by the differential gate)

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

static uint8_t clampidx(int8_t v) { return (uint8_t)((v < 0) ? 0 : (v >= NCELL ? NCELL - 1 : v)); }

// Regenerate the noisy buffer, then render: left of the wipe = median-denoised, right = raw noisy.
__attribute__((noinline))
static void frame_step(App *a) {
  for (uint8_t y = 0; y < NCELL; y++)
    for (uint8_t x = 0; x < NCELL; x++)
      a->noisy[y][x] = medfilt_noisy(x, y, &a->rng);

  uint8_t wipe = (uint8_t)(((a->frame >> 1) & 31u));
  if (wipe > NCELL) wipe = (uint8_t)(32u - wipe);            // sweep 0..16..0

  for (uint8_t cy = 0; cy < NCELL; cy++)
    for (uint8_t cx = 0; cx < NCELL; cx++) {
      uint8_t val;
      if (cx < wipe) {                                        // denoised side: 3x3 median
        uint8_t win[9]; uint8_t k = 0;
        for (int8_t dy = -1; dy <= 1; dy++)
          for (int8_t dx = -1; dx <= 1; dx++)
            win[k++] = a->noisy[clampidx((int8_t)cy + dy)][clampidx((int8_t)cx + dx)];
        val = medfilt_median9(win);
      } else {
        val = a->noisy[cy][cx];                               // raw noisy side
      }
      cell_fill(&a->canvas, cx, cy, (uint8_t)((val >> 4) & 3u));
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
  a->frame = 0u;
  a->rng = 0xACE1u;
  text_puts(&a->text, 0, 1, "MEDIAN DENOISER");
  text_puts(&a->text, 1, 0, "3x3 MIN/MAX NETWORK  <- CLEAN | NOISY ->");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "MEDIAN 3x3", "MIN/MAX NETWORK");
  corpus_result = medfilt_gate_crc();           // self-verify the median math == host 0x87FE
  title_end(&a.screen, &title, 110);
  for (;;) {
    a.frame++;
    frame_step(&a);
    display_frame(&a.screen);
  }
}
