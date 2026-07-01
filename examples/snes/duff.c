// Dissolve Transition — Duff's Device — #42 of the compiler stress-test demo battery.
// One image dissolves into the next in scattered bursts, each revealed tile's bytes copied by the
// classic Duff's device (examples/65816/duff.h — the same duff_copy the host oracle tools/duff-sim.c
// and the corpus slice run). No far pointers -> the program builds default-8-bit AND +mos-a16 AND
// +mos-xy16, so it earns the full 5-way differential bar.
//
// Codegen under test: irreducible loop-switch control flow — a switch whose case labels land in the
// middle of a do/while loop body (Duff's device). The interlaced jump targets + loop back-edge form
// a CFG the structurizer can't reduce; the backend must lower the branch tangle directly.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256       // full-canvas redraw fits ONE v-blank (4 KB; see #16)
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/duff.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4                // BG3 2bpp
#define REVEAL_PER_FRAME 3           // tiles dissolved in per frame

// BG3 2bpp palette (CGRAM 0..3).
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(2, 3, 8), SNES_RGB(28, 10, 22), SNES_RGB(10, 24, 30), SNES_RGB(31, 28, 14),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint8_t      variant;     // which pattern
  uint16_t     revealed;    // 0..CANVAS_NTILES tiles copied so far
} App;

volatile uint16_t corpus_result;  // Duff's-device copy fold (read from WRAM by the gate)

// bit-reverse an 8-bit tile index -> scattered dissolve order.
static uint8_t bitrev8(uint8_t v) {
  v = (uint8_t)(((v & 0xF0u) >> 4) | ((v & 0x0Fu) << 4));
  v = (uint8_t)(((v & 0xCCu) >> 2) | ((v & 0x33u) << 2));
  v = (uint8_t)(((v & 0xAAu) >> 1) | ((v & 0x55u) << 1));
  return v;
}

// Fill a 16-byte 2bpp tile scratch with the solid colour that tile `tile` holds in image `variant`.
static void build_tile(uint8_t *dst, uint16_t tile, uint8_t variant) {
  uint8_t tx = (uint8_t)(tile & 15u), ty = (uint8_t)(tile >> 4);
  uint8_t c;
  if (variant & 1u) {
    int8_t dx = (int8_t)(tx - 8), dy = (int8_t)(ty - 8);
    uint8_t r = (uint8_t)((dx * dx + dy * dy) >> 3);       // concentric rings
    c = (uint8_t)(r & 3u);
  } else {
    c = (uint8_t)(((tx + ty) >> 1) & 3u);                  // diagonal bands
  }
  uint8_t p0 = (uint8_t)((c & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((c & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { dst[r * 2] = p0; dst[r * 2 + 1] = p1; }
}

// Dissolve in REVEAL_PER_FRAME more tiles this frame, copying each via Duff's device. noinline caps
// the a16/xy16 register pressure of the copy+scatter loop.
__attribute__((noinline))
static void field_step(App *a) {
  uint8_t tilebuf[CANVAS_TILEBYTES];
  for (uint8_t k = 0; k < REVEAL_PER_FRAME; k++) {
    if (a->revealed >= CANVAS_NTILES) {                    // dissolve complete -> next image
      a->variant = (uint8_t)(a->variant + 1u);
      a->revealed = 0u;
    }
    uint16_t tile = bitrev8((uint8_t)a->revealed);         // scattered reveal order
    build_tile(tilebuf, tile, a->variant);                 // regenerate the source tile
    duff_copy(&a->canvas.chr[tile * CANVAS_TILEBYTES], tilebuf, CANVAS_TILEBYTES);
    a->revealed = (uint16_t)(a->revealed + 1u);
  }
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);   // re-DMA the whole canvas
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->variant = 0u;
  a->revealed = 0u;
  text_puts(&a->text, 0, 1, "DUFF DISSOLVE");
  text_puts(&a->text, 1, 0, "SWITCH INTO A LOOP  UNROLLED COPY");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "DUFF DISSOLVE", "SWITCH-IN-LOOP");
  corpus_result = duff_gate_crc();              // self-verify the Duff's-device copy == host 0x5531
  title_end(&a.screen, &title, 110);
  for (;;) {
    field_step(&a);
    display_frame(&a.screen);
  }
}
