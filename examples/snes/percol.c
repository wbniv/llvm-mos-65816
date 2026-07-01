// Union-Find Percolation — #62 of the compiler stress-test demo battery.
// Renders the verified, portable union-find (examples/65816/percol.h — the same header the host oracle
// tools/percol-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so it builds
// default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// Bond percolation: cells start as singleton sets; each frame a few random adjacent bonds union their
// sets (disjoint-set with PATH COMPRESSION — find chases parent pointers to the root and rewrites the
// whole path to point at it). Cells connected to the top row light up "wet"; the wet region grows
// downward until it reaches the bottom — the percolation phase transition. Then the grid reseeds. A
// codegen corner none of the first 61 demos run: the union-find find-with-compression pointer flatten.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/percol.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define BONDS_FRAME 6              // bonds added per frame

// BG3 2bpp palette (CGRAM 0..3): dry (dark) / wet (cyan) / spanning (white) / frontier (amber).
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(3, 4, 9), SNES_RGB(6, 26, 30), SNES_RGB(31, 31, 31), SNES_RGB(31, 22, 6),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  Percol       pc;
  uint16_t     frame;
  uint16_t     seed;
  uint8_t      done;         // percolated -> hold, then reseed
  uint8_t      hold;
} App;

volatile uint16_t corpus_result;  // union-find gate CRC (read from WRAM by the differential gate)

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Recolour the whole grid: wet (connected to the top row) vs dry; white if the spanning cluster.
__attribute__((noinline))
static void draw_grid(App *a) {
  uint16_t toproot[PC_W];
  for (uint16_t tx = 0; tx < PC_W; tx++) toproot[tx] = pc_find(&a->pc, tx);
  uint16_t spanroot = 0xFFFFu;
  if (a->done) {                                   // find which top root reached the bottom
    for (uint16_t tx = 0; tx < PC_W && spanroot == 0xFFFFu; tx++)
      for (uint16_t bx = 0; bx < PC_W; bx++)
        if (pc_find(&a->pc, (uint16_t)((PC_H - 1u) * PC_W + bx)) == toproot[tx]) { spanroot = toproot[tx]; break; }
  }
  for (uint8_t cy = 0; cy < PC_H; cy++)
    for (uint8_t cx = 0; cx < PC_W; cx++) {
      uint16_t root = pc_find(&a->pc, (uint16_t)(cy * PC_W + cx));
      uint8_t col = 0u;                            // dry
      for (uint16_t tx = 0; tx < PC_W; tx++)
        if (root == toproot[tx]) { col = 1u; break; }  // wet
      if (col == 1u && root == spanroot) col = 2u;  // spanning cluster -> white
      cell_fill(&a->canvas, cx, cy, col);
    }
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);
}

static void reseed(App *a) {
  a->seed = (uint16_t)(a->seed * 1103u + 12345u);
  pc_init(&a->pc, a->seed);
  a->done = 0u; a->hold = 0u;
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->frame = 0u; a->seed = 0xC0DEu; a->done = 0u; a->hold = 0u;
  pc_init(&a->pc, a->seed);
  text_puts(&a->text, 0, 1, "UNION-FIND PERCOLATION");
  text_puts(&a->text, 1, 0, "PATH-COMPRESSION  WET=TOP-CONNECTED");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "PERCOLATION", "UNION-FIND");
  corpus_result = percol_gate_crc();            // self-verify the union-find math == host 0x025B
  title_end(&a.screen, &title, 110);
  draw_grid(&a);
  for (;;) {
    a.frame++;
    if (!a.done) {
      for (uint8_t b = 0; b < BONDS_FRAME; b++) (void)pc_add_bond(&a.pc);
      if (pc_percolates(&a.pc)) a.done = 1u;
      draw_grid(&a);
    } else if (++a.hold > 90u) {                 // hold the spanning frame, then reseed
      reseed(&a);
      draw_grid(&a);
    }
    display_frame(&a.screen);
  }
}
