// Overflow Family Matrix — #155 of the compiler stress-test battery.
// Round 8 (the un-entered backend paths), Cluster C. Builds default-8-bit AND +mos-a16 AND
// +mos-xy16 (no far pointers -> full 5-way bar); the headless 5-way gate is
// corpus/ovmatrix_sim.c.
//
// Codegen corner: all six overflow opcodes — G_UADDO/G_SADDO, G_USUBO/G_SSUBO, G_UMULO/G_SMULO
// — at all three widths in ONE noinline kernel, so the signed and unsigned forms of each family
// are selected and register-allocated next to each other under real pressure. #44, #76, #101
// and #144 each test one family, at one or two widths, in a loop of its own.
//
// Measured, and it changed the design: a probe with one CONSTANT operand per builtin folded
// cells away outright and lost G_SSUBO entirely. So both operands of every cell come from
// runtime state, and the gate asserts every one of the 18 cells fired BOTH outcomes.
//
// Visual: the matrix itself. Eighteen cells in a 6x3 grid — three families down, three widths
// across, unsigned and signed side by side — each drawn as a two-tone bar whose split is that
// cell's overflow-to-clean ratio. A cell that never overflowed, or always did, would show as a
// solid bar, and that is exactly the degenerate coverage the gate refuses.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/ovmatrix.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define STEP_FRAMES  10u
#define HOLD_FRAMES 150u

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(7, 11, 20),          // 1: the cell's frame
    SNES_RGB(10, 26, 14),         // 2: the CLEAN share of the cell
    SNES_RGB(30, 12, 8),          // 3: the OVERFLOW share of the cell
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint16_t oz_cell;
static uint16_t oz_hold;

static const char hexd[17] = "0123456789ABCDEF";

// One cell: a 36-wide bar split at its overflow ratio. Row = family*2 + signedness,
// column = width.
__attribute__((noinline))
static void draw_cell(BitmapCanvas *cv, uint8_t c) {
    uint8_t fam  = (uint8_t)(c / 6u);
    uint8_t wid  = (uint8_t)((c % 6u) / 2u);
    uint8_t sgn  = (uint8_t)(c & 1u);
    int16_t x0 = (int16_t)((int16_t)wid * (int16_t)42 + (int16_t)2);
    int16_t y0 = (int16_t)((int16_t)((fam * 2u) + sgn) * (int16_t)20 + (int16_t)4);

    uint16_t fire = ov_fire[c];
    uint16_t tot  = (uint16_t)(fire + ov_clean[c]);
    uint16_t split = tot ? (uint16_t)(((uint32_t)fire * 36u) / (uint32_t)tot) : (uint16_t)0u;

    for (int16_t x = (int16_t)0; x < (int16_t)36; x++) {
        uint8_t col = (x < (int16_t)split) ? (uint8_t)3u : (uint8_t)2u;
        for (int16_t h = (int16_t)0; h < (int16_t)6; h++)
            canvas_plot(cv, (int16_t)(x0 + x), (int16_t)(y0 + h), col);
    }
    for (int16_t x = (int16_t)-1; x < (int16_t)37; x++) {
        canvas_plot(cv, (int16_t)(x0 + x), (int16_t)(y0 - 1), (uint8_t)1u);
        canvas_plot(cv, (int16_t)(x0 + x), (int16_t)(y0 + 6), (uint8_t)1u);
    }
}

__attribute__((noinline))
static void matrix_step(BitmapCanvas *cv) {
    if (oz_hold) {
        oz_hold--;
        if (oz_hold == (uint16_t)0u) { oz_cell = (uint16_t)0u; canvas_clear(cv); }
        return;
    }
    if (oz_cell >= (uint16_t)OV_CELLS) { oz_hold = (uint16_t)HOLD_FRAMES; return; }
    draw_cell(cv, (uint8_t)oz_cell);
    oz_cell = (uint16_t)(oz_cell + 1u);
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
    text_puts(&a.text, 0, 1, "OVMATRIX  18 CELLS");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "OVERFLOW MATRIX", "OVMATRIX");
    corpus_result = ovmatrix_gate_crc();    // expected 0xD4D0
    title_end(&a.screen, &title, 90);

    oz_cell = (uint16_t)0u;
    oz_hold = (uint16_t)0u;

    uint8_t two = ov_two_sided_cells();

    for (;;) {
        a.t++;
        if ((a.t % (uint16_t)STEP_FRAMES) == (uint16_t)0u) {
            matrix_step(&a.canvas);
            char buf[25];
            buf[0]='2'; buf[1]='S'; buf[2]='I'; buf[3]='D'; buf[4]='E'; buf[5]='=';
            buf[6]=(char)hexd[(two >> 4) & 15u];
            buf[7]=(char)hexd[two & 15u];
            buf[8]='/'; buf[9]='1'; buf[10]='2';
            buf[11]=' '; buf[12]='C'; buf[13]='E'; buf[14]='L'; buf[15]='L'; buf[16]='=';
            buf[17]=(char)hexd[(oz_cell >> 4) & 15u];
            buf[18]=(char)hexd[oz_cell & 15u];
            buf[19]=' '; buf[20]='C'; buf[21]='=';
            buf[22]=(char)hexd[(corpus_result >> 12) & 15u];
            buf[23]=(char)hexd[(corpus_result >> 8) & 15u];
            buf[24]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
