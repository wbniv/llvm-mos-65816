// Width-Sweep Sort Gallery — #97 of the compiler stress-test battery (Round 6, Cluster B).
// The gate (examples/65816/spaceship.h) qsorts int8/int16/int32/int64 panels with spaceship
// comparators (a>b)-(a<b), forcing G_SCMP at s16/s32/s64 → lowerThreewayCompare (patch 0016).
// Builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers → full 5-way bar).
//
// Visual: four bar-chart panels sort in lockstep (one bubble pass/frame), each comparison the
// spaceship sign. When a panel is sorted it reshuffles. Distinct from #46 qsortviz (single width,
// scatter viz) — this sweeps the comparison WIDTH, the s32/s64 legs qsortviz never reached.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/spaceship.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4

#define PANELS   4u
#define BARS     16u    // bars per panel (permutation of 0..15)
#define PW       32     // panel width in pixels (4 tiles)
#define BARH     8      // bar band height in pixels (16 bars × 8 = 128)

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 1,  1,  6),    // 0: background
    SNES_RGB( 6, 22, 30),    // 1: cyan bars
    SNES_RGB(30, 16,  4),    // 2: orange bars
    SNES_RGB(26, 28, 10),    // 3: lime bars
};

typedef struct { int16_t v[BARS]; uint16_t rng; } BarPanel;

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    BarPanel     panel[PANELS];
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

// Spaceship comparator on display values (forces G_SCMP s16 on the render path too).
static inline int16_t sp_sign(int16_t a, int16_t b) { return (int16_t)((a > b) - (a < b)); }

static void panel_shuffle(BarPanel *p) {
    for (uint16_t i = 0u; i < (uint16_t)BARS; i++) p->v[i] = (int16_t)i;
    // Fisher-Yates with the panel LCG.
    for (uint16_t i = (uint16_t)BARS - 1u; i > 0u; i--) {
        p->rng = (uint16_t)(p->rng * 25173u + 13849u);
        uint16_t j = (uint16_t)(p->rng % (uint16_t)(i + 1u));
        int16_t tmp = p->v[i]; p->v[i] = p->v[j]; p->v[j] = tmp;
    }
}

// One bubble pass; returns 1 if already sorted (no swaps).
static uint8_t panel_pass(BarPanel *p) {
    uint8_t sorted = 1u;
    for (uint16_t i = 0u; i + 1u < (uint16_t)BARS; i++) {
        if (sp_sign(p->v[i], p->v[i + 1u]) > (int16_t)0) {
            int16_t tmp = p->v[i]; p->v[i] = p->v[i + 1u]; p->v[i + 1u] = tmp;
            sorted = 0u;
        }
    }
    return sorted;
}

static void draw_panel(BitmapCanvas *cv, uint8_t pi, const BarPanel *p) {
    int16_t x0 = (int16_t)((uint16_t)pi * (uint16_t)PW);
    uint8_t color = (uint8_t)((pi % 3u) + 1u);
    for (uint16_t b = 0u; b < (uint16_t)BARS; b++) {
        int16_t y0 = (int16_t)((uint16_t)b * (uint16_t)BARH);
        int16_t len = (int16_t)((uint16_t)((uint16_t)p->v[b] * 2u));   // 0..30 px
        for (int16_t yy = y0; yy < (int16_t)(y0 + 6); yy++) {
            for (int16_t xx = x0; xx < (int16_t)(x0 + len); xx++)
                canvas_plot(cv, xx, yy, color);
            for (int16_t xx = (int16_t)(x0 + len); xx < (int16_t)(x0 + PW - 1); xx++)
                canvas_plot(cv, xx, yy, 0u);
        }
    }
    cv->lo = (uint16_t)0u;
    cv->hi = (uint16_t)(CANVAS_NTILES - 1u);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    for (uint8_t p = 0u; p < (uint8_t)PANELS; p++) {
        a->panel[p].rng = (uint16_t)(0x1111u * (uint16_t)(p + 1u) + 7u);
        panel_shuffle(&a->panel[p]);
    }
    a->t = (uint16_t)0u;
    text_puts(&a->text, 0, 2, "SPACESHIP  G_SCMP s64");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "SPACESHIP", "G_SCMP s8/16/32/64");
    corpus_result = spaceship_gate_crc();   // expected 0xF20F
    title_end(&a.screen, &title, 90);
    for (;;) {
        a.t++;
        for (uint8_t p = 0u; p < (uint8_t)PANELS; p++) {
            if (panel_pass(&a.panel[p])) panel_shuffle(&a.panel[p]);
            draw_panel(&a.canvas, p, &a.panel[p]);
        }
        display_frame(&a.screen);
    }
}
