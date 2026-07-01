// Sparse-Switch Step-Sequencer VM — #37 of the compiler stress-test demo battery.
// Renders the verified, portable VM (examples/65816/seqvm.h — the same header the host oracle
// tools/seqvm-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so the program
// builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// A tiny register VM runs a looping bytecode "song"; its opcode dispatch is a SPARSE switch (14
// non-contiguous byte cases 0x00..0xF0) that the compiler must lower to a BINARY-SEARCH COMPARISON
// TREE, not a jump table (#29a) or a computed goto (#38). The 8 registers drive an 8-bar equalizer.
//
// Codegen under test: sparse-switch comparison-tree lowering (cmp/branch cascade, no indexed-indirect
// jump) — control-flow only, deliberately no __mul/__udiv.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256       // full-canvas clear+redraw fits ONE v-blank (4 KB; see #16)
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/seqvm.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8                // 16-tile canvas box at cols 8..23  (screen px 64..191)
#define BOX_ROW     6                // rows 6..21
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define STEPS_PER_FRAME 2u           // VM steps advanced each display frame (sequencer tempo)

// BG3 2bpp palette (CGRAM 0..3): 0 black bg, 1 peak cap (white), 2 dim (baseline), 3 bar body (green).
static const uint16_t bg3_pal[4] = {
  SNES_RGB(0, 0, 0), SNES_RGB(31, 31, 31), SNES_RGB(6, 9, 8), SNES_RGB(8, 30, 12),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  seqvm_state  vm;
} App;

volatile uint16_t corpus_result;  // sparse-switch VM state CRC (read from WRAM by the gate)

// Fill an axis-aligned rectangle [x0..x1]x[y0..y1] in `color` — masked byte hspans per row (fast).
static void fill_rect(BitmapCanvas *cv, int16_t x0, int16_t y0, int16_t x1, int16_t y1, uint8_t color) {
  if (x0 < 0) x0 = 0; if (y0 < 0) y0 = 0;
  if (x1 > (int16_t)(CANVAS_W - 1)) x1 = (int16_t)(CANVAS_W - 1);
  if (y1 > (int16_t)(CANVAS_H - 1)) y1 = (int16_t)(CANVAS_H - 1);
  for (int16_t y = y0; y <= y1; y++) {
    uint16_t rowtilebase = (uint16_t)(((uint16_t)y >> 3) * CANVAS_TILES_W);
    uint8_t  rowbyte     = (uint8_t)(((uint8_t)y & 7u) * 2u);
    uint16_t x = (uint16_t)x0, xb = (uint16_t)x1;
    while (x <= xb) {
      uint16_t tx = (uint16_t)(x >> 3);
      uint16_t hi = ((tx << 3) | 7u);
      if (hi > xb) hi = xb;
      uint8_t bl = (uint8_t)(x & 7u), br = (uint8_t)(hi & 7u);
      uint8_t mask = (uint8_t)((0xFFu >> bl) & (uint8_t)(0xFFu << (7u - br)));
      uint8_t *t = &cv->chr[(uint16_t)((rowtilebase + tx) * CANVAS_TILEBYTES) + rowbyte];
      if (color & 1u) t[0] |= mask; else t[0] &= (uint8_t)~mask;
      if (color & 2u) t[1] |= mask; else t[1] &= (uint8_t)~mask;
      x = (uint16_t)(hi + 1u);
    }
  }
}

// Draw the 8-bar equalizer from the VM registers. noinline bounds a16/xy16 register pressure.
__attribute__((noinline))
static void draw_frame(App *a) {
  for (uint8_t c = 0; c < SEQ_NREG; c++) {
    uint8_t level = seqvm_level(&a->vm, c);
    int16_t bx0 = (int16_t)((uint16_t)c * 16u + 2u);
    int16_t bx1 = (int16_t)(bx0 + 11);                 // 12px wide bar
    for (uint8_t lvl = 0; lvl < level; lvl++) {
      int16_t y1 = (int16_t)(127 - (int16_t)lvl * 16);  // bottom of this cell
      int16_t y0 = (int16_t)(y1 - 13);                  // 14px tall cell
      fill_rect(&a->canvas, bx0, y0, bx1, y1, (uint8_t)(lvl + 1u == level ? 1u : 3u));
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
  seqvm_init(&a->vm);
  text_puts(&a->text, 0, 1, "STEP SEQUENCER VM");
  text_puts(&a->text, 1, 0, "SPARSE SWITCH  14 OPS  CMP TREE");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "STEP SEQUENCER", "SPARSE-SWITCH VM");
  corpus_result = seqvm_gate_crc();             // self-verify the VM math == host 0xE8C5
  title_end(&a.screen, &title, 110);
  for (;;) {
    for (uint8_t i = 0; i < STEPS_PER_FRAME; i++) seqvm_step(&a.vm);
    canvas_clear(&a.canvas);
    draw_frame(&a);
    display_frame(&a.screen);
  }
}
