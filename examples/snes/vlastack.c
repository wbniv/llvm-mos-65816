// Run-Length Scanline Decoder — #143 of the compiler stress-test battery.
// Round 8 (the un-entered backend paths), Cluster A. Builds default-8-bit AND +mos-a16 AND
// +mos-xy16 (no far pointers -> full 5-way bar); the headless 5-way gate is
// corpus/vlastack_sim.c.
//
// Codegen corner: G_DYN_STACKALLOC (MOSLegalizerInfo.cpp:456, `.custom()`) — a VLA whose
// length the compiler cannot fold, so the soft stack pointer is adjusted at run time by a
// computed delta inside a G_STACKSAVE/G_STACKRESTORE bracket. Zero demos #1-#141 form it:
// #68 polyfill's VLA const-folds to a fixed-size alloca, which covers the save/restore pair
// but never the dynamic allocation itself.
//
// Visual: the decoded image is revealed row by row as the decoder walks it, with a bar gauge
// at the right showing each row's run count — which IS that row's allocation size, so the
// gauge is a direct picture of how much the soft SP moved for that iteration.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/vlastack.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define ROWS_PER_FRAME 1u
#define HOLD_FRAMES  150u

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(7, 9, 16),           // 1: image, dark
    SNES_RGB(14, 20, 27),         // 2: image, mid
    SNES_RGB(30, 27, 13),         // 3: image bright / allocation gauge
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint8_t  vz_row;
static uint16_t vz_hold;

static const char hexd[17] = "0123456789ABCDEF";

// Reveal the next decoded row, then draw that row's allocation-size bar.
__attribute__((noinline))
static void reveal_step(BitmapCanvas *cv) {
    if (vz_hold) {
        vz_hold--;
        if (vz_hold == (uint16_t)0u) { vz_row = (uint8_t)0u; canvas_clear(cv); }
        return;
    }
    for (uint8_t n = (uint8_t)0u; n < (uint8_t)ROWS_PER_FRAME; n++) {
        if (vz_row >= (uint8_t)VS_ROWS) { vz_hold = (uint16_t)HOLD_FRAMES; return; }
        int16_t y = (int16_t)((int16_t)vz_row + (int16_t)24);
        for (uint8_t x = (uint8_t)0u; x < (uint8_t)VS_W; x++) {
            uint8_t v = vs_img[vz_row][x];
            uint8_t c = (uint8_t)((uint8_t)((v & 3u) + (uint8_t)((v >> 2) & 1u)) & 3u);
            if (c != (uint8_t)0u) canvas_plot(cv, (int16_t)x, y, c);
        }
        /* The allocation gauge: this row's run count IS its VLA length. */
        uint8_t nr = vs_nruns[vz_row];
        for (uint8_t b = (uint8_t)0u; b < nr; b++)
            canvas_plot(cv, (int16_t)((int16_t)VS_W + (int16_t)1 + (int16_t)b), y, (uint8_t)3u);
        vz_row++;
    }
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
    text_puts(&a.text, 0, 1, "VLASTACK  RUNTIME VLA");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "RUNTIME-SIZED VLA", "VLASTACK");
    corpus_result = vlastack_gate_crc();   // expected 0xD77B
    title_end(&a.screen, &title, 90);

    vz_row  = (uint8_t)0u;
    vz_hold = (uint16_t)0u;

    uint8_t lo = vs_min_runs(), hi = vs_max_runs();

    for (;;) {
        a.t++;
        if ((a.t & 3u) == 0u) {
            reveal_step(&a.canvas);
            char buf[24];
            buf[0]='A'; buf[1]='L'; buf[2]='L'; buf[3]='O'; buf[4]='C'; buf[5]=' ';
            buf[6]=(char)hexd[(lo >> 4) & 15u];
            buf[7]=(char)hexd[lo & 15u];
            buf[8]='-';
            buf[9]=(char)hexd[(hi >> 4) & 15u];
            buf[10]=(char)hexd[hi & 15u];
            buf[11]=' '; buf[12]='R'; buf[13]='O'; buf[14]='W'; buf[15]='=';
            buf[16]=(char)hexd[(vz_row >> 4) & 15u];
            buf[17]=(char)hexd[vz_row & 15u];
            buf[18]=' '; buf[19]='C'; buf[20]='=';
            buf[21]=(char)hexd[(corpus_result >> 12) & 15u];
            buf[22]=(char)hexd[(corpus_result >> 8) & 15u];
            buf[23]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
