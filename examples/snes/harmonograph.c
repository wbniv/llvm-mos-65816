/* Lissajous / Harmonograph on the snesgfx OOP library — #9 of the compiler stress-test demo battery.
 * Renders the verified, portable damped-sinusoid math (examples/65816/harmonograph.h — the same header
 * the host oracle tools/harmonograph-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas
 * (BG3), so the program builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers → the full
 * 5-way bar).
 *
 * Four damped pendulums (two per axis, slightly detuned) trace a Lissajous figure that precesses and
 * spirals inward as the exponential damping decays; once the envelope is spent the canvas clears and
 * the next of 4 presets blooms. A 2-row BG3 HUD labels the current figure.
 *
 * Codegen under test: a sin-LUT inner loop + EIGHT __mulsi3 per sample (four sin·env amplitude
 * products + four env·decay envelope products — a sustained fixed-point multiply + accumulation) +
 * 32-bit shift/add, all under +mos-a16 rep/sep brackets. Multiply-only (no divide).               */
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/harmonograph.h"

#define CANVAS_CHR  0x0000      /* BG3 char base (word) — canvas tiles 0..255 + blank 256 + font 256.. */
#define CANVAS_MAP  0x4000      /* BG3 tilemap base (word) */
#define BOX_COL     8           /* 16-tile canvas box at cols 8..23  (screen px 64..191) */
#define BOX_ROW     6           /* rows 6..21 (screen px 48..175) */
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define CX         (CANVAS_W / 2)
#define CY         (CANVAS_H / 2)
#define PTS_PER_FRAME 10        /* curve samples plotted per frame (the draw rate) */

/* Each figure runs this many samples, then the canvas clears and the next preset blooms. By ~700
 * samples the envelope (decay ≈ 0.998/sample) has bled to a few percent, so the curve has fully
 * settled into its centre point. */
#define FIG_SAMPLES   720u

/* BG3 2bpp palette (CGRAM 0..3): 0 = black bg, 1 = white (HUD), 2 = spare, 3 = curve (cyan). */
static const uint16_t bg3_pal[4] = {
  SNES_RGB(0, 0, 0), SNES_RGB(31, 31, 31), SNES_RGB(18, 18, 31), SNES_RGB(8, 28, 31),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  harmo_params params;
  harmo_state  pstate;
  int16_t      px, py;
  uint8_t      started;
  uint8_t      fig;          /* current preset 0..HARMO_NPRESETS-1 */
  uint16_t     drawn;        /* samples drawn in this figure */
} App;

volatile uint16_t corpus_result;   /* curve-math proof channel (read from WRAM by the gate) */

/* tiny unsigned-to-decimal for the HUD figure index (1..4). */
static uint8_t fmt_u8(uint8_t v, char *buf) {
  if (v >= 100u) { buf[0] = (char)('0' + v / 100u); buf[1] = (char)('0' + (v / 10u) % 10u);
                   buf[2] = (char)('0' + v % 10u); return 3; }
  if (v >= 10u)  { buf[0] = (char)('0' + v / 10u);  buf[1] = (char)('0' + v % 10u); return 2; }
  buf[0] = (char)('0' + v); return 1;
}

static void hud_update(App *a) {
  char line[24]; uint8_t n = 0;
  const char *t = "HARMONOGRAPH FIG ";
  for (const char *s = t; *s; s++) line[n++] = *s;
  n += fmt_u8((uint8_t)(a->fig + 1u), line + n);
  line[n++] = '/'; n += fmt_u8((uint8_t)HARMO_NPRESETS, line + n);
  line[n] = 0;
  text_clear_bar(&a->text, 0);
  text_puts(&a->text, 0, 1, line);
}

/* Load the next figure: re-init the damped oscillators, clear the canvas, reset the pen. */
static void rebloom(App *a) {
  harmo_init(&a->pstate, &a->params, a->fig);
  canvas_clear(&a->canvas);
  a->started = 0;
  a->drawn   = 0;
  hud_update(a);
}

/* Plot the next `n` curve samples, line-connecting consecutive points. noinline bounds a16/xy16
 * register pressure (handoff §4). */
__attribute__((noinline))
static void plot_n(App *a, uint16_t n) {
  for (uint16_t i = 0; i < n; i++) {
    int16_t x, y;
    harmo_point(&a->pstate, &a->params, &x, &y);
    int16_t qx = (int16_t)(x + CX), qy = (int16_t)(CY - y);
    if (a->started) canvas_line(&a->canvas, a->px, a->py, qx, qy, 3);
    a->px = qx; a->py = qy; a->started = 1;
    a->drawn++;
  }
}

static void app_init(App *a) {
  display_init(&a->screen);                                   /* boot bracket: force-blank, BGMODE_1 */
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);            /* reserve BG3 (tilemap + clear, force-blank) */
  display_add(&a->screen, (Drawable *)&a->text);              /* reserve: load font (force-blank) */
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->fig = 0;
  rebloom(a);
  text_puts(&a->text, 1, 0, "DAMPED SIN  4 PENDULUMS");
}

int main(void) {
  static App a;
  app_init(&a);

  /* Title overlay (BG2), added after the demo layers; held while the gate-CRC computes, then torn
     down before the curve blooms. Gate-neutral (no DMA; corpus_result is the pre-loop hash). */
  static TitleLayer title;
  title_begin(&a.screen, &title, "HARMONOGRAPH", "LISSAJOUS");

  corpus_result = harmo_gate_crc();                           /* self-verify curve math == host 0x0EBB */
  rebloom(&a);                                                /* harmo_gate_crc reused preset 0 state; restart */
  title_end(&a.screen, &title, 110);                               /* ~2 s title (gate hash is fast here) */

  for (;;) {
    plot_n(&a, PTS_PER_FRAME);
    if (a.drawn >= FIG_SAMPLES) {
      a.fig = (uint8_t)((a.fig + 1u) % HARMO_NPRESETS);
      rebloom(&a);
    }
    display_frame(&a.screen);                                 /* flush dirty tiles + HUD rows; release blank */
  }
}
