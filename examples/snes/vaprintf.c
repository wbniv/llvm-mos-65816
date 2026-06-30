// Variadic formatter (va_arg) — demo #32 of the compiler stress-test battery.
//
// Draws a Lissajous curve on a 128×128 BitmapCanvas, with parameters FX/FY
// cycled automatically. Each frame formats the HUD via mini_sprintf():
//   mini_sprintf(line, "#32 VA_ARG  FX=%u FY=%u", fx, fy);
// — the va_arg calls exercise the variadic calling convention on the 65816.
//
// On the target (16-bit int), va_arg(ap, unsigned int) reads 2 bytes from the
// soft-stack argument area. On x86 host (32-bit int), it reads 4 bytes. The gate
// CRC passes small values (< 1000) that are identical in both widths → bit-exact
// host == default == +mos-a16 == +mos-xy16 (no far pointers → 5-way bar).
//
// Coverage map: "variadic va_arg — the stack-walking calling convention". No other
// demo in the battery calls a variadic function.
//
// See docs/plans/2026-06-30-32-snes-vaprintf.md.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/drawable.h"
#include "snesgfx/vram.h"
#include "../65816/spiro.h"
#include "../65816/vaprintf.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 2
#define HUD_BOT_ROW 25

#define LISSA_R     56u     /* radius (canvas pixels) */
#define LISSA_CX    64      /* centre X on 128px canvas */
#define LISSA_CY    64      /* centre Y */
#define PTS_PER_FRAME 6u    /* curve points drawn per frame */
#define N_HOLD      120u    /* frames before advancing to next (fx,fy) pair */

// Lissajous parameter pairs to cycle through
#define NPAIRS 6u
static const uint8_t PAIRS_FX[NPAIRS] = { 1, 2, 3, 2, 4, 3 };
static const uint8_t PAIRS_FY[NPAIRS] = { 2, 3, 4, 5, 5, 2 };

// BG3 palette: 0=black, 1=white(text), 2=orange(curve), 3=cyan(dot)
static const uint16_t bg3_pal[4] = {
    SNES_RGB(0, 0, 0), SNES_RGB(24, 24, 24),
    SNES_RGB(28, 14, 0), SNES_RGB(0, 22, 28),
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint8_t      pair;    // current (fx,fy) pair index
    uint16_t     t;       // phase counter (0..255 = one full cycle)
    uint16_t     hold;    // frame counter
    int16_t      prev_x, prev_y;
    uint8_t      started;
} App;

volatile uint16_t corpus_result;

// Compute Lissajous point for parameter t (0..255 = 2π)
static void lissa_pt(uint8_t fx, uint8_t fy, uint8_t t, int16_t *px, int16_t *py) {
    *px = (int16_t)(LISSA_CX + (int16_t)((int32_t)LISSA_R * SPIRO_SIN((uint8_t)((uint16_t)t * fx + 64u)) >> 8));
    *py = (int16_t)(LISSA_CY - (int16_t)((int32_t)LISSA_R * SPIRO_SIN((uint8_t)((uint16_t)t * fy      )) >> 8));
}

__attribute__((noinline))
static void draw_pts(App *a, uint8_t fx, uint8_t fy, uint16_t n) {
    for (uint16_t c = 0; c < n; c++) {
        int16_t x, y;
        lissa_pt(fx, fy, (uint8_t)a->t, &x, &y);
        if (a->started)
            canvas_line(&a->canvas, a->prev_x, a->prev_y, x, y, 2);
        canvas_plot(&a->canvas, x, y, 3);
        a->prev_x = x; a->prev_y = y; a->started = 1;
        a->t = (uint16_t)(a->t + 1u);
        if (a->t >= 256u) a->t = 0u;
    }
}

static void hud_update(App *a) {
    uint8_t fx = PAIRS_FX[a->pair], fy = PAIRS_FY[a->pair];
    char line[32];
    // TOP row — va_arg for fx and fy
    mini_sprintf(line, "#32 VA ARG  FX=%u FY=%u", (unsigned)fx, (unsigned)fy);
    text_clear_bar(&a->text, 0);
    text_puts(&a->text, 0, 0, line);
    // BOTTOM row — va_arg for pair index and hold counter
    mini_sprintf(line, "PAIR %u/%u  T=%u", (unsigned)(a->pair + 1u),
                 (unsigned)NPAIRS, (unsigned)(a->t));
    text_clear_bar(&a->text, 1);
    text_puts(&a->text, 1, 0, line);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->pair    = 0u;
    a->t       = 0u;
    a->hold    = 0u;
    a->started = 0u;
}

int main(void) {
    static App a;
    app_init(&a);

    static TitleLayer title;
    title_begin16(&a.screen, &title, "VA_ARG", "LISSAJOUS");

    corpus_result = vaprintf_gate_crc();

    title_end(&a.screen, &title, 90);

    hud_update(&a);

    for (;;) {
        uint8_t fx = PAIRS_FX[a.pair], fy = PAIRS_FY[a.pair];
        draw_pts(&a, fx, fy, PTS_PER_FRAME);
        hud_update(&a);

        a.hold++;
        if (a.hold >= (uint16_t)N_HOLD) {
            canvas_clear(&a.canvas);
            a.pair = (uint8_t)((a.pair + 1u) % (uint8_t)NPAIRS);
            a.hold    = 0u;
            a.t       = 0u;
            a.started = 0u;
        }

        display_frame(&a.screen);
    }
}
