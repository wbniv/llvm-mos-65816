// Constant-Divisor Clock + Odometer — #39 of the compiler stress-test demo battery.
// Renders the verified, portable clock/odometer math (examples/65816/divclock.h — the same header the
// host oracle tools/divclock-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so
// the program builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// A sweeping analog clock (hour/minute/second hands) + a rolling base-10 odometer. Splitting the frame
// tick into h:m:s and the counter into digits uses divides by COMPILE-TIME CONSTANTS (/60, /10, /12).
//
// MEASURED FINDING (see the plan): llvm-mos does NOT strength-reduce constant division to a magic
// reciprocal at any width — the magic reciprocal needs a MULHU that is itself a libcall on this
// soft-multiply target, so the cost model correctly RETAINS __udivsi3/__udivmodsi4. The 5-way
// differential proves that retained constant division is bit-exact across default/a16/xy16. Not a bug;
// a correct cost decision (and a documented upstream optimization opportunity if MULHU ever cheapens).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256       // full-canvas clear+redraw fits ONE v-blank (4 KB; see #16)
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/divclock.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define CXc        (CANVAS_W / 2)
#define CYc        (CANVAS_H / 2)
#define TICK_STEP  41u               // frames advanced per display frame (fast sweep)
#define ODO_STEP   7u                // odometer increment per display frame

// BG3 2bpp palette: 0 black, 1 second hand (white), 2 ticks/face (dim), 3 hour+minute hands (amber).
static const uint16_t bg3_pal[4] = {
  SNES_RGB(0, 0, 0), SNES_RGB(31, 31, 31), SNES_RGB(9, 9, 13), SNES_RGB(31, 22, 6),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  dc_state     clk;
} App;

volatile uint16_t corpus_result;  // magic-reciprocal clock/odometer CRC (read from WRAM by the gate)

// Draw a hand of length `len` at angle index `idx` (0 = 12 o'clock) in `color`.
static void hand(BitmapCanvas *cv, uint8_t idx, int16_t len, uint8_t color) {
  int16_t ex = (int16_t)(CXc + (int16_t)(((int32_t)len * DC_SIN(idx)) >> 8));
  int16_t ey = (int16_t)(CYc - (int16_t)(((int32_t)len * DC_COS(idx)) >> 8));
  canvas_line(cv, CXc, CYc, ex, ey, color);
}

// Draw the clock face (12 tick dots) + the three hands from the current time. noinline caps pressure.
__attribute__((noinline))
static void draw_frame(App *a) {
  uint8_t hh, mm, ss;
  dc_hms(a->clk.tick, &hh, &mm, &ss);
  // 12 tick marks around radius 58.
  for (uint8_t t = 0; t < 12u; t++) {
    uint8_t idx = (uint8_t)(t * 21u + t / 3u);            // ~ t*256/12
    int16_t tx = (int16_t)(CXc + (int16_t)(((int32_t)58 * DC_SIN(idx)) >> 8));
    int16_t ty = (int16_t)(CYc - (int16_t)(((int32_t)58 * DC_COS(idx)) >> 8));
    canvas_plot(&a->canvas, tx, ty, 2);
    canvas_plot(&a->canvas, tx + 1, ty, 2);
    canvas_plot(&a->canvas, tx, ty + 1, 2);
  }
  hand(&a->canvas, dc_hand_angle(hh, 12u), 30, 3);        // hour  (amber, short)
  hand(&a->canvas, dc_hand_angle(mm, 60u), 46, 3);        // minute(amber, long)
  hand(&a->canvas, dc_hand_angle(ss, 60u), 52, 1);        // second(white, longest)
  canvas_plot(&a->canvas, CXc, CYc, 1);                   // centre pin
}

// Write a zero-padded 2-digit number at (row,col).
static void put2(TextLayer *t, uint8_t row, uint8_t col, uint8_t v) {
  char b[3]; b[0] = (char)('0' + (v / 10u) % 10u); b[1] = (char)('0' + v % 10u); b[2] = 0;
  text_puts(t, row, col, b);
}

static void hud_update(App *a) {
  uint8_t hh, mm, ss;
  dc_hms(a->clk.tick, &hh, &mm, &ss);
  text_clear_bar(&a->text, 1);
  text_puts(&a->text, 1, 1, "TIME ");
  put2(&a->text, 1, 6, hh); text_puts(&a->text, 1, 8, ":");
  put2(&a->text, 1, 9, mm); text_puts(&a->text, 1, 11, ":");
  put2(&a->text, 1, 12, ss);
  // Odometer: 6 base-10 digits, most-significant first.
  uint8_t d[ODO_DIGITS];
  dc_digits(a->clk.odo, d);
  text_puts(&a->text, 1, 18, "ODO ");
  char ob[ODO_DIGITS + 1];
  for (uint8_t k = 0; k < ODO_DIGITS; k++) ob[k] = (char)('0' + d[ODO_DIGITS - 1u - k]);
  ob[ODO_DIGITS] = 0;
  text_puts(&a->text, 1, 22, ob);
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  dc_init(&a->clk);
  text_puts(&a->text, 0, 1, "CONST-DIV CLOCK  /60 /10 /12");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "DIVISION CLOCK", "CONST /60 /10 /12");
  corpus_result = divclock_gate_crc();          // self-verify the constant-divisor math == host 0xF72E
  title_end(&a.screen, &title, 110);
  for (;;) {
    a.clk.tick += TICK_STEP;
    a.clk.odo  += ODO_STEP;
    canvas_clear(&a.canvas);
    draw_frame(&a);
    hud_update(&a);
    display_frame(&a.screen);
  }
}
