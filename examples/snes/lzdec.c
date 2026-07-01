// LZ77 Image-Decompress Reveal — #49 of the compiler stress-test demo battery.
// A compressed picture decoded by an LZ77/LZSS byte-stream decoder that copies back-references from its
// OWN output (examples/65816/lzdec.h — the same lz_decode the host oracle tools/lzdec-sim.c and the
// corpus slice run), then progressively revealed cell-by-cell ("image loading in"). No far pointers ->
// builds default-8-bit AND +mos-a16 AND +mos-xy16, the full 5-way bar.
//
// Codegen under test: a decode state machine copying output-relative back-references (the LZ77 sliding
// window) — self-referential byte pointer arithmetic reading bytes the loop itself just wrote.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/lzdec.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCELL       (CANVAS_W / 8)   // 16
#define REVEAL_PER_FRAME 5u          // cells revealed per frame
#define HOLD_FRAMES 90u              // pause with the full image before re-decoding

static const uint16_t bg3_pal[4] = {
  SNES_RGB(2, 6, 12), SNES_RGB(28, 12, 8), SNES_RGB(28, 24, 8), SNES_RGB(12, 28, 20),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint8_t      cells[LZ_OUTLEN];   // the decoded 16x16 colour-cell image
  uint16_t     reveal;             // cells shown so far
  uint16_t     hold;               // hold counter after full reveal
} App;

volatile uint16_t corpus_result;  // LZ decode fold (read from WRAM by the gate)

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Reveal REVEAL_PER_FRAME more decoded cells this frame. noinline caps a16/xy16 pressure.
__attribute__((noinline))
static void reveal_step(App *a) {
  if (a->reveal >= LZ_OUTLEN) {
    if (++a->hold >= HOLD_FRAMES) {                    // loop: re-decode + restart the reveal
      (void)lz_decode(LZ_STREAM, LZ_SRCLEN, a->cells, LZ_OUTLEN);   // the LZ decoder (hot path)
      a->reveal = 0u; a->hold = 0u;
      for (uint16_t i = 0; i < CANVAS_NTILES * CANVAS_TILEBYTES; i++) a->canvas.chr[i] = 0;
      a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);
    }
    return;
  }
  for (uint8_t k = 0; k < REVEAL_PER_FRAME && a->reveal < LZ_OUTLEN; k++) {
    uint16_t c = a->reveal;
    cell_fill(&a->canvas, (uint8_t)(c & 15u), (uint8_t)(c >> 4), a->cells[c]);
    a->reveal++;
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
  (void)lz_decode(LZ_STREAM, LZ_SRCLEN, a->cells, LZ_OUTLEN);
  a->reveal = 0u; a->hold = 0u;
  text_puts(&a->text, 0, 1, "LZ77 DECOMPRESS REVEAL");
  text_puts(&a->text, 1, 0, "SLIDING WINDOW  BACK-REF COPY");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "LZ77 REVEAL", "BACK-REFERENCE");
  corpus_result = lzdec_gate_crc();             // self-verify the LZ decode == host 0x0100
  title_end(&a.screen, &title, 110);
  for (;;) {
    reveal_step(&a);
    display_frame(&a.screen);
  }
}
