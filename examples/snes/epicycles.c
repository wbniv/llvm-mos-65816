// Fourier epicycles on the snesgfx OOP library — #10 of the compiler stress-test demo battery.
//
// Renders the verified, portable epicycle math (examples/65816/epicycles.h — the same header the
// host oracle tools/epicycles-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3),
// so the program builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers → the full 5-way
// bar). A sum of EPI_NHARM rotating vectors (epicycles) traces a baked 5-pointed-star outline: a
// dim scaffold of the nested generating circles is drawn once, then the bright outline draws itself
// stroke by stroke as the chain tip sweeps one period.
//
// Codegen under test: a sin/cos-LUT sweep with FOUR 16×16→32 multiplies per harmonic (__mulsi3 —
// the complex multiply) + 32-bit accumulation per traced point. No 32-bit divide (the spirograph/
// n-body profile) — this is the many-multiply member. corpus_result = epi_gate_crc() == host 0x4F6C.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/drawable.h"
#include "snesgfx/vram.h"
#include "../65816/epicycles.h"

#define CANVAS_CHR  0x0000      // BG3 char base (word) — canvas tiles 0..255 + blank 256 + font 256..
#define CANVAS_MAP  0x4000      // BG3 tilemap base (word)
#define BOX_COL     8           // 16-tile canvas box at cols 8..23  (screen px 64..191)
#define BOX_ROW     6           // rows 6..21 (screen px 48..175)
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define CX         (CANVAS_W / 2)
#define CY         (CANVAS_H / 2)
#define DRAW_STEP   2u          // LUT phase advance per frame (256 frames → one full trace)
#define HOLD_FRAMES 150u        // pause on the finished star before re-blooming

// BG3 2bpp palette (CGRAM 0..3): 0 black bg, 1 dim (scaffold circles), 2 spare, 3 bright (outline).
static const uint16_t bg3_pal[4] = {
    SNES_RGB(0, 0, 0), SNES_RGB(8, 8, 14), SNES_RGB(20, 14, 4), SNES_RGB(10, 28, 31),
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     phase;     // current trace phase (0..EPI_PERIOD)
    int16_t      px, py;    // previous tip (canvas coords)
    uint8_t      started;
    uint16_t     hold;
} App;

volatile uint16_t corpus_result;   // epicycle-math proof channel (read from WRAM by the gate)

// Integer hypotenuse (alpha-max-plus-beta-min ≈; radii are small, scaffold-only).
static uint8_t ihyp(int16_t dx, int16_t dy) {
    uint16_t a = (uint16_t)(dx < 0 ? -dx : dx), b = (uint16_t)(dy < 0 ? -dy : dy);
    if (a < b) { uint16_t t = a; a = b; b = t; }
    return (uint8_t)(a + (b >> 1) - (b >> 3));      // max + 0.375·min
}

// Midpoint circle into the canvas (color c). noinline: bounds register pressure (handoff §4).
__attribute__((noinline))
static void canvas_circle(BitmapCanvas *cv, int16_t cx, int16_t cy, uint8_t rad, uint8_t c) {
    int16_t x = (int16_t)rad, y = 0, err = 0;
    while (x >= y) {
        canvas_plot(cv, (int16_t)(cx + x), (int16_t)(cy + y), c);
        canvas_plot(cv, (int16_t)(cx + y), (int16_t)(cy + x), c);
        canvas_plot(cv, (int16_t)(cx - y), (int16_t)(cy + x), c);
        canvas_plot(cv, (int16_t)(cx - x), (int16_t)(cy + y), c);
        canvas_plot(cv, (int16_t)(cx - x), (int16_t)(cy - y), c);
        canvas_plot(cv, (int16_t)(cx - y), (int16_t)(cy - x), c);
        canvas_plot(cv, (int16_t)(cx + y), (int16_t)(cy - x), c);
        canvas_plot(cv, (int16_t)(cx + x), (int16_t)(cy - y), c);
        y++; err += 1 + 2 * y;
        if (2 * (err - x) + 1 > 0) { x--; err += 1 - 2 * x; }
    }
}

// Draw the dim scaffold: the EPI_NHARM nested generating circles at phase 0 (each epicycle k is a
// circle centred at chain joint k with radius = that vector's length). Shows the "nested circles".
__attribute__((noinline))
static void draw_scaffold(App *a) {
    int16_t jx[EPI_NHARM + 1], jy[EPI_NHARM + 1];
    epi_chain(0u, jx, jy);
    for (uint8_t k = 0; k < EPI_NHARM; k++) {
        uint8_t r = ihyp((int16_t)(jx[k + 1] - jx[k]), (int16_t)(jy[k + 1] - jy[k]));
        if (r >= 2u) canvas_circle(&a->canvas, (int16_t)(CX + jx[k]), (int16_t)(CY - jy[k]), r, 1u);
    }
}

static void hud_pts(App *a) {
    char t[6]; uint8_t m = 0; uint16_t v = a->phase;
    if (!v) t[m++] = '0';
    while (v) { t[m++] = (char)('0' + (uint8_t)(v % 10u)); v /= 10u; }
    char line[20]; uint8_t i = 0;
    const char *q = "N=8 STAR PT "; while (*q) line[i++] = *q++;
    while (m) line[i++] = t[--m];
    line[i] = 0;
    text_clear_bar(&a->text, 1);
    text_puts(&a->text, 1, 0, line);
}

// Restart the bloom on a clean canvas: scaffold + reset the trace.
static void rebloom(App *a) {
    canvas_clear(&a->canvas);
    draw_scaffold(a);
    a->phase = 0u; a->started = 0u; a->hold = 0u;
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    text_puts(&a->text, 0, 8, "FOURIER EPICYCLES");
    rebloom(a);
    hud_pts(a);
}

// Advance one frame of the trace: plot the next outline segment, or hold + re-bloom at the end.
__attribute__((noinline))
static void step_frame(App *a) {
    if (a->phase < EPI_PERIOD) {
        int16_t x, y;
        epi_point((uint8_t)a->phase, &x, &y);
        int16_t qx = (int16_t)(CX + x), qy = (int16_t)(CY - y);
        if (a->started) canvas_line(&a->canvas, a->px, a->py, qx, qy, 3u);
        a->px = qx; a->py = qy; a->started = 1u;
        a->phase = (uint16_t)(a->phase + DRAW_STEP);
        if ((a->phase & 7u) == 0u) hud_pts(a);
    } else if (a->hold < HOLD_FRAMES) {
        a->hold++;
    } else {
        rebloom(a);
        hud_pts(a);
    }
}

int main(void) {
    static App a;
    app_init(&a);

    static TitleLayer title;
    title_begin(&a.screen, &title, "FOURIER", "EPICYCLES");

    corpus_result = epi_gate_crc();          // self-verify epicycle math == host 0x4F6C
    title_end(&a.screen, &title, 100u);           // ~1.7 s title

    for (;;) {
        step_frame(&a);
        display_frame(&a.screen);
    }
}
