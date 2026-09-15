// ISA-256 Bytecode Machine — #142 of the compiler stress-test battery.
// Round 8 (the un-entered backend paths), Cluster A. Builds default-8-bit AND +mos-a16 AND
// +mos-xy16 (no far pointers -> full 5-way bar); the headless 5-way gate is
// corpus/jt256_sim.c.
//
// Codegen corner: the ELSE arm of legalizeBrJt. That handler picks between `JMP (abs,X)` and
// a split low-byte/high-byte table pair (the high one under its own MO_HI_JT relocation) fed
// into G_BRINDIRECT, on `Table.MBBs.size() <= 128`. All five jump tables that exist across
// demos #1-#141 are 8-16-case VM dispatches and take the first arm; ISA-256's 256-way
// dispatch is structurally over the limit, so it is the first program in this project to
// compile the second.
//
// Visual: the machine's r[0]/r[1] are read as a point after every instruction, so the
// executed program draws a phase portrait stroke by stroke. Below it, the 16x16 opcode-space
// map lights each handler as it is first entered — a dispatch that lands one table slot off
// lights the wrong cell.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/jt256.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define PLOT_PER_FRAME 6u    /* trace points drawn per v-blank */
#define HOLD_FRAMES  150u    /* v-blanks the finished portrait is held before restarting */

// BG3 2bpp palette: black, the settled trace, the recent trace, and the live pen.
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(6, 12, 18),          // 1: settled trace
    SNES_RGB(12, 24, 28),         // 2: recent trace
    SNES_RGB(31, 26, 10),         // 3: pen head / opcode map
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint16_t vz_next;    /* next trace point to draw */
static uint16_t vz_hold;    /* frames left holding the finished portrait */

static const char hexd[17] = "0123456789ABCDEF";

// Draw the next few trace points, then (once the portrait is complete) the 16x16 opcode-space
// coverage map along the bottom of the canvas.
__attribute__((noinline))
static void plot_step(BitmapCanvas *cv) {
    if (vz_hold) {
        vz_hold--;
        if (vz_hold == (uint16_t)0u) { vz_next = (uint16_t)0u; canvas_clear(cv); }
        return;
    }
    for (uint8_t n = (uint8_t)0u; n < (uint8_t)PLOT_PER_FRAME; n++) {
        if (vz_next >= jt_nplot) { vz_hold = (uint16_t)HOLD_FRAMES; return; }
        int16_t x = (int16_t)jt_tx[vz_next];
        int16_t y = (int16_t)((int16_t)jt_ty[vz_next] >> 1);   /* upper half: portrait */
        if (vz_next != (uint16_t)0u)
            canvas_plot(cv, x, y, (uint8_t)2u);
        else
            canvas_plot(cv, x, y, (uint8_t)3u);
        vz_next++;

        /* The opcode-space map: a 16x16 grid of 4x2 cells in the lower quarter of the
           canvas, one cell per opcode byte, lit once that handler has been entered. */
        if ((vz_next & 7u) == 0u) {
            for (uint16_t op = (uint16_t)0u; op < (uint16_t)256u; op++) {
                if (!(jt_seen[(uint8_t)(op >> 3)] &
                      (uint8_t)((uint8_t)1u << (uint8_t)(op & 7u)))) continue;
                int16_t cx = (int16_t)((int16_t)((op & 15u) * 8u) + (int16_t)2);
                int16_t cy = (int16_t)((int16_t)((op >> 4) * 3u) + (int16_t)78);
                canvas_plot(cv, cx, cy, (uint8_t)3u);
                canvas_plot(cv, (int16_t)(cx + 1), cy, (uint8_t)1u);
            }
        }
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
    text_puts(&a.text, 0, 1, "JT256  256-WAY DISPATCH");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "ISA-256 DISPATCH", "JT256");
    corpus_result = jt256_gate_crc();    // expected 0xB8CC
    title_end(&a.screen, &title, 90);

    vz_next = (uint16_t)0u;
    vz_hold = (uint16_t)0u;

    uint16_t cov = jt256_coverage();

    for (;;) {
        a.t++;
        if ((a.t & 1u) == 0u) {
            plot_step(&a.canvas);
            char buf[25];
            buf[0]='O'; buf[1]='P'; buf[2]='S'; buf[3]=' ';
            buf[4]=(char)hexd[(cov >> 8) & 15u];
            buf[5]=(char)hexd[(cov >> 4) & 15u];
            buf[6]=(char)hexd[cov & 15u];
            buf[7]='/'; buf[8]='1'; buf[9]='0'; buf[10]='0';
            buf[11]=' '; buf[12]='P'; buf[13]='T'; buf[14]='=';
            buf[15]=(char)hexd[(vz_next >> 8) & 15u];
            buf[16]=(char)hexd[(vz_next >> 4) & 15u];
            buf[17]=(char)hexd[vz_next & 15u];
            buf[18]=' '; buf[19]='C'; buf[20]='=';
            buf[21]=(char)hexd[(corpus_result >> 12) & 15u];
            buf[22]=(char)hexd[(corpus_result >> 8) & 15u];
            buf[23]=(char)hexd[(corpus_result >> 4) & 15u];
            buf[24]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
