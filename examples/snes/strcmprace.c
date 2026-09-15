// Lexicographic Race — #148 of the compiler stress-test battery.
// Round 8 (the un-entered backend paths), Cluster B. Builds default-8-bit AND +mos-a16 AND
// +mos-xy16 (no far pointers -> full 5-way bar); the headless 5-way gate is
// corpus/strcmprace_sim.c.
//
// Codegen corner: memcmp / strcmp / strncmp — three libc comparison functions used ZERO times
// tree-wide across demos #1-#141. (#66 editdist compares characters by hand, #46 qsortviz
// compares numbers.) Measured negative, recorded honestly: MOS never inline-expands memcmp at
// any constant size, including the `== 0` form other targets specialise, so this covers three
// never-linked libcalls rather than a second lowering.
//
// Visual: 24 fixed-width string lanes as rows of glyph blocks, redrawn in the order strcmp
// sorted them, with each comparison's resolving byte column marked — the position at which
// the lexicographic order was actually decided.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/strcmprace.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define STEP_FRAMES   6u
#define HOLD_FRAMES 120u

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(7, 14, 24),          // 1: a lane byte before the terminator
    SNES_RGB(20, 20, 20),         // 2: the filler past the terminator (memcmp sees it)
    SNES_RGB(31, 16, 6),          // 3: the byte at which a comparison resolved
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint8_t  lr_row;
static uint16_t lr_hold;

static const char hexd[17] = "0123456789ABCDEF";

// Draw one lane as a run of byte cells, height-coded by the character. The cells past the
// terminator are drawn in the filler colour, because that is the part only memcmp compares.
__attribute__((noinline))
static void draw_lane(BitmapCanvas *cv, uint8_t row) {
    uint8_t lane = sr_order[row];
    int16_t y = (int16_t)((int16_t)row * (int16_t)5 + (int16_t)4);
    uint8_t past = (uint8_t)0u;
    for (uint8_t k = (uint8_t)0u; k < (uint8_t)SR_W; k++) {
        uint8_t c = (uint8_t)sr_lane[lane][k];
        if (c == (uint8_t)0u) past = (uint8_t)1u;
        uint8_t col = past ? (uint8_t)2u : (uint8_t)1u;
        int16_t x = (int16_t)((int16_t)k * (int16_t)10 + (int16_t)4);
        uint8_t h = (uint8_t)((uint8_t)(c & 7u) >> 1);
        for (int16_t dx = (int16_t)0; dx < (int16_t)8; dx++)
            for (int16_t dy = (int16_t)0; dy <= (int16_t)h; dy++)
                canvas_plot(cv, (int16_t)(x + dx), (int16_t)(y + dy), col);
    }
    /* The resolving column for the strcmp that placed this lane, from the comparison log. */
    if (row > (uint8_t)0u) {
        uint16_t idx = (uint16_t)((uint16_t)(row - 1u) % sr_nlog);
        uint8_t at = sr_at[idx];
        if (at < (uint8_t)SR_W) {
            int16_t x = (int16_t)((int16_t)at * (int16_t)10 + (int16_t)4);
            for (int16_t dx = (int16_t)0; dx < (int16_t)8; dx++)
                canvas_plot(cv, (int16_t)(x + dx), y, (uint8_t)3u);
        }
    }
}

__attribute__((noinline))
static void race_step(BitmapCanvas *cv) {
    if (lr_hold) {
        lr_hold--;
        if (lr_hold == (uint16_t)0u) { lr_row = (uint8_t)0u; canvas_clear(cv); }
        return;
    }
    if (lr_row >= (uint8_t)SR_N) { lr_hold = (uint16_t)HOLD_FRAMES; return; }
    draw_lane(cv, lr_row);
    lr_row = (uint8_t)(lr_row + 1u);
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
    text_puts(&a.text, 0, 1, "STRCMPRACE LEXICOGRAPHIC");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "LEXICOGRAPHIC", "STRCMPRACE");
    corpus_result = strcmprace_gate_crc();   // expected 0xF0BA
    title_end(&a.screen, &title, 90);

    lr_row = (uint8_t)0u;
    lr_hold = (uint16_t)0u;

    for (;;) {
        a.t++;
        if ((a.t % (uint16_t)STEP_FRAMES) == (uint16_t)0u) {
            race_step(&a.canvas);
            char buf[25];
            buf[0]='R'; buf[1]='O'; buf[2]='W'; buf[3]='=';
            buf[4]=(char)hexd[(lr_row >> 4) & 15u];
            buf[5]=(char)hexd[lr_row & 15u];
            buf[6]=' '; buf[7]='C'; buf[8]='M'; buf[9]='P'; buf[10]='=';
            buf[11]=(char)hexd[(sr_nlog >> 8) & 15u];
            buf[12]=(char)hexd[(sr_nlog >> 4) & 15u];
            buf[13]=(char)hexd[sr_nlog & 15u];
            buf[14]=' '; buf[15]='U'; buf[16]='N'; buf[17]='C'; buf[18]='=';
            buf[19]=(char)hexd[sr_uncovered() & 15u];
            buf[20]=' '; buf[21]=' '; buf[22]=' '; buf[23]=' '; buf[24]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
