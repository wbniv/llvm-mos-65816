// FFT spectrum analyser — demo #25 of the compiler stress-test battery.
//
// 32-point DIT FFT on a synthesised tone; displays 16 frequency bars on a
// 128×128 BitmapCanvas. The tone's frequency sweeps bin 1→15 automatically,
// so the tallest bar marches from left to right across the spectrum.
//
// Hot path: butterfly twiddle multiply — 4× __mulsi3 per butterfly × 16 butterflies
// × 5 stages = 320 __mulsi3 calls per FFT frame.  Also exercises bit-reversal
// permutation (new corner: "bit-reversal/interleave permutation" in the coverage map).
//
// No far pointers → 5-way differential bar. See docs/plans/2026-06-30-25-snes-fft.md.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/drawable.h"
#include "snesgfx/vram.h"
#include "../65816/fft.h"
#include "../65816/spiro.h"   // SPIRO_SIN_LUT for signal synthesis

// BG3 layout
#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 2
#define HUD_BOT_ROW 25

#define BAR_W       8u     // pixels per bar (16 bars × 8 px = 128 px)
#define BAR_SCALE   4u     // divide Q8.8 magnitude by this for bar height
#define N_HOLD      60u    // frames per tone before advancing to next bin
#define NBINS       (FFT_N / 2u)  // 16 display bins

// BG3 palette: 0=black, 1=white(text), 2=green(bars), 3=cyan(peak)
static const uint16_t bg3_pal[4] = {
    SNES_RGB(0, 0, 0), SNES_RGB(24, 24, 24),
    SNES_RGB(4, 24, 8), SNES_RGB(0, 24, 24),
};

// -------------------------------------------------------------------------
// App state
// -------------------------------------------------------------------------

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint8_t      cur_bin;   // current tone frequency bin (1..15)
    uint8_t      phase;     // LUT phase offset for animation
    uint16_t     hold;      // frame counter before advancing bin
    int16_t      bar_h[NBINS];  // last drawn bar heights (for erase)
} App;

volatile uint16_t corpus_result;

// -------------------------------------------------------------------------
// Signal synthesis and FFT bar computation
// -------------------------------------------------------------------------

// Generate signal: pure tone at cur_bin cycles in N samples.
// x[i] = SPIRO_SIN(phase + i * cur_bin * (256/FFT_N))
static void gen_signal(int16_t xr[FFT_N], int16_t xi[FFT_N], uint8_t freq_bin, uint8_t ph) {
    uint8_t step = (uint8_t)(freq_bin * (uint8_t)(256u / FFT_N));
    for (uint8_t i = 0u; i < (uint8_t)FFT_N; i++) {
        xr[i] = (int16_t)(SPIRO_SIN((uint8_t)(ph + (uint8_t)((uint8_t)i * step))));
        xi[i] = 0;
    }
}

// Compute bar heights from FFT output: |re| + |im| (Manhattan approx) >> BAR_SCALE
static void compute_bars(const int16_t xr[FFT_N], const int16_t xi[FFT_N],
                         int16_t bar[NBINS]) {
    for (uint8_t b = 0u; b < (uint8_t)NBINS; b++) {
        int16_t r = xr[b]; if (r < 0) r = (int16_t)-r;
        int16_t m = xi[b]; if (m < 0) m = (int16_t)-m;
        int16_t mag = (int16_t)(r + m);
        mag >>= (uint8_t)BAR_SCALE;
        if (mag > (int16_t)(CANVAS_H - 1)) mag = (int16_t)(CANVAS_H - 1);
        bar[b] = mag;
    }
}

// -------------------------------------------------------------------------
// Bar rendering (erase old, draw new)
// -------------------------------------------------------------------------

__attribute__((noinline))
static void draw_bars(BitmapCanvas *c, const int16_t old_h[NBINS],
                      const int16_t new_h[NBINS]) {
    for (uint8_t b = 0u; b < (uint8_t)NBINS; b++) {
        int16_t x0 = (int16_t)((uint16_t)b * BAR_W);
        int16_t oh = old_h[b], nh = new_h[b];
        // Erase old bar top (pixels that are now above the new height)
        if (oh > nh) {
            for (int16_t y = (int16_t)(CANVAS_H - 1 - oh);
                 y < (int16_t)(CANVAS_H - nh); y++) {
                for (uint8_t dx = 0u; dx < BAR_W; dx++)
                    canvas_plot(c, (int16_t)(x0 + dx), y, 0);  // can't erase...
            }
        }
        // Draw new bar (all pixels from bottom to new height)
        for (int16_t y = (int16_t)(CANVAS_H - 1 - nh);
             y < (int16_t)CANVAS_H; y++) {
            uint8_t color = (b == 0u || b == NBINS - 1u) ? 3u : 2u;  // top cap = cyan
            for (uint8_t dx = 0u; dx < BAR_W; dx++)
                canvas_plot(c, (int16_t)(x0 + dx), y, color);
        }
    }
}

// -------------------------------------------------------------------------
// HUD
// -------------------------------------------------------------------------

static inline void fmt2(char *buf, uint8_t v) {
    buf[0] = (char)('0' + (uint8_t)(v / 10u));
    buf[1] = (char)('0' + (uint8_t)(v % 10u));
}

static void hud_top(App *a) {
    char line[32] = "#25 FFT SPECTRUM   BIN:  ";
    fmt2(line + 23, a->cur_bin);
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
    a->cur_bin = 1u;
    a->phase   = 0u;
    a->hold    = 0u;
    for (uint8_t i = 0u; i < (uint8_t)NBINS; i++) a->bar_h[i] = 0;
}

int main(void) {
    static App a;
    app_init(&a);

    text_clear_bar(&a.text, 1);
    text_puts(&a.text, 1, 0, "N=32  5 STAGES  MULSI3×320");

    static TitleLayer title;
    title_begin(&a.screen, &title, "FFT SPECTRUM", "RADIX-2 DIT");

    corpus_result = fft_gate_crc();

    title_end(&a.screen, &title, 90);

    hud_top(&a);

    // Static buffers in BSS (avoid soft-stack pressure)
    static int16_t xr[FFT_N], xi[FFT_N];
    static int16_t new_bars[NBINS];

    // Draw the first bin immediately
    gen_signal(xr, xi, a.cur_bin, 0);
    fft_run(xr, xi);
    compute_bars(xr, xi, new_bars);
    canvas_clear(&a.canvas);
    for (uint8_t b = 0u; b < (uint8_t)NBINS; b++) {
        int16_t h = new_bars[b];
        if (h <= 0) continue;
        int16_t x0 = (int16_t)((uint16_t)b * (uint16_t)BAR_W);
        uint8_t color = (h > 96) ? 3u : 2u;
        for (int16_t y = (int16_t)(CANVAS_H - h); y < (int16_t)CANVAS_H; y++)
            for (uint8_t dx = 0u; dx < (uint8_t)BAR_W; dx++)
                canvas_plot(&a.canvas, (int16_t)(x0 + (int16_t)dx), y, color);
    }

    for (;;) {
        // Run FFT every frame for the compiler stress test (corpus_result proved
        // correctness at startup; the gate CRC ran during the title animation).
        // We still compute the spectrum here so the multiply hot-path runs continuously.
        gen_signal(xr, xi, a.cur_bin, a.phase);
        fft_run(xr, xi);
        a.phase = (uint8_t)(a.phase + 4u);

        a.hold++;
        if (a.hold >= (uint16_t)N_HOLD) {
            // Advance bin: recompute bars + redraw canvas.
            // canvas_clear marks all 256 tiles dirty; emit flushes 64/frame → 4 frames
            // to complete. N_HOLD=60 >> 4, so the full canvas is visible before next change.
            a.cur_bin = (uint8_t)(a.cur_bin < (uint8_t)(NBINS - 1u) ? a.cur_bin + 1u : 1u);
            a.hold    = 0u;
            compute_bars(xr, xi, new_bars);
            canvas_clear(&a.canvas);
            for (uint8_t b = 0u; b < (uint8_t)NBINS; b++) {
                int16_t h = new_bars[b];
                if (h <= 0) continue;
                int16_t x0 = (int16_t)((uint16_t)b * (uint16_t)BAR_W);
                uint8_t color = (h > 96) ? 3u : 2u;
                for (int16_t y = (int16_t)(CANVAS_H - h); y < (int16_t)CANVAS_H; y++)
                    for (uint8_t dx = 0u; dx < (uint8_t)BAR_W; dx++)
                        canvas_plot(&a.canvas, (int16_t)(x0 + (int16_t)dx), y, color);
            }
            hud_top(&a);
        }

        display_frame(&a.screen);
    }
}
