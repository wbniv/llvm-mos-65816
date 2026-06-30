// #23 — L-System Plant on the SNES.
//
// Grows an L-system by STRING REWRITING (examples/65816/lsystem.h) — each generation rewrites a char
// buffer IN PLACE with memmove (overlapping tail shift) + memcpy (write the production) + strlen (its
// length), the string-libcall corner no other demo runs — then a turtle interprets the final string into
// a fractal plant on a NEAR 2bpp bitmap canvas (BG3). The turtle's `[`/`]` save/restore is a bracket
// push/pop stack, the second new corner.
//
// The picture IS the proof: a correct rewrite + interpreter grows a coherent fractal plant; a memcpy/
// strlen miscompile or a botched stack frame scrambles the string/path and the gate CRC freezes. No far
// pointers (buffers/stack/turtle in bank-0 WRAM) so the corpus slice (lsystem_sim.c) is a full 5-way
// differential: corpus_result = lsystem_gate_crc() == the host oracle (tools/lsystem-sim.c) == 0x79C3,
// bit-for-bit, across default / +mos-a16 / +mos-xy16.
//
// The plant draws and the gate CRC come from the SAME interpretation pass: lsystem_interp folds the CRC
// AND calls our emit callback per segment, so the on-screen path and corpus_result can never disagree.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/title_layer.h"
#include "../65816/lsystem.h"

#define CANVAS_CHR  0x0000      // BG3 char base (word) — canvas tiles 0..255
#define CANVAS_MAP  0x4000      // BG3 tilemap base (word)
#define BOX_COL     8           // 16-tile (128 px) canvas box at cols 8..23  (screen px 64..191)
#define BOX_ROW     6           // rows 6..21 (screen px 48..175)

volatile uint16_t corpus_result;   // differential proof channel (read from WRAM by the gate)

// BG3 2bpp palette (CGRAM 0..3): 0 = black bg, then trunk + two greens (selected by branch depth).
static const uint16_t bg3_pal[4] = {
  SNES_RGB(0, 0, 0), SNES_RGB(20, 11, 2), SNES_RGB(7, 26, 5), SNES_RGB(16, 31, 9),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
} App;

// The L-system interpreter's per-segment emit callback: draw one line into the canvas.
static void draw_seg(void *ctx, uint8_t x0, uint8_t y0, uint8_t x1, uint8_t y1, uint8_t col) {
  canvas_line((BitmapCanvas *)ctx, (int16_t)x0, (int16_t)y0, (int16_t)x1, (int16_t)y1, col);
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);                    // reserve BG3 (force-blank)
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
}

int main(void) {
  static App a;
  app_init(&a);

  // Title card (BG2). Behind it, rewrite the L-system then interpret it: the interpreter draws the whole
  // plant into the canvas (via draw_seg) AND returns the path CRC -> corpus_result (== host == 0x79C3).
  static TitleLayer title;
  title_begin(&a.screen, &title, "L-SYSTEM", "PLANT");
  uint16_t len;
  const char *s = lsystem_build(&len);
  corpus_result = lsystem_interp(s, len, draw_seg, &a.canvas);
  title_end(&a.screen, &title, 110);
  a.screen.bright = INIDISP_ON; a.screen.btgt = INIDISP_ON;          // full brightness from frame 1

  // The plant is fully drawn into the canvas shadow; the dirty-tile DMA streams it in over a few frames.
  for (;;) display_frame(&a.screen);
}
