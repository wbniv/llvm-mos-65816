// Jump-Table Boundary Sweep — #152 of the compiler stress-test battery.
// Round 8 (the un-entered backend paths), Cluster C. Builds default-8-bit AND +mos-a16 AND
// +mos-xy16 (no far pointers -> full 5-way bar); the headless 5-way gate is
// corpus/jtedge_sim.c.
//
// Codegen corner: the EXACT boundary in legalizeBrJt, `Table.MBBs.size() <= 128`
// (MOSLegalizerInfo.cpp:3334). Three dispatchers over the same sixteen handler families, at
// 127, 128 and 129 successors, so both arms and the boundary itself are compiled side by side.
// Measured: the boundary is exact and inclusive at 128 — 127/128 take `jmp (.LJTI,x)`, 129
// takes `ldy .LJTI,x` + `lda .LJTI+256,x` + `jmp (__rc)`. #142 jt256 sits at 256, deep past it.
//
// Visual: three phase portraits of the same VM state, one per dispatcher, drawn ON TOP of each
// other in three colours. Because all three lowerings must be indistinguishable, the correct
// picture is a SINGLE stroke in the last colour drawn — any divergence would split it into
// visibly separate curves, and the HUD's DIS= counter would leave zero.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/jtedge.h"

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
    SNES_RGB(20, 6, 6),           // 1: the 127-successor dispatcher (JMP (abs,X) arm)
    SNES_RGB(6, 20, 10),          // 2: the 128-successor dispatcher (still that arm, AT the limit)
    SNES_RGB(28, 24, 10),         // 3: the 129-successor dispatcher (split lo/hi + MO_HI_JT)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint16_t jz_next;
static uint16_t jz_hold;

static const char hexd[17] = "0123456789ABCDEF";

__attribute__((noinline))
static void plot_step(BitmapCanvas *cv) {
    if (jz_hold) {
        jz_hold--;
        if (jz_hold == (uint16_t)0u) { jz_next = (uint16_t)0u; canvas_clear(cv); }
        return;
    }
    for (uint8_t n = (uint8_t)0u; n < (uint8_t)PLOT_PER_FRAME; n++) {
        if (jz_next >= je_nplot) { jz_hold = (uint16_t)HOLD_FRAMES; return; }
        for (uint8_t v = (uint8_t)0u; v < (uint8_t)3u; v++)
            canvas_plot(cv, (int16_t)je_tx[v][jz_next], (int16_t)je_ty[v][jz_next],
                        (uint8_t)(v + 1u));
        jz_next++;
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
    text_puts(&a.text, 0, 1, "JTEDGE  127 128 129");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "JUMP TABLE EDGE", "JTEDGE");
    corpus_result = jtedge_gate_crc();    // expected 0xC199
    title_end(&a.screen, &title, 90);

    jz_next = (uint16_t)0u;
    jz_hold = (uint16_t)0u;

    uint16_t dis = je_disagreements();
    uint16_t mis = je_misses();

    for (;;) {
        a.t++;
        if ((a.t & 1u) == 0u) {
            plot_step(&a.canvas);
            char buf[25];
            buf[0]='D'; buf[1]='I'; buf[2]='S'; buf[3]='=';
            buf[4]=(char)hexd[(dis >> 4) & 15u];
            buf[5]=(char)hexd[dis & 15u];
            buf[6]=' '; buf[7]='M'; buf[8]='I'; buf[9]='S'; buf[10]='=';
            buf[11]=(char)hexd[(mis >> 4) & 15u];
            buf[12]=(char)hexd[mis & 15u];
            buf[13]=' '; buf[14]='P'; buf[15]='T'; buf[16]='=';
            buf[17]=(char)hexd[(jz_next >> 8) & 15u];
            buf[18]=(char)hexd[(jz_next >> 4) & 15u];
            buf[19]=(char)hexd[jz_next & 15u];
            buf[20]=' '; buf[21]='C'; buf[22]='=';
            buf[23]=(char)hexd[(corpus_result >> 12) & 15u];
            buf[24]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
