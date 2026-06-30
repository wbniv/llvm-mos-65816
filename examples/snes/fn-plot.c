// fn-plot — Recursive-descent float function plotter, #24 compiler stress-test demo.
//
// Parses four baked expressions with a recursive-descent parser, evaluates each at
// 128 x-values using soft-float arithmetic, and plots the curve on a BitmapCanvas.
// Consecutive pixels are joined by canvas_line() so steep curves have no gaps.
// Cycles through all four expressions automatically with an animated title intro.
//
// Codegen stress:
//   Recursive call graph: fn_eval_expr → fn_eval_term → fn_eval_factor → fn_eval_expr
//   (for parenthesised subexpressions) — up to 7 levels deep; exercises the soft-stack ABI.
//   Soft-float libcalls: __mulsf3 (x*x), __subsf3 (y-0.5), __divsf3 (x/(…)),
//   __addsf3, __fixsfsi (float→int pixel mapping), __floatsisf (int→float for xi).
//
// No far pointers → builds default-8-bit AND +mos-a16 AND +mos-xy16
// → full 5-way differential bar.
//
// See docs/plans/2026-06-30-24-snes-fn-plot.md.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/drawable.h"
#include "snesgfx/vram.h"
#include "../65816/fn_plot.h"

// ─── VRAM layout ────────────────────────────────────────────────────────────
#define CANVAS_CHR  0x0000u   // BG3 chr base: tiles 0..255 canvas, 256 blank, 257+ font
#define CANVAS_MAP  0x4000u   // BG3 tilemap base
#define BOX_COL     8u        // canvas centred: (32-16)/2 = 8
#define BOX_ROW     6u        // canvas centred: (28-16)/2 = 6
#define HUD_TOP_ROW 2u        // TextLayer bar 0 (above canvas)
#define HUD_BOT_ROW 25u       // TextLayer bar 1 (below canvas)

// ─── BG3 2bpp palette ───────────────────────────────────────────────────────
static const uint16_t bg3_pal[4] = {
    SNES_RGB( 0,  0,  0),   // 0: black background
    SNES_RGB(28, 28, 28),   // 1: near-white (curve + text)
    SNES_RGB(10, 10, 10),   // 2: dim gray (unused)
    SNES_RGB( 0, 24, 28),   // 3: cyan (unused)
};

// Draw 2 pixels/frame. Each evaluation: ~6 000–18 000 cycles depending on expression.
// 2 × worst-case ≈ 36 000 < 44 667 NTSC budget. Takes 64 frames (~1 s) per curve.
#define PIXELS_PER_FRAME 2u

// Pause frames between expressions (≈4 seconds)
#define PAUSE_FRAMES 240u

// Short display names padded to 16 chars
static const char * const fn_names[] = {
    "y=x*x-0.5      ",
    "y=x*x*x-x      ",
    "y=x/(x*x+1.0)  ",
    "y=x*x*x*x-x*x  ",
};

// ─── Number formatter (3 digits, leading zeros) ──────────────────────────────
static void fmt3(char *dst, uint16_t v) {
    dst[0] = (char)('0' + (uint8_t)(v / (uint16_t)100));
    dst[1] = (char)('0' + (uint8_t)((v / (uint16_t)10) % (uint16_t)10));
    dst[2] = (char)('0' + (uint8_t)(v % (uint16_t)10));
    dst[3] = 0;
}

// ─── App state ───────────────────────────────────────────────────────────────
typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint8_t      expr_idx;     // current expression (0..FN_NEXPR-1)
    uint16_t     cur_px;       // next pixel column to draw (0..127; ≥128 = done)
    uint16_t     pause_timer;  // frames spent pausing after curve complete
    int16_t      prev_py;      // canvas row of the previous column (-1 = none)
} App;

// ─── App init ────────────────────────────────────────────────────────────────
static void app_init(App *a) {
    display_init(&a->screen);

    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);

    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->text);

    a->expr_idx   = 0;
    a->cur_px     = 0;
    a->pause_timer = 0;
    a->prev_py    = -1;

    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint16_t)sizeof bg3_pal);
}

// ─── HUD update ──────────────────────────────────────────────────────────────
static void hud_update(App *a) {
    char buf[21];   // max use: 20-char progress bar + NUL

    // Top row: "FN-PLOT  y=x*x-0.5       [1/4]"
    text_clear_bar(&a->text, 0);
    text_puts(&a->text, 0, 0, "FN-PLOT  ");
    text_puts(&a->text, 0, 9, fn_names[a->expr_idx]);
    buf[0] = '[';
    buf[1] = (char)('1' + (char)a->expr_idx);
    buf[2] = '/';
    buf[3] = '4';
    buf[4] = ']';
    buf[5] = 0;
    text_puts(&a->text, 0, 26, buf);

    // Bottom row: "PX:NNN  [====================]"
    text_clear_bar(&a->text, 1);
    text_puts(&a->text, 1, 0, "PX:");
    fmt3(buf, (a->cur_px < (uint16_t)CANVAS_W) ? a->cur_px : (uint16_t)CANVAS_W);
    text_puts(&a->text, 1, 3, buf);
    text_puts(&a->text, 1, 7, "[");
    uint8_t filled = (a->cur_px >= (uint16_t)CANVAS_W) ? 20u :
                     (uint8_t)(((uint16_t)a->cur_px * 20u) / (uint16_t)CANVAS_W);
    uint8_t i;
    for (i = 0; i < 20u; i++) buf[i] = (i < filled) ? '=' : ' ';
    buf[20] = 0;
    text_puts(&a->text, 1, 8, buf);
    text_puts(&a->text, 1, 28, "]");
}

// ─── Plot one pixel column, connecting to the previous column ─────────────────
static void plot_column(App *a, uint16_t px) {
    // xi in [-2.0, 2.0), step = 4/128 = 0.03125
    float xi = -2.0f + (float)px * 0.03125f;         /* __floatsisf, __mulsf3, __addsf3 */
    float yi = fn_eval(a->expr_idx, xi);              /* recursive-descent soft-float */
    // Map y in [-2, 2] → canvas row [0, 127]: py = (2.0 - yi) * 32
    int16_t py = (int16_t)((2.0f - yi) * 32.0f);     /* __subsf3, __mulsf3, __fixsfsi */

    if (py >= 0 && py < (int16_t)CANVAS_H) {
        if (a->prev_py >= 0 && a->prev_py < (int16_t)CANVAS_H && px > 0u) {
            // Connect to previous column: fills gaps on steep sections
            canvas_line(&a->canvas, (int16_t)(px - 1u), a->prev_py,
                        (int16_t)px, py, (uint8_t)1u);
        } else {
            canvas_plot(&a->canvas, (int16_t)px, py, (uint8_t)1u);
        }
    }
    a->prev_py = py;
}

// ─── corpus_result (gate anchor) ─────────────────────────────────────────────
volatile uint16_t corpus_result;

// ─── Main ────────────────────────────────────────────────────────────────────
int main(void) {
    static App a;
    app_init(&a);

    // Title intro card — shown while the gate CRC computes.
    // Must be added AFTER all demo drawables and BEFORE any demo HDMA.
    static TitleLayer title;
    title_begin(&a.screen, &title, "FN-PLOT", "RECURSIVE PARSER");

    // Gate CRC: evaluates fn_exprs[0] at 64 points — runs in ~9 frames during title.
    corpus_result = fn_gate_crc();

    // Hold the title ~1.5 s then fade out into the demo.
    title_end(&a.screen, &title, 90);

    hud_update(&a);

    for (;;) {
        if (a.cur_px < (uint16_t)CANVAS_W) {
            // Draw PIXELS_PER_FRAME columns left-to-right, connected by lines
            uint8_t k;
            for (k = 0; k < (uint8_t)PIXELS_PER_FRAME; k++) {
                if (a.cur_px >= (uint16_t)CANVAS_W) break;
                plot_column(&a, a.cur_px);
                a.cur_px++;
            }
            hud_update(&a);
        } else {
            // Curve complete — pause, then switch to next expression
            a.pause_timer++;
            if (a.pause_timer >= (uint16_t)PAUSE_FRAMES) {
                canvas_clear(&a.canvas);
                a.expr_idx    = (uint8_t)((uint8_t)(a.expr_idx + 1u) % (uint8_t)FN_NEXPR);
                a.cur_px      = 0;
                a.pause_timer = 0;
                a.prev_py     = -1;
            }
            hud_update(&a);
        }

        display_frame(&a.screen);
    }
}
