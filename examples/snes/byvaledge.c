// By-Value Boundary Trio — #154 of the compiler stress-test battery.
// Round 8 (the un-entered backend paths), Cluster C. Builds default-8-bit AND +mos-a16 AND
// +mos-xy16 (no far pointers -> full 5-way bar); the headless 5-way gate is
// corpus/byvaledge_sim.c.
//
// Codegen corner: clang's `getTypeSize(Ty) > 32` by-value classifier (Targets/MOS.cpp), compiled
// from BOTH sides adjacently. A 4-byte record goes getDirect (scalars in registers); a 5-byte
// record goes getNaturalAlignIndirect with ByVal=false, so the callee gets a pointer to the
// CALLER's object and by-value semantics rest entirely on a call-site copy. Every stage mutates
// its own parameter and the driver re-reads its original afterwards — a missing copy is
// otherwise completely silent.
//
// Measured correction recorded in the header: there is no 33-bit size class on MOS. getTypeSize
// is in bits and a record is always whole bytes, so a record declaring 33 bits of bitfield is
// sizeof 5 (40 bits) and takes the indirect path. The boundary is sizeof 4 vs sizeof 5.
//
// THIS DEMO FOUND AN OPEN COMPILER DEFECT. Its 5-byte stage originally derived its result with a
// 16x16 multiply, which puts a libcall between a byte member and a word member of the same
// pointed-to record — an upstream llvm-mos register-allocation failure ("ran out of registers",
// -O1 and above, reproduced on pristine upstream llc at -mcpu=mos6502). See
// docs/investigations/2026-09-16-mos-regalloc-out-of-registers-mixed-width-pointer-plus-call.md.
// The multiply is not the corner under test, so it was removed from that stage and the demo
// ships gated; nothing about the ABI check was weakened.
//
// Visual: three lanes, one per record shape, with each lane's stage outputs plotted as a trace
// and the caller's re-read of its own original drawn beneath it as a steady baseline. The
// baseline staying flat IS the by-value contract holding.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/byvaledge.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define PLOT_PER_FRAME 2u
#define HOLD_FRAMES  150u

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(22, 10, 8),          // 1: the 4-byte lane   (32 bits, getDirect)
    SNES_RGB(10, 24, 14),         // 2: the 33-bit lane   (sizeof 5 -> indirect)
    SNES_RGB(28, 24, 10),         // 3: the 5-byte lane   (40 bits, indirect)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint16_t bz_next;
static uint16_t bz_hold;

static const char hexd[17] = "0123456789ABCDEF";

// One step of all three lanes. Each lane occupies a 40-pixel band: the stage output as a
// scatter in the upper part, the caller's re-read as a baseline dot in the lower part.
__attribute__((noinline))
static void plot_lane(BitmapCanvas *cv, uint16_t i, uint8_t lane, uint16_t out, uint16_t reread) {
    int16_t x = (int16_t)((uint16_t)i + (uint16_t)16u);
    int16_t top = (int16_t)((int16_t)lane * (int16_t)42);
    canvas_plot(cv, x, (int16_t)(top + (int16_t)((out >> 11) & 0x1Fu) + 2), (uint8_t)(lane + 1u));
    canvas_plot(cv, x, (int16_t)(top + (int16_t)36 - (int16_t)((reread >> 13) & 3u)),
                (uint8_t)1u);
}

__attribute__((noinline))
static void plot_step(BitmapCanvas *cv) {
    if (bz_hold) {
        bz_hold--;
        if (bz_hold == (uint16_t)0u) { bz_next = (uint16_t)0u; canvas_clear(cv); }
        return;
    }
    for (uint8_t n = (uint8_t)0u; n < (uint8_t)PLOT_PER_FRAME; n++) {
        if (bz_next >= bv_n) { bz_hold = (uint16_t)HOLD_FRAMES; return; }
        plot_lane(cv, bz_next, (uint8_t)0u, bv_out32[bz_next][0], bv_reread[bz_next][0]);
        plot_lane(cv, bz_next, (uint8_t)1u,
                  (uint16_t)(bv_out33[bz_next] & 0xFFFFu), bv_reread[bz_next][1]);
        plot_lane(cv, bz_next, (uint8_t)2u, bv_out40[bz_next][0], bv_reread[bz_next][2]);
        bz_next++;
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
    text_puts(&a.text, 0, 1, "BY-VALUE  32 VS 40 BIT");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "BY-VALUE", "BOUNDARY TRIO");
    corpus_result = byvaledge_gate_crc();    // expected 0x4FAB
    title_end(&a.screen, &title, 90);

    bz_next = (uint16_t)0u;
    bz_hold = (uint16_t)0u;

    uint16_t bad = bv_violations();

    for (;;) {
        a.t++;
        if ((a.t & 1u) == 0u) {
            plot_step(&a.canvas);
            char buf[25];
            buf[0]='S'; buf[1]='Z'; buf[2]=' ';
            buf[3]=(char)hexd[sizeof(BvR32) & 15u];
            buf[4]='/';
            buf[5]=(char)hexd[sizeof(BvR33) & 15u];
            buf[6]='/';
            buf[7]=(char)hexd[sizeof(BvR40) & 15u];
            buf[8]=' '; buf[9]='B'; buf[10]='A'; buf[11]='D'; buf[12]='=';
            buf[13]=(char)hexd[(bad >> 4) & 15u];
            buf[14]=(char)hexd[bad & 15u];
            buf[15]=' '; buf[16]='N'; buf[17]='=';
            buf[18]=(char)hexd[(bz_next >> 8) & 15u];
            buf[19]=(char)hexd[(bz_next >> 4) & 15u];
            buf[20]=(char)hexd[bz_next & 15u];
            buf[21]=' '; buf[22]=' '; buf[23]=' '; buf[24]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
