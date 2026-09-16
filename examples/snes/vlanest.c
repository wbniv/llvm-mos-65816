// Nested VLA Pyramid — #151 of the compiler stress-test battery.
// Round 8 (the un-entered backend paths), Cluster C. Builds default-8-bit AND +mos-a16 AND
// +mos-xy16 (no far pointers -> full 5-way bar); the headless 5-way gate is
// corpus/vlanest_sim.c.
//
// Codegen corner: TWO nested G_STACKSAVE/G_STACKRESTORE brackets around two G_DYN_STACKALLOCs
// with independent runtime lengths. #143 vlastack brought G_DYN_STACKALLOC into the tree with
// ONE bracket at ONE depth; this is the depth axis. Measured: the nesting only survives when
// both VLA scopes are re-entered per loop iteration — the obvious shapes collapse to a single
// save/restore because the outer restore coincides with the function's return.
//
// Visual: the pyramid. Each row draws its OUTER allocation as a row of cells, one per element,
// and each cell's height is that element's INNER allocation length — so the picture is
// literally the two-level allocation profile, and the irregular skyline is the proof that
// neither length is a constant the compiler could have folded.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/vlanest.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define STEP_FRAMES   6u
#define HOLD_FRAMES 140u

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(7, 10, 20),          // 1: the level-1 (outer) allocation's floor
    SNES_RGB(12, 26, 16),         // 2: a level-2 (inner) allocation's body
    SNES_RGB(31, 22, 8),          // 3: the row being built
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint16_t vz_row;
static uint16_t vz_hold;

static const char hexd[17] = "0123456789ABCDEF";

// One row: the outer allocation's floor, then one column per element whose height is that
// element's inner allocation length.
__attribute__((noinline))
static void draw_row(BitmapCanvas *cv, uint16_t r) {
    uint8_t n = vn_olen[r];
    int16_t base = (int16_t)((int16_t)(r * 5) + (int16_t)4);
    for (uint8_t i = (uint8_t)0u; i < n; i++) {
        int16_t x = (int16_t)((int16_t)(i * 7) + (int16_t)2);
        canvas_plot(cv, x, base, (uint8_t)1u);
        canvas_plot(cv, (int16_t)(x + 1), base, (uint8_t)1u);
        canvas_plot(cv, (int16_t)(x + 2), base, (uint8_t)1u);
        /* The REAL inner allocation length for this element, as recorded by the reduction. */
        uint8_t k = vn_kprof[r][i];
        for (uint8_t h = (uint8_t)0u; h < k && h < (uint8_t)4u; h++)
            canvas_plot(cv, (int16_t)(x + 1), (int16_t)(base - (int16_t)h - 1), (uint8_t)2u);
    }
    /* the row marker */
    canvas_plot(cv, (int16_t)0, base, (uint8_t)3u);
    canvas_plot(cv, (int16_t)1, base, (uint8_t)3u);
}

__attribute__((noinline))
static void build_step(BitmapCanvas *cv) {
    if (vz_hold) {
        vz_hold--;
        if (vz_hold == (uint16_t)0u) { vz_row = (uint16_t)0u; canvas_clear(cv); }
        return;
    }
    if (vz_row >= (uint16_t)VN_ROWS) { vz_hold = (uint16_t)HOLD_FRAMES; return; }
    draw_row(cv, vz_row);
    vz_row = (uint16_t)(vz_row + 1u);
}

int main(void) {
    static App a;
    display_init(&a.screen);
    canvas_init(&a.canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a.text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a.screen, (Drawable *)&a.canvas);
    display_add(&a.screen, (Drawable *)&a.text);
    upq_push_cgram(&a.screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a.t = (uint16_t)0u;
    text_puts(&a.text, 0, 1, "VLANEST  NESTED VLAS");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "NESTED VLA PYRAMID", "VLANEST");
    corpus_result = vlanest_gate_crc();   // expected 0x153B
    title_end(&a.screen, &title, 90);

    vz_row = (uint16_t)0u;
    vz_hold = (uint16_t)0u;

    uint8_t dout = vn_distinct_outer();
    uint8_t din  = vn_distinct_inner();

    for (;;) {
        a.t++;
        if ((a.t % (uint16_t)STEP_FRAMES) == (uint16_t)0u) {
            build_step(&a.canvas);
            char buf[25];
            buf[0]='R'; buf[1]='=';
            buf[2]=(char)hexd[(vz_row >> 4) & 15u];
            buf[3]=(char)hexd[vz_row & 15u];
            buf[4]=' '; buf[5]='N'; buf[6]='=';
            buf[7]=(char)hexd[(dout >> 4) & 15u];
            buf[8]=(char)hexd[dout & 15u];
            buf[9]='/'; buf[10]='K'; buf[11]='=';
            buf[12]=(char)hexd[(din >> 4) & 15u];
            buf[13]=(char)hexd[din & 15u];
            buf[14]=' '; buf[15]='B'; buf[16]='A'; buf[17]='D'; buf[18]='=';
            buf[19]=(char)hexd[(vn_reread_bad >> 4) & 15u];
            buf[20]=(char)hexd[vn_reread_bad & 15u];
            buf[21]=' '; buf[22]=' '; buf[23]=' '; buf[24]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
