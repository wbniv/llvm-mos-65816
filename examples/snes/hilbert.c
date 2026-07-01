// Hilbert curve — demo #28 of the compiler stress-test battery.
//
// Draws a 16×16 (order-4) Hilbert space-filling curve on a 128×128 BitmapCanvas.
// The hot path (hil_d2xy) uses VARIABLE-COUNT 32-bit shifts — the loop variable k
// is NOT a compile-time constant, so LLVM emits __ashlsi3(rx, k) and __ashlsi3(1, k)
// rather than inlining a fixed shift chain (contrast with TEA #30, where constant
// <<4/>>5 get inlined as ASL+ROL).
//
//   for k = 0..ORDER-1:
//     x += rx << k;     // __ashlsi3(rx, k)  — variable-count 32-bit shift
//     y += ry << k;     // __ashlsi3(ry, k)  — variable-count 32-bit shift
//
// Gate also exercises hil_xy2d (inverse) which uses __lshrsi3(x, k) and __lshrsi3(y, k).
// Round-trip verified: hil_xy2d(hil_d2xy(d)) == d for all 256 points.
//
// No far pointers → 5-way differential bar. See docs/plans/2026-06-30-28-snes-hilbert.md.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/m7title.h"
#include "snesgfx/upload.h"
#include "snesgfx/drawable.h"
#include "snesgfx/vram.h"
#include "../65816/hilbert.h"

// BG3 layout
#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 2
#define HUD_BOT_ROW 25

// CELL_PX: each 16×16 grid cell is CELL_PX×CELL_PX canvas pixels (8 = one tile)
#define CELL_PX     8u

// Points drawn per frame and hold time
#define PTS_PER_FRAME  4u
#define N_HOLD         120u

// BG3 2bpp palette (CGRAM[0..3])
//   0=black(bg)  1=near-white(text)  2=cyan(curve)  3=orange(endpoint dots)
static const uint16_t bg3_pal[4] = {
    SNES_RGB(0, 0, 0), SNES_RGB(24, 24, 24),
    SNES_RGB(0, 22, 28), SNES_RGB(28, 14, 0),
};

// -------------------------------------------------------------------------
// HUD
// -------------------------------------------------------------------------

static inline void fmt4(char *buf, uint16_t v) {
    buf[0] = (char)('0' + (uint8_t)(v / 1000u));
    buf[1] = (char)('0' + (uint8_t)((v / 100u) % 10u));
    buf[2] = (char)('0' + (uint8_t)((v / 10u) % 10u));
    buf[3] = (char)('0' + (uint8_t)(v % 10u));
}

// -------------------------------------------------------------------------
// App state
// -------------------------------------------------------------------------

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     d_next;     // next Hilbert index to draw (0..HILBERT_NPTS)
    uint16_t     hold;       // hold countdown after full curve drawn
    int16_t      prev_px;   // previous canvas pixel (for line drawing)
    int16_t      prev_py;
    uint8_t      started;    // first point drawn?
} App;

volatile uint16_t corpus_result;

// Convert Hilbert (x,y) in [0,15]² to canvas pixel center
static inline int16_t hil_to_px(uint32_t v) {
    return (int16_t)((uint16_t)v * (uint16_t)CELL_PX + (uint16_t)(CELL_PX / 2u));
}

__attribute__((noinline))
static void draw_pts(App *a, uint16_t n) {
    for (uint16_t c = 0; c < n && a->d_next < (uint16_t)HILBERT_NPTS; c++, a->d_next++) {
        uint32_t x, y;
        hil_d2xy((uint32_t)a->d_next, &x, &y);
        int16_t px = hil_to_px(x), py = hil_to_px(y);
        if (a->started)
            canvas_line(&a->canvas, a->prev_px, a->prev_py, px, py, 2);
        // draw endpoint dot
        canvas_plot(&a->canvas, px, py, 3);
        a->prev_px = px; a->prev_py = py; a->started = 1;
    }
}

static void hud_top(App *a) {
    char line[32] = "#28 HILBERT CURVE   D:    ";
    fmt4(line + 22, a->d_next < (uint16_t)HILBERT_NPTS ? a->d_next : (uint16_t)HILBERT_NPTS);
    text_clear_bar(&a->text, 0);
    text_puts(&a->text, 0, 0, line);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->d_next  = 0;
    a->hold    = 0;
    a->started = 0;
}

int main(void) {
    m7splash_begin("HILBERT CURVE", "SPACE-FILLING");
    corpus_result = hilbert_gate_crc();   /* runs during hold; screen shows last frame */
    m7splash_end(90);

    static App a;
    app_init(&a);   /* display_init wipes Mode 7 state; re-uploads BGMODE_1 content */

    text_clear_bar(&a.text, 1);
    text_puts(&a.text, 1, 0, "ORDER:4  256 PTS  ASHLSI3");

    hud_top(&a);

    for (;;) {
        if (a.d_next < (uint16_t)HILBERT_NPTS) {
            draw_pts(&a, PTS_PER_FRAME);
            hud_top(&a);
        } else {
            a.hold++;
            if (a.hold >= (uint16_t)N_HOLD) {
                canvas_clear(&a.canvas);
                a.d_next  = 0;
                a.hold    = 0;
                a.started = 0;
                hud_top(&a);
            }
        }
        display_frame(&a.screen);
    }
}
