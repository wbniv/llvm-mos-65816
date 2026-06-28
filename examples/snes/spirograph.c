// Spirograph (hypotrochoid) on the snesgfx OOP library — #11 of the compiler stress-test demo
// battery. Renders the verified, portable curve math (examples/65816/spiro.h — the same header the
// host oracle tools/spiro-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so
// the program builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// The figure BLOOMS a few curve points per frame; the joypad drives the parametric controls live (the
// interactive state machine examples/snes/spirograph.h), and a tiled BG3 HUD shows the (R,r,d) / mode
// / petal-count fields. Curve families: hypotrochoid / epitrochoid / rose / Lissajous (A/Y cycles).
//
// Codegen under test: sin/cos-LUT + two 16x16->32 fixed-point multiplies + 32-bit add/shift per point
// (spiro_point), plus the gear-ratio divide per parameter change (spiro_derive).
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/controller.h"
#include "spirograph.h"

#define CANVAS_CHR  0x0000      // BG3 char base (word) — canvas tiles 0..255 + blank/space tile 256 + font 256..
#define CANVAS_MAP  0x4000      // BG3 tilemap base (word)
#define BOX_COL     8           // 16-tile canvas box at cols 8..23  (screen px 64..191)
#define BOX_ROW     6           // rows 6..21 (screen px 48..175)
#define HUD_TOP_ROW 1           // value bar  (above the box)
#define HUD_BOT_ROW 25          // legend bar (below the box)
#define CX         (CANVAS_W / 2)
#define CY         (CANVAS_H / 2)
#define PTS_PER_FRAME 8         // curve samples plotted per frame (the bloom rate)

// BG3 2bpp palette (CGRAM 0..3): 0 = black bg, 1 = white (HUD text), 2 = spare, 3 = curve (cyan).
static const uint16_t bg3_pal[4] = {
  SNES_RGB(0, 0, 0), SNES_RGB(31, 31, 31), SNES_RGB(18, 18, 31), SNES_RGB(8, 28, 31),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  Controller   pad;
  spiro_view   view;
  spiro_params params;
  spiro_state  pstate;
  int16_t      px, py;
  uint8_t      started;
  uint16_t     crc;        // controller proof CRC (verified separately via the corpus slice)
} App;

volatile uint16_t corpus_result;   // curve-math proof channel (read from WRAM by the gate)

// Build the top HUD line "R<ring> W<wheel> D<pen> <MODE> P<petals>" (the font is uppercase-only, so
// the ring/wheel radii are labelled R and W, the pen offset D). NUL-terminated.
static void fmt_hud(const spiro_view *v, char *buf) {
  uint8_t n = 0;
  buf[n++] = 'R'; n += spiro_fmt_u8(v->R, buf + n); buf[n++] = ' ';
  buf[n++] = 'W'; n += spiro_fmt_u8(v->r, buf + n); buf[n++] = ' ';
  buf[n++] = 'D'; n += spiro_fmt_u8(v->d, buf + n); buf[n++] = ' ';
  const char *m = SPIRO_MODE_NAME[v->mode];
  for (uint8_t i = 0; i < 5 && m[i]; i++) buf[n++] = m[i];
  buf[n++] = ' '; buf[n++] = 'P'; n += spiro_fmt_u8(spiro_petals(v->R, v->r), buf + n);
  buf[n] = 0;
}

static void hud_update(App *a) {
  char line[24];
  fmt_hud(&a->view, line);
  text_clear_bar(&a->text, 0);
  text_puts(&a->text, 0, 1, line);
}

// Re-derive the curve params and restart the bloom on a clean canvas (called when the figure changed).
static void rebloom(App *a) {
  spiro_derive(a->view.R, a->view.r, a->view.d, a->view.mode, &a->params);
  canvas_clear(&a->canvas);
  a->pstate.acc_a = 0; a->pstate.acc_b = 0;
  a->started = 0;
}

// Plot the next `n` curve samples, line-connecting consecutive points. noinline bounds a16/xy16
// register pressure (handoff §4).
__attribute__((noinline))
static void plot_n(App *a, uint16_t n) {
  for (uint16_t i = 0; i < n; i++) {
    int16_t x, y;
    spiro_point(&a->pstate, &a->params, &x, &y);
    int16_t qx = (int16_t)(x + CX), qy = (int16_t)(CY - y);
    if (a->started) canvas_line(&a->canvas, a->px, a->py, qx, qy, 3);
    a->px = qx; a->py = qy; a->started = 1;
  }
}

static void app_init(App *a) {
  display_init(&a->screen);                                   // boot bracket: force-blank, BGMODE_1
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);            // reserve BG3 (tilemap + clear, force-blank)
  display_add(&a->screen, (Drawable *)&a->text);              // reserve: load font (force-blank)
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  controller_init(&a->pad);
  spiro_view_reset(&a->view);
#ifdef SPIRO_BOOT_MODE
  a->view.mode = SPIRO_BOOT_MODE;       // screenshot/demo override of the boot curve family
#endif
  a->crc = 0xFFFF;
  rebloom(a);                                                 // derive classic preset + clear canvas
  hud_update(a);
  text_puts(&a->text, 1, 0, "DPAD RW  LR D  AY MODE  SEL GEAR");
}

int main(void) {
  static App a;
  app_init(&a);
  /* Title overlay (BG2), added after the demo layers; held while the gate-CRC computes, then torn
     down before the curve blooms. Gate-neutral (no DMA; corpus_result is the pre-loop hash). */
  static TitleLayer title;
  title_init(&title, "SPIROGRAPH", "HYPOTROCHOID");
  display_add(&a.screen, (Drawable *)&title);
  display_frame(&a.screen);
  corpus_result = spiro_gate_crc();                           // self-verify curve math == host 0x32D4
  display_hold(&a.screen, 110);                               // ~2 s title (gate hash is fast here)
  display_hide_layer(&a.screen, (Drawable *)&title);
  for (;;) {
    controller_poll(&a.pad);
    spiro_view_step(&a.view, controller_held(&a.pad));        // edge/level handling inside
    if (a.view.dirty) { rebloom(&a); hud_update(&a); }
    plot_n(&a, PTS_PER_FRAME);
    a.crc = spiro_view_fold(a.crc, &a.view);
    display_frame(&a.screen);                                 // flush dirty tiles + HUD rows; release blank
  }
}
