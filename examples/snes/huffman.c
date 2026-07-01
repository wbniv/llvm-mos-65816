// Huffman Decode Reveal — #67 of the compiler stress-test demo battery.
// Renders the verified, portable Huffman decoder (examples/65816/huffman.h — the same header the host
// oracle tools/huffman-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so it builds
// default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// A 16x16 image is Huffman-encoded into a bitstream, then decoded bit by bit — pull one bit (MSB-first),
// descend the pointer-linked Huffman tree (left on 0, right on 1), emit a symbol at each leaf — and the
// pixels are revealed a few per frame, the classic "image loading in". A codegen corner none of the first
// 66 demos run: a bit-granular stream reader + tree descent (distinct from #49's byte-oriented LZ).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/huffman.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define PIX_FRAME   3             // pixels decoded/revealed per frame

// BG3 2bpp palette (CGRAM 0..3): the four Huffman symbols -> a diamond ramp.
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(3, 4, 12), SNES_RGB(28, 8, 22), SNES_RGB(8, 26, 26), SNES_RGB(31, 30, 10),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint8_t      stream[HF_STREAM_BYTES];
  uint16_t     bit;              // decode bit cursor
  uint16_t     pixel;            // next pixel index to reveal
  uint16_t     holdt;
} App;

volatile uint16_t corpus_result;  // Huffman gate CRC (read from WRAM by the differential gate)

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

static void restart(App *a) {
  a->bit = 0u; a->pixel = 0u; a->holdt = 0u;
  for (uint8_t cy = 0; cy < HF_H; cy++)
    for (uint8_t cx = 0; cx < HF_W; cx++) cell_fill(&a->canvas, cx, cy, 0u);
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);
}

// Decode + reveal PIX_FRAME more pixels this frame (the bit-tree walk).
__attribute__((noinline))
static void reveal(App *a) {
  if (a->pixel >= HF_N) { if (++a->holdt > 120u) restart(a); return; }
  for (uint8_t k = 0; k < PIX_FRAME && a->pixel < HF_N; k++) {
    uint8_t sym = hf_decode_one(a->stream, &a->bit);          // one symbol via the tree descent
    uint8_t cx = (uint8_t)(a->pixel % HF_W), cy = (uint8_t)(a->pixel / HF_W);
    cell_fill(&a->canvas, cx, cy, sym);
    a->pixel++;
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
  (void)hf_encode(a->stream);
  a->bit = 0u; a->pixel = 0u; a->holdt = 0u;
  text_puts(&a->text, 0, 1, "HUFFMAN DECODE");
  text_puts(&a->text, 1, 0, "BIT-STREAM TREE WALK  IMAGE LOADING");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "HUFFMAN", "BIT-TREE DECODE");
  corpus_result = huffman_gate_crc();           // self-verify the decode math == host 0xE8E4
  title_end(&a.screen, &title, 110);
  for (;;) {
    reveal(&a);
    display_frame(&a.screen);
  }
}
