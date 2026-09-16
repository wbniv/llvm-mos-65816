// Sparse Switch Ladder — #153 of the compiler stress-test battery.
// Round 8 (the un-entered backend paths), Cluster C. Builds default-8-bit AND +mos-a16 AND
// +mos-xy16 (no far pointers -> full 5-way bar); the headless 5-way gate is
// corpus/jtsparse_sim.c.
//
// Codegen corner: the THIRD switch-lowering strategy. A switch whose case values are too sparse
// to tabulate never reaches legalizeBrJt at all — it becomes a binary-search compare tree,
// structurally distinct from both jump-table arms (#142 jt256, #152 jtedge) and never
// deliberately forced by any prior demo. Measured: sixteen keys spread over 0..55555 emit ZERO
// `.LJTI` references and a signed-comparison narrowing tree.
//
// Visual: the ladder on the left is the sparse key space — each of the sixteen keys drawn at
// its own height, so the irregular gaps that force the compare tree are the picture. On the
// right, the two dispatchers' phase portraits are drawn on top of each other; since strategy 1
// and strategy 3 must be indistinguishable, the correct result is one stroke.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/jtsparse.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define PLOT_PER_FRAME 4u
#define HOLD_FRAMES  150u

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(8, 14, 22),          // 1: the sparse key ladder
    SNES_RGB(22, 8, 8),           // 2: the DENSE dispatcher's trace (jump table)
    SNES_RGB(10, 28, 14),         // 3: the SPARSE dispatcher's trace (compare tree)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint16_t sz_next;
static uint16_t sz_hold;

static const char hexd[17] = "0123456789ABCDEF";

// The sixteen sparse keys, each drawn as a bar whose length is the key scaled into the canvas.
// The gaps are the whole point: they are what make a jump table uneconomical.
__attribute__((noinline))
static void draw_ladder(BitmapCanvas *cv) {
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)16u; i++) {
        int16_t y = (int16_t)((int16_t)(i * 8) + (int16_t)2);
        int16_t w = (int16_t)((uint16_t)(js_key[i] >> 10) + 1u);   /* 0..63 */
        for (int16_t x = (int16_t)0; x < w && x < (int16_t)40; x++)
            canvas_plot(cv, x, y, (uint8_t)1u);
    }
}

__attribute__((noinline))
static void plot_step(BitmapCanvas *cv) {
    if (sz_hold) {
        sz_hold--;
        if (sz_hold == (uint16_t)0u) { sz_next = (uint16_t)0u; canvas_clear(cv); draw_ladder(cv); }
        return;
    }
    for (uint8_t n = (uint8_t)0u; n < (uint8_t)PLOT_PER_FRAME; n++) {
        if (sz_next >= js_nplot) { sz_hold = (uint16_t)HOLD_FRAMES; return; }
        for (uint8_t v = (uint8_t)0u; v < (uint8_t)2u; v++) {
            int16_t x = (int16_t)((int16_t)((uint16_t)js_tx[v][sz_next] >> 1) + (int16_t)48);
            int16_t y = (int16_t)js_ty[v][sz_next];
            canvas_plot(cv, x, y, (uint8_t)(v + 2u));
        }
        sz_next++;
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
    text_puts(&a.text, 0, 1, "JTSPARSE  COMPARE TREE");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "SPARSE SWITCH LADDER", "JTSPARSE");
    corpus_result = jtsparse_gate_crc();    // expected 0xA131
    title_end(&a.screen, &title, 90);

    sz_next = (uint16_t)0u;
    sz_hold = (uint16_t)0u;
    draw_ladder(&a.canvas);

    uint16_t dis = js_disagreements();
    uint16_t mis = js_sparse_misses();

    for (;;) {
        a.t++;
        if ((a.t & 1u) == 0u) {
            plot_step(&a.canvas);
            char buf[25];
            buf[0]='D'; buf[1]='I'; buf[2]='S'; buf[3]='=';
            buf[4]=(char)hexd[(dis >> 4) & 15u];
            buf[5]=(char)hexd[dis & 15u];
            buf[6]=' '; buf[7]='M'; buf[8]='I'; buf[9]='S'; buf[10]='=';
            buf[11]=(char)hexd[(mis >> 8) & 15u];
            buf[12]=(char)hexd[(mis >> 4) & 15u];
            buf[13]=(char)hexd[mis & 15u];
            buf[14]=' '; buf[15]='P'; buf[16]='T'; buf[17]='=';
            buf[18]=(char)hexd[(sz_next >> 8) & 15u];
            buf[19]=(char)hexd[(sz_next >> 4) & 15u];
            buf[20]=(char)hexd[sz_next & 15u];
            buf[21]=' '; buf[22]=' '; buf[23]=' '; buf[24]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
