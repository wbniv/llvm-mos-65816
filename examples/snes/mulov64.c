// 64-bit Multiply-Overflow / Multiply-High Sentinel — #101 of the compiler stress-test battery.
// Round 6 (harden-the-fixes), Cluster C, first pick. Renders an orbit-scatter on a 128x128 BG3
// canvas driven by __builtin_mul_overflow on uint64_t operands. Builds default-8-bit AND +mos-a16
// AND +mos-xy16 (no far pointers -> full 5-way bar).
//
// Codegen corner (the one untested s64 legalizer path, per the 2026-07-02 coverage check):
//   __builtin_mul_overflow on uint64_t/int64_t -> G_UMULO/G_SMULO at s64 (.lower() @301)
//     -> lowerMulo -> G_UMULH/G_SMULH at s64 (.lower() @312), which must compose the 128-bit
//        product from s32 (__mulsi3) pieces + s64 (__muldi3) glue WITHOUT widening to s128
//        (G_MUL is clampScalar(0,S8,S32) to avoid "infinite regress", @231/@237).
//   No prior demo forms an s64 mulh/mulo: #76 smulorbit was s16/s32, #56 rotozoom s32, #22
//   avalanche the LOW 64 bits only.
//
// Visual: 6 orbiters trace looping paths. Each carries a 64-bit momentum scaled by a growing
// factor via s64 mul-overflow; when it overflows, the orbiter teleports to the mirror quadrant
// and leaves a bright orange spark. The orbit density builds up over time.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/mulov64.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

// BG3 2bpp palette: black -> dim trail -> medium trail -> bright overflow spark.
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(4, 4, 18),           // 1: dim orbit trail (dark blue)
    SNES_RGB(6, 14, 28),          // 2: medium trail (brighter blue)
    SNES_RGB(31, 18, 2),          // 3: overflow spark (bright orange)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    MOrbiter     orbs[MO_N];
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    mo_init(a->orbs);
    a->t = (uint16_t)0u;
    text_puts(&a->text, 0, 2, "MULO64  G_UMULH/SMULH");
}

// Fade the canvas by halving plane-0 of every 4th tile: dims old trails without a full clear.
__attribute__((noinline))
static void fade_canvas(BitmapCanvas *cv) {
    for (uint16_t t = 0u; t < (uint16_t)CANVAS_NTILES; t += (uint16_t)4u) {
        uint8_t *p = &cv->chr[t * (uint16_t)CANVAS_TILEBYTES];
        for (uint8_t r = 0u; r < 8u; r++) p[r * 2u] = (uint8_t)(p[r * 2u] >> 1);
    }
    cv->lo = (uint16_t)0u;
    cv->hi = (uint16_t)(CANVAS_NTILES - 1u);
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "MULO 64", "64-BIT MUL OVERFLOW");
    corpus_result = mulov64_gate_crc();   // expected 0x3A69
    title_end(&a.screen, &title, 90);

    uint16_t spark_count = (uint16_t)0u;
    for (;;) {
        a.t++;
        if ((a.t & (uint16_t)7u) == (uint16_t)0u) fade_canvas(&a.canvas);
        for (uint8_t i = 0u; i < (uint8_t)MO_N; i++) {
            MOrbiter *o = &a.orbs[i];
            uint8_t color = mo_step(o, a.t);
            if (color == (uint8_t)3u) spark_count++;
            canvas_plot(&a.canvas, (int16_t)o->px, (int16_t)o->py, color);
        }
        char buf[21];
        buf[0]='O'; buf[1]='V'; buf[2]='F'; buf[3]='L'; buf[4]='O'; buf[5]='W';
        buf[6]='S'; buf[7]=':'; buf[8]=' ';
        buf[9]=(char)('0' + (char)((spark_count / (uint16_t)1000u) % (uint16_t)10u));
        buf[10]=(char)('0' + (char)((spark_count / (uint16_t)100u) % (uint16_t)10u));
        buf[11]=(char)('0' + (char)((spark_count / (uint16_t)10u) % (uint16_t)10u));
        buf[12]=(char)('0' + (char)(spark_count % (uint16_t)10u));
        buf[13]=' '; buf[14]=' '; buf[15]=' '; buf[16]=' '; buf[17]=' '; buf[18]=' ';
        buf[19]=' '; buf[20]='\0';
        text_puts(&a.text, 1, 0, buf);
        display_frame(&a.screen);
    }
}
