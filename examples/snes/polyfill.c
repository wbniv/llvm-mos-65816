// Polygon Scanline Fill (VLA) — #36 of the compiler stress-test demo battery.
// Renders the verified, portable scanline-fill math (examples/65816/polyfill.h — the same header the
// host oracle tools/polyfill-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so
// the program builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// Each frame: compute the rotating star's nv vertices (nv = 2*npoints, MORPHING at run time), then
// even-odd scanline-fill it. The x-crossing table is a C99 VLA — `int16_t xs[nv]`, its size a RUNTIME
// value — so the soft-stack target must do a runtime stack-pointer adjustment (alloca/VLA). That is
// the codegen corner #36 exists to exercise; a soft-stack target that can't would be a finding.
//
// Codegen under test: a runtime-sized VLA frame + __divsi3 (edge crossing), __udivsi3 (i*256/nv),
// __mulsi3 (r*cos vertex placement), all on the hot fill path.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256       // crisp full-canvas clear+redraw fits ONE v-blank (4 KB; see #16)
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/polyfill.h"

#define CANVAS_CHR  0x0000      // BG3 char base (word) — canvas tiles 0..255 + blank tile 256 + font 256..
#define CANVAS_MAP  0x4000      // BG3 tilemap base (word)
#define BOX_COL     8           // 16-tile canvas box at cols 8..23  (screen px 64..191)
#define BOX_ROW     6           // rows 6..21 (screen px 48..175)
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25

// BG3 2bpp palette (CGRAM 0..3): 0 black bg, 1 white (HUD + outline), 2 dim, 3 fill ink.
static const uint16_t bg3_pal[4] = {
  SNES_RGB(0, 0, 0), SNES_RGB(31, 31, 31), SNES_RGB(10, 10, 14), SNES_RGB(6, 26, 31),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  pf_state     poly;
  uint8_t      last_np;
} App;

volatile uint16_t corpus_result;  // filled-area CRC proof channel (read from WRAM by the gate)

// Fill one scanline's even-odd spans into the canvas (color 3 = both 2bpp planes), from the sorted
// VLA crossings. Writes whole tile bytes with precomputed edge masks (O(tiles), not O(pixels)) so the
// tumble stays smooth — the fill is pixel-heavy and per-pixel canvas_plot would drop it to ~2 fps.
static void fill_row(BitmapCanvas *cv, const int16_t *xs, uint16_t nx, int16_t y) {
  if ((uint16_t)y >= CANVAS_H) return;
  uint16_t rowtilebase = (uint16_t)(((uint16_t)y >> 3) * CANVAS_TILES_W);
  uint8_t  rowbyte     = (uint8_t)(((uint8_t)y & 7u) * 2u);
  for (uint16_t k = 0; k + 1u < nx; k += 2u) {
    int16_t sx0 = xs[k], sx1 = xs[k + 1u];
    if (sx1 < sx0) continue;
    if (sx0 < 0) sx0 = 0;
    if (sx1 > (int16_t)(CANVAS_W - 1)) sx1 = (int16_t)(CANVAS_W - 1);
    if (sx1 < sx0) continue;
    uint16_t x = (uint16_t)sx0, xb = (uint16_t)sx1;
    while (x <= xb) {
      uint16_t tx = (uint16_t)(x >> 3);
      uint16_t hi = ((tx << 3) | 7u);
      if (hi > xb) hi = xb;
      uint8_t bl = (uint8_t)(x & 7u), br = (uint8_t)(hi & 7u);
      uint8_t mask = (uint8_t)((0xFFu >> bl) & (uint8_t)(0xFFu << (7u - br)));  // bits bl..br set
      uint8_t *t = &cv->chr[(uint16_t)((rowtilebase + tx) * CANVAS_TILEBYTES) + rowbyte];
      t[0] |= mask; t[1] |= mask;
      x = (uint16_t)(hi + 1u);
    }
  }
}

// Compute the star's vertices, then even-odd scanline-fill it through a RUNTIME-SIZED VLA (xs[nv]).
// noinline bounds the a16/xy16 register pressure of the fill kernel (handoff §4).
__attribute__((noinline))
static void draw_frame(App *a) {
  int16_t px[PF_MAXV], py[PF_MAXV];
  uint16_t nv = pf_verts(&a->poly, px, py);
  int16_t xs[nv];                               // <-- the #36 VLA, on the real console soft stack
  for (int16_t y = (int16_t)PF_YMIN; y <= (int16_t)PF_YMAX; y++) {
    uint16_t nx = pf_scan(px, py, nv, y, xs);
    fill_row(&a->canvas, xs, nx, y);
  }
  // Bright outline: connect consecutive vertices (white, color 1) over the fill.
  for (uint16_t i = 0; i < nv; i++) {
    uint16_t j = (uint16_t)((i + 1u) % nv);
    canvas_line(&a->canvas, px[i], py[i], px[j], py[j], 1);
  }
}

static void hud_update(App *a) {
  char line[24];
  uint8_t n = 0;
  const char *lbl = "POLY FILL P";
  for (uint8_t i = 0; lbl[i]; i++) line[n++] = lbl[i];
  line[n++] = (char)('0' + a->poly.npoints);
  line[n++] = ' '; line[n++] = 'V';
  uint16_t nv = (uint16_t)a->poly.npoints * 2u;
  if (nv >= 10u) line[n++] = (char)('0' + nv / 10u);
  line[n++] = (char)('0' + nv % 10u);
  line[n] = 0;
  text_clear_bar(&a->text, 0);
  text_puts(&a->text, 0, 1, line);
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  pf_init(&a->poly);
  a->poly.npoints = 5u;                 // visual starts as a full 5-point star (gate uses its own state)
  a->last_np = a->poly.npoints;
  hud_update(a);
  text_puts(&a->text, 1, 0, "VLA XS[NV] SCANLINE EVEN-ODD FILL");
}

int main(void) {
  static App a;
  app_init(&a);
  // Title overlay (BG2), held while the gate CRC computes, then torn down before the star spins.
  static TitleLayer title;
  title_begin16(&a.screen, &title, "POLYGON FILL", "VLA SCANLINE");
  corpus_result = polyfill_gate_crc();          // self-verify the fill math == host 0x8ED9
  title_end(&a.screen, &title, 110);
  for (;;) {
    canvas_clear(&a.canvas);                     // crisp tumble: erase last frame
    draw_frame(&a);
    if (a.poly.npoints != a.last_np) { hud_update(&a); a.last_np = a.poly.npoints; }
    pf_step(&a.poly);
    display_frame(&a.screen);                    // flush dirty canvas tiles + HUD; release blank
  }
}
