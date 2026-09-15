// Precision Bridge — #146 of the compiler stress-test battery.
// Round 8 (the un-entered backend paths), Cluster B. Builds default-8-bit AND +mos-a16 AND
// +mos-xy16 (no far pointers -> full 5-way bar); the headless 5-way gate is
// corpus/dblbridge_sim.c.
//
// Codegen corner: G_FPEXT S32->S64 and G_FPTRUNC S64->S32 (MOSLegalizerInfo.cpp:375 / :376,
// both .libcallFor) -> __extendsfdf2 / __truncdfsf2. ZERO corpus slices across demos #1-#141
// link either symbol; #57 mandel-double runs a double escape loop and a float twin but never
// converts between them (only __floatunsidf, integer->double).
//
// Visual: the same chaotic map iterated two ways over identical binary32 state — lane A
// wholly at float, lane B promoted to double for the step and demoted back each iteration.
// The two traces start on top of each other and separate; the divergence step is drawn as a
// vertical marker.
//
// ROM-SIZE CONSTRAINT — must precede the title_layer.h include, and is why this demo's
// markers differ from the rest of Cluster B. MEASURED: linked against the plain `snes`
// platform this overflows the 32 KB NEAR window $8000-$FFAF by 5,299 bytes. The double
// soft-float library is what does it — __adddf3 + __muldf3 alone are ~12 KB, and this demo
// links the FLOAT twin (__subsf3/__mulsf3, ~5.5 KB) as well, because running both precisions
// side by side is the entire point. That near window is fixed by the LoROM bank mapping; you
// do not enlarge it, you go PAST it by banking, which is precisely the contract #57
// mandel-double already established for exactly this reason. So:
//
// mos-a16-only — far pointers are 32-bit, so the far platform needs +mos-a16.
// snes-far-platform — build against platforms/snes-far (mos-snes-far.cfg), NOT plain snes.
//   Grepped by every build path (dev/build.sh, dev/dblbridge.sh) so the platform choice
//   cannot drift into one script.
// TITLE_FONT16_FAR parks title_layer's 4 KB FONT16 Waldo table in bank $01 .far_rodata; it is
//   const and read once at title upload. The ROM becomes 64 KB — trivial for a cartridge.
//
// This changes NOTHING about the differential: the 5-way gate is the HAL-free corpus slice
// (corpus/dblbridge_sim.c), which links no HAL, needs no far pointers, and is compiled and
// asserted in all three modes — default, +mos-a16 and +mos-xy16 — by dev/run.sh corpus-a16
// and by this demo's own structure gate.
#ifndef TITLE_FONT16_FAR
#define TITLE_FONT16_FAR
#endif

#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/dblbridge.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define STEP_FRAMES   4u
#define HOLD_FRAMES 120u

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(8, 20, 31),          // 1: lane A — pure float
    SNES_RGB(31, 24, 6),          // 2: lane B — promoted/demoted through double
    SNES_RGB(31, 6, 6),           // 3: the divergence marker
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint8_t  pb_orb;     /* orbit on screen  */
static uint8_t  pb_step;    /* step revealed    */
static uint16_t pb_hold;

static const char hexd[17] = "0123456789ABCDEF";

// Reveal one more step of the current orbit: plot both lanes, and once the divergence step is
// reached, drop a red column so the separation point is visible rather than inferred.
__attribute__((noinline))
static void step_reveal(BitmapCanvas *cv) {
    if (pb_hold) {
        pb_hold--;
        if (pb_hold == (uint16_t)0u) {
            canvas_clear(cv);
            pb_step = (uint8_t)0u;
            pb_orb = (uint8_t)((uint8_t)(pb_orb + (uint8_t)1u) % (uint8_t)DB_ORB);
        }
        return;
    }
    if (pb_step >= (uint8_t)DB_STEPS) { pb_hold = (uint16_t)HOLD_FRAMES; return; }

    int16_t x = (int16_t)((int16_t)pb_step * (int16_t)2);
    int16_t ya = (int16_t)((int16_t)DB_PLOTH + (int16_t)14 - (int16_t)db_ya[pb_orb][pb_step]);
    int16_t yb = (int16_t)((int16_t)DB_PLOTH + (int16_t)14 - (int16_t)db_yb[pb_orb][pb_step]);

    canvas_plot(cv, x, ya, (uint8_t)1u);
    canvas_plot(cv, (int16_t)(x + 1), ya, (uint8_t)1u);
    canvas_plot(cv, x, yb, (uint8_t)2u);

    if (pb_step == db_div[pb_orb]) {
        for (int16_t k = (int16_t)8; k < (int16_t)118; k = (int16_t)(k + 3))
            canvas_plot(cv, x, k, (uint8_t)3u);
    }
    pb_step = (uint8_t)(pb_step + 1u);
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
    text_puts(&a.text, 0, 1, "DBLBRIDGE FLOAT VS DOUBLE");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "PRECISION BRIDGE", "DBLBRIDGE");
    corpus_result = dblbridge_gate_crc();   // expected 0xF829
    title_end(&a.screen, &title, 90);

    pb_orb = (uint8_t)0u;
    pb_step = (uint8_t)0u;
    pb_hold = (uint16_t)0u;

    for (;;) {
        a.t++;
        if ((a.t % (uint16_t)STEP_FRAMES) == (uint16_t)0u) {
            step_reveal(&a.canvas);
            /* HUD built from a template + a nibble table rather than 23 open-coded
               stores: this demo is within a few hundred bytes of the LoROM near window
               (see the ROM-SIZE CONSTRAINT block above), so the loop form is not style. */
            static char buf[] = "ORB=0 DIV=00 DS=00 S=00 ";
            static const uint8_t slot[7] = { 4, 10, 11, 16, 17, 21, 22 };
            uint8_t nib[7];
            nib[0] = (uint8_t)(pb_orb & 15u);
            nib[1] = (uint8_t)((db_div[pb_orb] >> 4) & 15u);
            nib[2] = (uint8_t)(db_div[pb_orb] & 15u);
            nib[3] = (uint8_t)((db_dis[pb_orb] >> 4) & 15u);
            nib[4] = (uint8_t)(db_dis[pb_orb] & 15u);
            nib[5] = (uint8_t)((pb_step >> 4) & 15u);
            nib[6] = (uint8_t)(pb_step & 15u);
            for (uint8_t k = (uint8_t)0u; k < (uint8_t)7u; k++)
                buf[slot[k]] = (char)hexd[nib[k]];
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
