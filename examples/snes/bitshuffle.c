// Perfect-Shuffle Transition — #54 of the compiler stress-test demo battery.
// Renders the verified, portable bit-permutation (examples/65816/bitshuffle.h — the same header the
// host oracle tools/bitshuffle-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3),
// so it builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// A source image is permuted by the BIT-REVERSAL of each cell's linear index (__builtin_bitreverse32,
// G_BITREVERSE .lower() @186) — an INVOLUTION, so the image scrambles into its butterfly/perfect-shuffle
// order and un-scrambles with the same operation. While held scrambled, colours byte-rotate via
// __builtin_bswap32 (-> __bswapsi2). Distinct from #25/#28's hand-rolled bit-reversal loops: here the
// clang builtins take the generic-opcode -> legalizer path.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256       // full-canvas redraw fits ONE v-blank (4 KB; see #16/#40)
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/bitshuffle.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCELL       16              // 16x16 cells (matches SHUF_BITS=8 -> 256-cell index space)
#define NCOL        4               // BG3 2bpp: 4 colours

// Phase timing (frames): scramble sweep, hold + recolour, unscramble sweep, hold identity.
#define T_SCRAMBLE  260u
#define T_HOLD1     140u
#define T_UNSCRAM   260u
#define T_HOLD2     90u
#define T_CYCLE     (T_SCRAMBLE + T_HOLD1 + T_UNSCRAM + T_HOLD2)

// BG3 2bpp palette (CGRAM 0..3): a four-quadrant source palette — teal / amber / magenta / white.
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(4, 22, 24), SNES_RGB(31, 21, 6), SNES_RGB(28, 6, 24), SNES_RGB(31, 31, 31),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint16_t     frame;
  uint8_t      phase_shown;  // HUD phase currently written (avoid redundant redraw)
} App;

volatile uint16_t corpus_result;  // bit-shuffle gate CRC (read from WRAM by the differential gate)

// The source image: four coloured quadrants with a diagonal accent — a shape whose scramble is obvious.
static uint8_t src_color(uint8_t sx, uint8_t sy) {
  uint8_t q = (uint8_t)(((sx >> 3) & 1u) | (((sy >> 3) & 1u) << 1));   // 2x2 quadrant -> 0..3
  if (sx == sy || (uint8_t)(NCELL - 1 - sx) == sy) return 3u;         // white diagonals
  return q;
}

// Fill an 8x8 cell at (cx,cy) with 2bpp colour (0..3), writing whole tile bytes directly.
static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
  uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
  uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
  uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
  uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
  for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
}

// Recompute the whole grid for the current transition phase. noinline caps register pressure.
__attribute__((noinline))
static void shuffle_step(App *a) {
  uint16_t c = (uint16_t)(a->frame % T_CYCLE);
  // sweep threshold: how many cells (in index order) are currently in their permuted position.
  uint16_t thresh;
  uint8_t recolor;
  if (c < T_SCRAMBLE)                     { thresh = (uint16_t)(c * 256u / T_SCRAMBLE); recolor = 0; }
  else if (c < T_SCRAMBLE + T_HOLD1)      { thresh = 256u; recolor = 1; }
  else if (c < T_SCRAMBLE + T_HOLD1 + T_UNSCRAM) {
    uint16_t u = (uint16_t)(c - (T_SCRAMBLE + T_HOLD1));
    thresh = (uint16_t)(256u - u * 256u / T_UNSCRAM); recolor = 0;    // cells return to identity
  } else                                  { thresh = 0u; recolor = 0; }

  for (uint8_t cy = 0; cy < NCELL; cy++)
    for (uint8_t cx = 0; cx < NCELL; cx++) {
      uint16_t j = (uint16_t)((uint16_t)cy * NCELL + cx);
      uint16_t si = (j < thresh) ? bitshuffle_perm(j) : j;            // permuted or identity
      uint8_t col = src_color((uint8_t)(si % NCELL), (uint8_t)(si / NCELL));
      if (recolor) {                                                  // byte-swap recolour while held
        uint8_t rc = bitshuffle_color((uint16_t)(cx + a->frame), (uint16_t)cy, a->frame, NCOL);
        col = (uint8_t)((col + rc) & 3u);
      }
      cell_fill(&a->canvas, cx, cy, col);
    }
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);     // re-DMA the whole canvas
}

static void hud_phase(App *a) {
  uint16_t c = (uint16_t)(a->frame % T_CYCLE);
  uint8_t ph;
  if (c < T_SCRAMBLE)                { ph = 0; }
  else if (c < T_SCRAMBLE + T_HOLD1) { ph = 1; }
  else if (c < T_SCRAMBLE + T_HOLD1 + T_UNSCRAM) { ph = 2; }
  else                              { ph = 3; }
  if (ph == a->phase_shown) return;
  a->phase_shown = ph;
  const char *msg =
    (ph == 0) ? "BIT-REVERSE SCRAMBLE " :
    (ph == 1) ? "BYTE-SWAP RECOLOUR   " :
    (ph == 2) ? "BIT-REVERSE UNSHUFFLE" :
                "SOURCE IMAGE         ";
  text_puts(&a->text, 1, 0, msg);
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->frame = 0u;
  a->phase_shown = 0xFFu;
  text_puts(&a->text, 0, 2, "PERFECT SHUFFLE");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "PERFECT SHUFFLE", "BITREV / BSWAP");
  corpus_result = bitshuffle_gate_crc();        // self-verify the permutation math == host 0x2A4A
  title_end(&a.screen, &title, 110);
  for (;;) {
    a.frame++;
    hud_phase(&a);
    shuffle_step(&a);
    display_frame(&a.screen);
  }
}
