// Affine Stage Pipeline — #145 of the compiler stress-test battery.
// Round 8 (the un-entered backend paths), Cluster A. Builds default-8-bit AND +mos-a16 AND
// +mos-xy16 (no far pointers -> full 5-way bar); the headless 5-way gate is
// corpus/bigbyval_sim.c.
//
// Codegen corner: a record passed BY VALUE as an ARGUMENT when it is larger than 32 bits.
// MOSABIInfo::classifyArgumentType (clang/lib/CodeGen/Targets/MOS.cpp:64) routes it to
// getNaturalAlignIndirect(..., ByVal=false) at :71 — the callee receives a POINTER to storage
// the caller owns, so C's by-value semantics hold only because the front end materializes a
// temporary and copies into it at each call site. #91 matcascade validated the RETURN half of
// the same helper; no demo #1-#141 passes a >32-bit record by value.
//
// Visual: a 144-bit matrix travels by value through six stages, each of which mutates its own
// parameter before deriving the next. The wireframe object transformed by each stage is drawn
// in its own panel, with the driver's OWN matrix re-read after every call and shown as a 3x3
// grid — if a call-site copy were ever missing, that grid would drift stage to stage instead
// of standing still, and the panel of shapes would smear.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/bigbyval.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define STAGE_FRAMES 45u

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(6, 11, 20),          // 1: the re-read original matrix (must never move)
    SNES_RGB(12, 25, 22),         // 2: transformed wireframe
    SNES_RGB(31, 25, 11),         // 3: this stage's vertices
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint8_t  bz_stage;
static uint16_t bz_phase;

static const char hexd[17] = "0123456789ABCDEF";

// Draw one stage: its transformed vertex batch, and beneath it the driver's own matrix as
// re-read AFTER that stage's call — the observable a missing by-value copy would corrupt.
__attribute__((noinline))
static void stage_draw(BitmapCanvas *cv, uint8_t s) {
    canvas_clear(cv);
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)BV_VERTS; i++) {
        int16_t x = (int16_t)((int16_t)64 + (int16_t)(bv_vout[s][i].x >> 2));
        int16_t y = (int16_t)((int16_t)44 + (int16_t)(bv_vout[s][i].y >> 2));
        canvas_plot(cv, x, y, (uint8_t)3u);
        if (i != (uint8_t)0u) {
            int16_t px = (int16_t)((int16_t)64 + (int16_t)(bv_vout[s][i - 1u].x >> 2));
            int16_t py = (int16_t)((int16_t)44 + (int16_t)(bv_vout[s][i - 1u].y >> 2));
            canvas_line(cv, px, py, x, y, (uint8_t)2u);
        }
    }
    /* The re-read original, as a 3x3 bar grid. It must look IDENTICAL for every stage. */
    for (uint8_t r = (uint8_t)0u; r < (uint8_t)3u; r++)
        for (uint8_t c = (uint8_t)0u; c < (uint8_t)3u; c++) {
            int16_t v = bv_reread[s].m[(uint8_t)(r * 3u + c)];
            uint8_t w = (uint8_t)((uint8_t)((v + (int16_t)256) >> 5) & 15u);
            for (uint8_t k = (uint8_t)0u; k <= w; k++)
                canvas_plot(cv, (int16_t)((int16_t)((int16_t)c * (int16_t)18) + (int16_t)36 + (int16_t)k),
                            (int16_t)((int16_t)((int16_t)r * (int16_t)6) + (int16_t)100), (uint8_t)1u);
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
    text_puts(&a.text, 0, 1, "BIGBYVAL  144-BIT BY VALUE");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "144-BIT BY VALUE", "BIGBYVAL");
    corpus_result = bigbyval_gate_crc();   // expected 0xBD6B
    title_end(&a.screen, &title, 90);

    bz_stage = (uint8_t)0u;
    bz_phase = (uint16_t)0u;
    stage_draw(&a.canvas, bz_stage);

    uint16_t bad = bv_copy_violations();

    for (;;) {
        a.t++;
        bz_phase++;
        if (bz_phase >= (uint16_t)STAGE_FRAMES) {
            bz_phase = (uint16_t)0u;
            bz_stage = (uint8_t)((uint8_t)(bz_stage + 1u) % (uint8_t)BV_STAGES);
            stage_draw(&a.canvas, bz_stage);
        }
        if ((a.t & 7u) == 0u) {
            char buf[24];
            buf[0]='S'; buf[1]='T'; buf[2]='G'; buf[3]=' ';
            buf[4]=(char)('1' + (char)bz_stage);
            buf[5]='/'; buf[6]=(char)('0' + (char)BV_STAGES);
            buf[7]=' '; buf[8]='C'; buf[9]='O'; buf[10]='P'; buf[11]='Y';
            buf[12]='='; buf[13]=(bad == (uint16_t)0u) ? 'O' : 'X';
            buf[14]='K';
            buf[15]=' '; buf[16]='C'; buf[17]='=';
            buf[18]=(char)hexd[(corpus_result >> 12) & 15u];
            buf[19]=(char)hexd[(corpus_result >> 8) & 15u];
            buf[20]=(char)hexd[(corpus_result >> 4) & 15u];
            buf[21]=(char)hexd[corpus_result & 15u];
            buf[22]=' '; buf[23]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
