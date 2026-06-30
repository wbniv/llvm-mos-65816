// Times-table cardioid — demo #27 of the compiler stress-test battery.
//
// Plots all N=200 chord segments for each multiplier k (2..30): chord from circle point i
// to circle point (k*i)%N.  k=2 → cardioid, k=3 → nephroid, higher k → epicycloid envelopes.
// The hot inner loop folds (uint32_t)k*(uint32_t)i % (uint32_t)N, forcing __mulsi3 +
// __umodsi3 even though k*i < 6000 fits in 16 bits (explicit casts prevent 16-bit paths).
//
// No far pointers → builds default AND +mos-a16 AND +mos-xy16 → 5-way differential bar.
// See docs/plans/2026-06-30-27-snes-cardioid.md.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/drawable.h"
#include "snesgfx/vram.h"
#include "../65816/spiro.h"       // SPIRO_SIN_LUT for circle precomputation
#include "../65816/cardioid.h"    // CARD_N, CARD_R, CARD_CX, CARD_CY, card_gate_crc()

// BG3 layout — shared between BitmapCanvas and TextLayer
#define CANVAS_CHR  0x0000u   // BG3 chr base word: canvas tiles 0..255 then font at 256
#define CANVAS_MAP  0x4000u   // BG3 tilemap base word
#define BOX_COL     8         // canvas at tile cols 8..23 (px 64..191)
#define BOX_ROW     6         // canvas at tile rows 6..21 (px 48..175)
#define HUD_TOP_ROW 2
#define HUD_BOT_ROW 25

// Animation pacing
#define CHORDS_PER_FRAME 10u  // chords drawn per frame during the bloom phase
#define N_HOLD           40u  // frames to hold the finished figure before advancing k

// BG3 2bpp palette (CGRAM[0..3]):
//   0 = black (background)   1 = near-white (text ink, font plane-1)
//   2 = orange (chords)      3 = cyan (endpoint dots)
static const uint16_t bg3_pal[4] = {
    SNES_RGB(0, 0, 0), SNES_RGB(24, 24, 24),
    SNES_RGB(28, 14, 0), SNES_RGB(0, 20, 28),
};

// -------------------------------------------------------------------------
// Number formatting helpers
// -------------------------------------------------------------------------

// Write 2-digit zero-padded decimal of v (0..99) into buf[2]; no NUL.
static inline void fmt2(char *buf, uint8_t v) {
    buf[0] = (char)('0' + (uint8_t)(v / 10u));
    buf[1] = (char)('0' + (uint8_t)(v % 10u));
}

// Write 3-digit zero-padded decimal of v (0..999) into buf[3]; no NUL.
static inline void fmt3(char *buf, uint16_t v) {
    buf[0] = (char)('0' + (uint8_t)(v / 100u));
    buf[1] = (char)('0' + (uint8_t)((v / 10u) % 10u));
    buf[2] = (char)('0' + (uint8_t)(v % 10u));
}

// -------------------------------------------------------------------------
// Application state
// -------------------------------------------------------------------------

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    int16_t      pts_x[CARD_N];   // precomputed circle points (canvas coords)
    int16_t      pts_y[CARD_N];
    uint16_t     k;               // current multiplier (CARD_KMIN..CARD_KMAX)
    uint16_t     chord;           // next chord index to draw (0..CARD_N)
    uint16_t     hold;            // hold-phase countdown
    uint16_t     k_idx;           // 0-based (k - CARD_KMIN), 0..28
} App;

volatile uint16_t corpus_result;  // gate proof channel (read from WRAM by dev/cardioid.sh)

// -------------------------------------------------------------------------
// Circle precomputation  (uses SPIRO_SIN_LUT from spiro.h)
// -------------------------------------------------------------------------

static void precompute_pts(App *a) {
    for (uint16_t i = 0; i < (uint16_t)CARD_N; i++) {
        // Angle a ∈ [0, 256): step = 256/200 = 1.28 per point
        uint8_t ang = (uint8_t)((uint32_t)i * 256u / (uint32_t)CARD_N);
        a->pts_x[i] = (int16_t)(CARD_CX
            + (int16_t)((int32_t)CARD_R * SPIRO_COS(ang) >> 8));
        a->pts_y[i] = (int16_t)(CARD_CY
            - (int16_t)((int32_t)CARD_R * SPIRO_SIN(ang) >> 8));
    }
}

// -------------------------------------------------------------------------
// HUD rendering
// -------------------------------------------------------------------------

static void hud_top(App *a) {
    // "#27 CARDIOID  k=NN    [NN/29]"
    char line[32] = "#27 CARDIOID  k=  " "   [  /29]";
    fmt2(line + 16, (uint8_t)a->k);
    uint8_t idx1 = (uint8_t)(a->k_idx + 1u);
    fmt2(line + 23, idx1);
    text_clear_bar(&a->text, 0);
    text_puts(&a->text, 0, 0, line);
}

static void hud_bot(App *a) {
    // "N=200  CHORDS:NNN  (K*I)%N"
    char line[32] = "N=200  CHORDS:   " "  (K*I)%N";
    fmt3(line + 14, a->chord < (uint16_t)CARD_N ? a->chord : (uint16_t)CARD_N);
    text_clear_bar(&a->text, 1);
    text_puts(&a->text, 1, 0, line);
}

// -------------------------------------------------------------------------
// Chord drawing  (noinline to bound register-allocator pressure under +mos-a16)
// -------------------------------------------------------------------------

__attribute__((noinline))
static void draw_chords(App *a, uint16_t n) {
    for (uint16_t c = 0; c < n && a->chord < (uint16_t)CARD_N; c++, a->chord++) {
        uint32_t j = (uint32_t)a->k * (uint32_t)a->chord % (uint32_t)CARD_N;
        canvas_line(&a->canvas,
                    a->pts_x[a->chord], a->pts_y[a->chord],
                    a->pts_x[j],        a->pts_y[j],
                    2);   // color 2 = orange
    }
}

// -------------------------------------------------------------------------
// Advance to next k (clear canvas, reset draw state)
// -------------------------------------------------------------------------

static void next_k(App *a) {
    a->k_idx++;
    if (a->k_idx >= (uint16_t)(CARD_KMAX - CARD_KMIN + 1u))
        a->k_idx = 0;
    a->k = (uint16_t)(CARD_KMIN + a->k_idx);
    a->chord = 0;
    a->hold  = 0;
    canvas_clear(&a->canvas);
}

// -------------------------------------------------------------------------
// Init and main
// -------------------------------------------------------------------------

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);

    precompute_pts(a);

    a->k     = CARD_KMIN;
    a->k_idx = 0;
    a->chord = 0;
    a->hold  = 0;

    hud_top(a);
    hud_bot(a);
}

int main(void) {
    static App a;
    app_init(&a);

    static TitleLayer title;
    title_begin(&a.screen, &title, "CARDIOID", "TIMES TABLE");

    corpus_result = card_gate_crc();

    title_end(&a.screen, &title, 90);

    for (;;) {
        if (a.chord < (uint16_t)CARD_N) {
            // Bloom phase: draw CHORDS_PER_FRAME chords this frame
            draw_chords(&a, CHORDS_PER_FRAME);
            hud_bot(&a);
        } else {
            // Hold phase: countdown, then advance k
            a.hold++;
            if (a.hold >= N_HOLD) {
                next_k(&a);
                hud_top(&a);
                hud_bot(&a);
            }
        }
        display_frame(&a.screen);
    }
}
