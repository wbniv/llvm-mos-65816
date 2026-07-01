// Edit-Distance Dynamic Programming — #66 of the compiler stress-test demo battery.
// Renders the verified, portable Levenshtein DP (examples/65816/editdist.h — the same header the host
// oracle tools/editdist-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so it
// builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// For each word pair the (m+1)x(n+1) DP table D[i][j] is filled by the min-recurrence
// D[i][j]=min(sub,del,ins), then the optimal alignment is backtracked from D[m][n] to D[0][0]. The table
// is drawn as a cost heat-map with the traced path lit. A codegen corner none of the first 65 demos run:
// a 2-D dynamic-programming table (true D[i][j] addressing) with a min-recurrence + backtrack walk.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/editdist.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define HOLD        120           // frames each word pair is shown

// BG3 2bpp palette (CGRAM 0..3): low cost (dark) / mid (blue) / high (amber) / path (white).
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(3, 4, 9), SNES_RGB(6, 16, 28), SNES_RGB(31, 22, 6), SNES_RGB(31, 31, 31),
};

// Word pairs to align (<= ED_MAX chars each).
static const char *const WORDS_A[] = { "KITTEN", "SATURDAY", "DYNAMICPROG", "INTENTION", "FLAW" };
static const char *const WORDS_B[] = { "SITTING", "SUNDAY",  "EDITDISTANC", "EXECUTION", "LAWN" };
#define NPAIR 5

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  EditDist     e;
  uint16_t     frame;
  uint8_t      pair;
} App;

volatile uint16_t corpus_result;  // edit-distance gate CRC (read from WRAM by the differential gate)

static uint8_t slen(const char *s) { uint8_t n = 0; while (s[n]) n++; return n; }

// Fill an 8x8 cell at (cx,cy) with 2bpp colour (0..3).
static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Fill + backtrack the current pair, then draw the DP table as a heat-map with the path lit. noinline.
__attribute__((noinline))
static void solve_and_draw(App *a) {
  const char *A = WORDS_A[a->pair], *B = WORDS_B[a->pair];
  uint8_t m = slen(A), n = slen(B);
  ed_fill(&a->e, (const uint8_t *)A, m, (const uint8_t *)B, n);
  ed_backtrack(&a->e, (const uint8_t *)A, (const uint8_t *)B);
  for (uint8_t i = 0; i <= m && i < 16u; i++)
    for (uint8_t j = 0; j <= n && j < 16u; j++) {
      uint8_t col;
      if (a->e.path[i][j]) col = 3u;                        // path (white)
      else { uint8_t d = a->e.D[i][j]; col = (d < 4u) ? 0u : ((d < 9u) ? 1u : 2u); }
      cell_fill(&a->canvas, j, i, col);                     // column = j (B), row = i (A)
    }
  for (uint8_t i = 0; i < 16u; i++)                         // clear unused cells
    for (uint8_t j = 0; j < 16u; j++)
      if (i > m || j > n) cell_fill(&a->canvas, j, i, 0u);
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->frame = 0u; a->pair = 0u;
  text_puts(&a->text, 0, 1, "EDIT-DISTANCE DP");
  text_puts(&a->text, 1, 0, "MIN-RECURRENCE + BACKTRACK PATH");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "EDIT DISTANCE", "DP + BACKTRACK");
  corpus_result = editdist_gate_crc();          // self-verify the DP math == host 0xFB59
  title_end(&a.screen, &title, 110);
  solve_and_draw(&a);
  for (;;) {
    a.frame++;
    if ((a.frame % HOLD) == 0u) { a.pair = (uint8_t)((a.pair + 1u) % NPAIR); solve_and_draw(&a); }
    display_frame(&a.screen);
  }
}
