// Table-Driven CRC32 Procedural Texture — #40 of the compiler stress-test demo battery.
// Renders the verified, portable CRC32 hash (examples/65816/crctex.h — the same header the host oracle
// tools/crctex-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so the program
// builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// Each cell's colour is a real CRC32 (poly 0xEDB88320) of its (x, y, time) coordinates, computed by
// the standard byte-at-a-time table algorithm: crc = TABLE[(crc^byte)&0xFF] ^ (crc>>8), where TABLE
// is a const uint32_t[256] in ROM. The field flows and mutates ("hash marble").
//
// Codegen under test: a 256-entry const ROM look-up table indexed per byte (32-bit indexed load loop).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256       // full-canvas redraw fits ONE v-blank (4 KB; see #16)
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/crctex.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define CELL        8                // 8x8 px per hashed cell -> 16x16 cells over the 128x128 canvas
#define NCELL       (CANVAS_W / CELL)   // 16
#define NCOL        4                // BG3 2bpp: 4 marble colours

// BG3 2bpp palette (CGRAM 0..3): a compact marble ramp deep-blue -> teal -> white -> amber.
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(2, 4, 10), SNES_RGB(6, 20, 27), SNES_RGB(30, 31, 30), SNES_RGB(31, 20, 6),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint8_t      t;
} App;

volatile uint16_t corpus_result;  // CRC32 texture-hash CRC (read from WRAM by the gate)

// Fill an 8x8 cell at (cx,cy) with 2bpp colour (0..3), writing whole tile bytes directly.
static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);   // one cell == one 8x8 tile
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Recompute the whole field from the CRC32 hash at time t (flows diagonally). noinline caps pressure.
__attribute__((noinline))
static void field_step(App *a) {
  for (uint8_t cy = 0; cy < NCELL; cy++)
    for (uint8_t cx = 0; cx < NCELL; cx++) {
      uint32_t hash = crctex_cell((uint8_t)(cx + (a->t >> 1)), (uint8_t)(cy + (a->t >> 2)),
                                  (uint8_t)(a->t >> 3));
      cell_fill(&a->canvas, cx, cy, crctex_color(hash, NCOL));
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
  a->t = 0u;
  text_puts(&a->text, 0, 1, "CRC32 HASH MARBLE");
  text_puts(&a->text, 1, 0, "256-ENTRY ROM LUT  POLY EDB88320");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "CRC32 TEXTURE", "ROM-LUT HASH");
  corpus_result = crctex_gate_crc();            // self-verify the CRC32 math == host 0xDBBA
  title_end(&a.screen, &title, 110);
  for (;;) {
    a.t++;
    field_step(&a);
    display_frame(&a.screen);
  }
}
