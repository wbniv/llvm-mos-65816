// Reservoir Ladder — #144 of the compiler stress-test battery.
// Round 8 (the un-entered backend paths), Cluster A. Builds default-8-bit AND +mos-a16 AND
// +mos-xy16 (no far pointers -> full 5-way bar); the headless 5-way gate is
// corpus/borrowov_sim.c.
//
// Codegen corner: G_USUBO / G_SSUBO (MOSLegalizerInfo.cpp:296; custom cases :2031/:2034) —
// subtract-with-overflow, lowered separately from the add forms. `__builtin_sub_overflow` is
// used ZERO times across demos #1-#141; only the add (#44 hdr-bloom) and mul (#76 smulorbit,
// #101 mulov64) forms appear. The unsigned case tests a BORROW out (the inverse sense of the
// add form's carry) and the signed case a sign-agreement predicate that is exactly backwards
// from the add one — opposite-sign operands are what can overflow a subtract.
//
// Visual: twelve reservoirs drawn as vertical bars. Every scheduled transfer drains one into
// another through a checked subtract; a detected underflow rejects the transfer and the bar
// flashes and bounces instead of draining.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/borrowov.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define TICK_FRAMES   3u
#define HOLD_FRAMES 150u

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(5, 13, 22),          // 1: reservoir level
    SNES_RGB(10, 24, 16),         // 2: accepted transfer
    SNES_RGB(31, 10, 8),          // 3: REJECTED — an overflow the predicate caught
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint16_t rv_ev;      /* next recorded event to replay */
static uint16_t rv_hold;

static const char hexd[17] = "0123456789ABCDEF";

// Replay one recorded event: draw the twelve bars at their scaled heights, then mark the
// reservoir this tick drained — green when the checked subtract succeeded, red when its
// overflow predicate fired and the transfer was rejected.
__attribute__((noinline))
static void tick_step(BitmapCanvas *cv) {
    if (rv_hold) {
        rv_hold--;
        if (rv_hold == (uint16_t)0u) { rv_ev = (uint16_t)0u; canvas_clear(cv); }
        return;
    }
    if (rv_ev >= bo_nevent) { rv_hold = (uint16_t)HOLD_FRAMES; return; }

    uint8_t ev  = bo_event[rv_ev];
    uint8_t src = bo_src[rv_ev];

    for (uint8_t i = (uint8_t)0u; i < (uint8_t)BO_N; i++) {
        int16_t bx = (int16_t)((int16_t)i * (int16_t)10 + (int16_t)4);
        uint8_t hgt = (uint8_t)((bo_u16[i] >> 9) & 0x3Fu);
        for (uint8_t k = (uint8_t)0u; k < (uint8_t)6u; k++) {
            int16_t y = (int16_t)((int16_t)100 - (int16_t)hgt);
            uint8_t c = (i == src) ? ((ev & (uint8_t)1u) ? (uint8_t)3u : (uint8_t)2u)
                                   : (uint8_t)1u;
            canvas_plot(cv, (int16_t)(bx + (int16_t)k), y, c);
        }
    }
    /* Event ribbon across the top: one column per tick, coloured by which width rejected. */
    {
        int16_t x = (int16_t)((int16_t)(rv_ev & 127u));
        if (ev & (uint8_t)1u) canvas_plot(cv, x, (int16_t)4,  (uint8_t)3u);
        if (ev & (uint8_t)2u) canvas_plot(cv, x, (int16_t)7,  (uint8_t)3u);
        if (ev & (uint8_t)4u) canvas_plot(cv, x, (int16_t)10, (uint8_t)3u);
        if (ev == (uint8_t)0u) canvas_plot(cv, x, (int16_t)13, (uint8_t)2u);
    }
    rv_ev++;
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
    text_puts(&a.text, 0, 1, "BORROWOV  CHECKED SUBTRACT");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "CHECKED SUBTRACT", "BORROWOV");
    corpus_result = borrowov_gate_crc();   // expected 0x81FB
    title_end(&a.screen, &title, 90);

    rv_ev   = (uint16_t)0u;
    rv_hold = (uint16_t)0u;

    uint16_t rej = bo_rejects();

    for (;;) {
        a.t++;
        if ((a.t % (uint16_t)TICK_FRAMES) == (uint16_t)0u) {
            tick_step(&a.canvas);
            char buf[25];
            buf[0]='R'; buf[1]='E'; buf[2]='J'; buf[3]='=';
            buf[4]=(char)hexd[(rej >> 8) & 15u];
            buf[5]=(char)hexd[(rej >> 4) & 15u];
            buf[6]=(char)hexd[rej & 15u];
            buf[7]=' '; buf[8]='U'; buf[9]='=';
            buf[10]=(char)hexd[(bo_reject_u >> 4) & 15u];
            buf[11]=(char)hexd[bo_reject_u & 15u];
            buf[12]=' '; buf[13]='S'; buf[14]='=';
            buf[15]=(char)hexd[(bo_reject_s >> 4) & 15u];
            buf[16]=(char)hexd[bo_reject_s & 15u];
            buf[17]=' '; buf[18]='L'; buf[19]='=';
            buf[20]=(char)hexd[(bo_reject_l >> 4) & 15u];
            buf[21]=(char)hexd[bo_reject_l & 15u];
            buf[22]=' '; buf[23]=' '; buf[24]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
