// Bisection Oracle — #147 of the compiler stress-test battery.
// Round 8 (the un-entered backend paths), Cluster B. Builds default-8-bit AND +mos-a16 AND
// +mos-xy16 (no far pointers -> full 5-way bar); the headless 5-way gate is
// corpus/bsearchviz_sim.c.
//
// Codegen corner: libc `bsearch` — a callback ABI this battery has never linked, and one that
// is structurally unlike `qsort`'s. `qsort`'s comparator drives a SWAP and the call permutes
// in place; `bsearch`'s drives an INTERVAL BISECTION and the call returns a void* INTO the
// array (or NULL), which the caller must difference back into an index. `bsearch` is used
// ZERO times across demos #1-#141.
//
// Visual: the 64-key sorted field as an 8x8 grid. Each query's probe sequence lights up in
// order as the bisection narrows, then the landing cell flashes green for a hit or the whole
// row flashes red for a miss (the NULL return).
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/bsearchviz.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define STEP_FRAMES   8u
#define HOLD_FRAMES 120u

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(6, 10, 16),          // 1: the sorted field, at rest
    SNES_RGB(28, 26, 8),          // 2: a probe the bisection touched
    SNES_RGB(8, 28, 10),          // 3: the landing cell (hit) / miss marker
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint8_t  bv_q;      /* query being replayed */
static uint16_t bv_hold;

static const char hexd[17] = "0123456789ABCDEF";

// One 14x14 cell per key, 8 across. Drawn as a filled block so a probe is legible at SNES
// resolution.
static void cell(BitmapCanvas *cv, uint8_t idx, uint8_t color) {
    int16_t cx = (int16_t)((int16_t)((int16_t)(idx & 7u) * (int16_t)15) + (int16_t)6);
    int16_t cy = (int16_t)((int16_t)((int16_t)(idx >> 3) * (int16_t)14) + (int16_t)10);
    for (int16_t dy = (int16_t)0; dy < (int16_t)9; dy++)
        for (int16_t dx = (int16_t)0; dx < (int16_t)10; dx++)
            canvas_plot(cv, (int16_t)(cx + dx), (int16_t)(cy + dy), color);
}

__attribute__((noinline))
static void query_step(BitmapCanvas *cv) {
    if (bv_hold) {
        bv_hold--;
        if (bv_hold == (uint16_t)0u) {
            bv_q = (uint8_t)0u;
            canvas_clear(cv);
        }
        return;
    }
    if (bv_q >= (uint8_t)BS_Q) { bv_hold = (uint16_t)HOLD_FRAMES; return; }

    canvas_clear(cv);
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)BS_N; i++) cell(cv, i, (uint8_t)1u);
    for (uint8_t p = (uint8_t)0u; p < bs_nprobe[bv_q]; p++)
        cell(cv, bs_probe[bv_q][p], (uint8_t)2u);

    if (bs_found[bv_q] != (uint16_t)BS_MISS) {
        cell(cv, (uint8_t)bs_found[bv_q], (uint8_t)3u);
    } else {
        /* the NULL arm — a bar across the foot rather than a cell, because there is no cell */
        for (int16_t x = (int16_t)4; x < (int16_t)124; x++)
            canvas_plot(cv, x, (int16_t)124, (uint8_t)3u);
    }
    bv_q = (uint8_t)(bv_q + 1u);
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
    text_puts(&a.text, 0, 1, "BSEARCHVIZ  BISECTION");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "BISECTION ORACLE", "BSEARCHVIZ");
    corpus_result = bsearchviz_gate_crc();   // expected 0x7FF5
    title_end(&a.screen, &title, 90);

    bv_q = (uint8_t)0u;
    bv_hold = (uint16_t)0u;

    for (;;) {
        a.t++;
        if ((a.t % (uint16_t)STEP_FRAMES) == (uint16_t)0u) {
            query_step(&a.canvas);
            uint8_t q = (uint8_t)(bv_q ? (uint8_t)(bv_q - 1u) : (uint8_t)0u);
            char buf[25];
            buf[0]='Q'; buf[1]='=';
            buf[2]=(char)hexd[(q >> 4) & 15u];
            buf[3]=(char)hexd[q & 15u];
            buf[4]=' '; buf[5]='I'; buf[6]='=';
            buf[7]=(bs_found[q] == (uint16_t)BS_MISS) ? '-' : (char)hexd[(bs_found[q] >> 4) & 15u];
            buf[8]=(bs_found[q] == (uint16_t)BS_MISS) ? '-' : (char)hexd[bs_found[q] & 15u];
            buf[9]=' '; buf[10]='P'; buf[11]='=';
            buf[12]=(char)hexd[bs_nprobe[q] & 15u];
            buf[13]=' '; buf[14]='H'; buf[15]='=';
            buf[16]=(char)hexd[(bs_hits >> 4) & 15u];
            buf[17]=(char)hexd[bs_hits & 15u];
            buf[18]=' '; buf[19]='M'; buf[20]='=';
            buf[21]=(char)hexd[(bs_misses >> 4) & 15u];
            buf[22]=(char)hexd[bs_misses & 15u];
            buf[23]=' '; buf[24]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
