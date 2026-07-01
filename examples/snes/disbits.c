// Cross-Byte-Boundary Bitfield Disassembler — #52 of the compiler stress-test demo battery.
// A scrolling colour-coded "disassembly" where each cell decodes a synthetic opcode byte into bitfields
// that STRADDLE byte boundaries inside a uint32_t (examples/65816/disbits.h — the same dis_decode the
// host oracle tools/disbits-sim.c and the corpus slice run), colouring by the extracted instruction
// group. No far pointers -> builds default-8-bit AND +mos-a16 AND +mos-xy16, the full 5-way bar.
//
// Codegen under test: unaligned / cross-byte-boundary bitfield extract-insert — fields crossing bit 16
// (group) and bit 24 (flags) force multi-byte shift + mask (distinct from #29b's single-uint16 fields).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/disbits.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCELL       (CANVAS_W / 8)   // 16

static const uint16_t bg3_pal[4] = {
  SNES_RGB(3, 4, 10), SNES_RGB(28, 10, 12), SNES_RGB(10, 26, 28), SNES_RGB(28, 26, 10),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint8_t      t;
} App;

volatile uint16_t corpus_result;  // cross-byte bitfield fold (read from WRAM by the gate)

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Decode a synthetic opcode per cell and colour by the (cross-byte) group + flags fields. noinline
// caps the a16/xy16 register pressure of the bitfield loop.
__attribute__((noinline))
static void field_step(App *a) {
  for (uint8_t cy = 0; cy < NCELL; cy++)
    for (uint8_t cx = 0; cx < NCELL; cx++) {
      Instr in;
      uint8_t op      = (uint8_t)(cx * 17u + cy * 3u + a->t);
      uint8_t operand = (uint8_t)(cy * 11u + a->t);
      dis_decode(&in, op, operand);                    // insert into straddling bitfields
      uint8_t col = (uint8_t)(((in.group >> 1) ^ (in.flags >> 2)) & 3u);  // straddling extracts
      cell_fill(&a->canvas, cx, cy, col);
    }
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);
  a->t++;
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->t = 0u;
  text_puts(&a->text, 0, 1, "CROSS-BYTE BITFIELDS");
  text_puts(&a->text, 1, 0, "OP:8 MODE:3 GROUP:5 FLAGS:7 U32");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "BITFIELDS", "CROSS-BYTE");
  corpus_result = disbits_gate_crc();           // self-verify the straddling-bitfield decode == host 0x31D7
  title_end(&a.screen, &title, 110);
  for (;;) {
    field_step(&a);
    display_frame(&a.screen);
  }
}
