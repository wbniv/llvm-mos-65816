// Radix / Counting Sort — #64 of the compiler stress-test demo battery.
// Renders the verified, portable LSD radix sort (examples/65816/radix.h — the same header the host oracle
// tools/radix-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so it builds
// default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// A row of 16 bars is sorted base-16 one nibble at a time: each pass histograms the digit, prefix-sums
// the counts into offsets, and stable-scatters the elements — a NON-COMPARISON sort (zero compares).
// The demo shows the array after each pass: raw -> after the low-nibble pass -> fully sorted, then
// reshuffles. #17 (sort-race) animated comparison sorts; a compare-free scatter sort is a different loop
// nest none of the first 63 demos run.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/radix.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define HOLD        50            // frames each state is held

// BG3 2bpp palette (CGRAM 0..3): a value ramp (low->high) blue / teal / gold / white.
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(6, 10, 28), SNES_RGB(6, 26, 24), SNES_RGB(31, 22, 6), SNES_RGB(31, 31, 31),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint8_t      arr[RX_N];
  uint8_t      buf[RX_N];
  uint16_t     rng;
  uint8_t      phase;        // 0=raw, 1=after low-nibble pass, 2=sorted
  uint16_t     timer;
} App;

volatile uint16_t corpus_result;  // radix gate CRC (read from WRAM by the differential gate)

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Draw the 16 bars: column i, height = arr[i]>>4 (0..16 rows), colour = arr[i]>>6 (value band).
__attribute__((noinline))
static void draw_bars(App *a) {
  for (uint8_t cx = 0; cx < RX_N; cx++) {
    uint8_t v = a->arr[cx];
    uint8_t h = (uint8_t)(v >> 4);                 // 0..15
    uint8_t col = (uint8_t)((v >> 6) & 3u);        // value band 0..3
    for (uint8_t cy = 0; cy < 16u; cy++)
      cell_fill(&a->canvas, cx, cy, (cy >= (uint8_t)(16u - h)) ? col : 0u);
  }
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);
}

static void reshuffle(App *a) {
  for (uint16_t i = 0; i < RX_N; i++) {
    a->rng ^= (uint16_t)(a->rng << 7); a->rng ^= (uint16_t)(a->rng >> 9); a->rng ^= (uint16_t)(a->rng << 8);
    a->arr[i] = (uint8_t)(a->rng & 0xFFu);
  }
  a->phase = 0u; a->timer = 0u;
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->rng = 0xBEEFu;
  reshuffle(a);
  text_puts(&a->text, 0, 2, "RADIX SORT");
  text_puts(&a->text, 1, 0, "COUNT + PREFIX + SCATTER (NO COMPARE)");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "RADIX SORT", "COUNTING / SCATTER");
  corpus_result = radix_gate_crc();             // self-verify the sort math == host 0x123E
  title_end(&a.screen, &title, 110);
  draw_bars(&a);
  for (;;) {
    if (++a.timer >= HOLD) {
      a.timer = 0u;
      if (a.phase == 0u)      { rx_pass_into(a.arr, a.buf, RX_N, 0u); for (uint16_t i=0;i<RX_N;i++) a.arr[i]=a.buf[i]; a.phase = 1u; }
      else if (a.phase == 1u) { rx_pass_into(a.arr, a.buf, RX_N, 4u); for (uint16_t i=0;i<RX_N;i++) a.arr[i]=a.buf[i]; a.phase = 2u; }
      else                    { reshuffle(&a); }
      draw_bars(&a);
    }
    display_frame(&a.screen);
  }
}
