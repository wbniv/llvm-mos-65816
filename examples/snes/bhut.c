// Barnes-Hut quadtree galaxy — demo #31 of the compiler stress-test battery.
//
// N-body gravity simulation using a Barnes-Hut quadtree: each step rebuilds a
// pooled-node quadtree (bh_insert, recursive) and walks it per particle to
// approximate forces (bh_force, recursive). Particles render as star dots on a
// 128×128 BitmapCanvas; their trails trace the galaxy collapse.
//
// The codegen corner: "pointer-chasing dynamic trees" — bh_insert and bh_force
// follow runtime child[q] indices through bh_pool[], generating ZP-indexed
// indirect loads and a tree-shaped recursive call graph (JSR to self), distinct
// from #13's flat-array N-body and #17/#18's linear/log recursion. Combined with
// __mulsi3 (dx², force) and __divsi3 (force/dist²) from the gravity kernel.
//
// No far pointers → 5-way differential bar. See docs/plans/2026-06-30-31-snes-bhut.md.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/drawable.h"
#include "snesgfx/vram.h"
#include "../65816/bhut.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 2
#define HUD_BOT_ROW 25

#define RESET_STEPS 600u   // steps before re-seeding the galaxy (long enough that the
                           // frame-500 gate snapshot shows accumulated trails, not a reset)

// BG3 palette: 0=black, 1=white(text), 2=cyan(trails), 3=amber(stars)
static const uint16_t bg3_pal[4] = {
    SNES_RGB(0, 0, 0), SNES_RGB(24, 24, 24),
    SNES_RGB(2, 12, 20), SNES_RGB(31, 26, 8),
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     step;
} App;

volatile uint16_t corpus_result;

static inline void fmt3(char *buf, uint16_t v) {
    buf[0] = (char)('0' + (uint8_t)(v / 100u));
    buf[1] = (char)('0' + (uint8_t)((v / 10u) % 10u));
    buf[2] = (char)('0' + (uint8_t)(v % 10u));
}

// Plot each particle as a 2×2 star, fading the previous frame's trail.
static void draw_galaxy(App *a) {
    for (uint8_t i = 0u; i < (uint8_t)BH_N; i++) {
        int16_t x = bh_par[i].x, y = bh_par[i].y;
        // trail dot (cyan)
        canvas_plot(&a->canvas, x, y, 2);
        // star core (amber 2×2)
        canvas_plot(&a->canvas, x, y, 3);
        canvas_plot(&a->canvas, (int16_t)(x + 1), y, 3);
        canvas_plot(&a->canvas, x, (int16_t)(y + 1), 3);
        canvas_plot(&a->canvas, (int16_t)(x + 1), (int16_t)(y + 1), 3);
    }
}

static void hud_top(App *a) {
    char line[32] = "#31 BARNES-HUT  STEP:    ";
    fmt3(line + 21, a->step);
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
    a->step = 0u;
}

int main(void) {
    static App a;
    app_init(&a);

    text_clear_bar(&a.text, 1);
    text_puts(&a.text, 1, 0, "N=8  QUADTREE  MULSI3+DIVSI3");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "BARNES-HUT", "QUADTREE GALAXY");

    corpus_result = bh_gate_crc();

    title_end(&a.screen, &title, 90);

    // Re-seed for live animation (gate consumed the initial state)
    bh_init();
    hud_top(&a);

    for (;;) {
        bh_step();              // rebuild quadtree + walk per particle (the stress)
        draw_galaxy(&a);
        a.step++;
        if ((a.step & 7u) == 0u) hud_top(&a);

        if (a.step >= (uint16_t)RESET_STEPS) {
            a.step = 0u;
            canvas_clear(&a.canvas);
            bh_init();
            hud_top(&a);
        }

        display_frame(&a.screen);
    }
}
