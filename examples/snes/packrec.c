// Unaligned Record Reader — #149 of the compiler stress-test battery.
// Round 8 (the un-entered backend paths), Cluster B. Builds default-8-bit AND +mos-a16 AND
// +mos-xy16 (no far pointers -> full 5-way bar); the headless 5-way gate is
// corpus/packrec_sim.c.
//
// REFRAMED, honestly — read examples/65816/packrec.h's header comment first. The ideas doc
// proposed __attribute__((packed)) as a distinct LOWERING; measured, it is not one on MOS,
// where every scalar already has ABI alignment 1 so an unpacked struct has no padding to
// remove and `packed` is a layout no-op (Round 8's second negative result). What this demo is
// for is the padding-free-layout INVARIANT, which no demo across #1-#141 asserts and on which
// every binary-format parse built with this toolchain silently depends.
//
// Visual: the raw byte stream drawn as a ruler, with each parsed record outlined and each
// field painted across exactly the bytes it occupies — so the 7- and 10-byte strides and the
// odd field offsets are visible as geometry rather than asserted in a comment.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/packrec.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4

#define STEP_FRAMES   5u
#define HOLD_FRAMES 120u
#define RULER_W      32     /* bytes per ruler row */

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: background
    SNES_RGB(6, 12, 20),          // 1: a tag byte — the only naturally-placed field
    SNES_RGB(10, 26, 14),         // 2: a 16-bit member at an odd offset
    SNES_RGB(31, 18, 6),          // 3: a 32-bit member at an odd offset
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

static uint16_t pr_rec;
static uint16_t pr_hold;

static const char hexd[17] = "0123456789ABCDEF";

// Paint one byte of the stream at its true position in the ruler.
static void byte_cell(BitmapCanvas *cv, uint16_t off, uint8_t color) {
    uint16_t o = (uint16_t)(off % (uint16_t)(RULER_W * 8u));
    int16_t bx = (int16_t)((int16_t)((int16_t)(o % (uint16_t)RULER_W) * (int16_t)4));
    int16_t by = (int16_t)((int16_t)((int16_t)(o / (uint16_t)RULER_W) * (int16_t)15) + (int16_t)4);
    for (int16_t dx = (int16_t)0; dx < (int16_t)3; dx++)
        for (int16_t dy = (int16_t)0; dy < (int16_t)11; dy++)
            canvas_plot(cv, (int16_t)(bx + dx), (int16_t)(by + dy), color);
}

// Paint one record: the tag byte, then each wide member across exactly its own bytes, at the
// offsets the _Static_assert block in packrec.h pins.
__attribute__((noinline))
static void draw_record(BitmapCanvas *cv, uint16_t r) {
    uint16_t off = pk_off[r];
    byte_cell(cv, off, (uint8_t)1u);
    if (pk_shape[r] == (uint8_t)0u) {
        for (uint8_t k = (uint8_t)1u; k < (uint8_t)3u; k++) byte_cell(cv, (uint16_t)(off + k), (uint8_t)2u);
        for (uint8_t k = (uint8_t)3u; k < (uint8_t)7u; k++) byte_cell(cv, (uint16_t)(off + k), (uint8_t)3u);
        for (uint8_t k = (uint8_t)7u; k < (uint8_t)9u; k++) byte_cell(cv, (uint16_t)(off + k), (uint8_t)2u);
        byte_cell(cv, (uint16_t)(off + 9u), (uint8_t)1u);
    } else {
        for (uint8_t k = (uint8_t)1u; k < (uint8_t)5u; k++) byte_cell(cv, (uint16_t)(off + k), (uint8_t)3u);
        for (uint8_t k = (uint8_t)5u; k < (uint8_t)7u; k++) byte_cell(cv, (uint16_t)(off + k), (uint8_t)2u);
    }
}

__attribute__((noinline))
static void parse_step(BitmapCanvas *cv) {
    if (pr_hold) {
        pr_hold--;
        if (pr_hold == (uint16_t)0u) { pr_rec = (uint16_t)0u; canvas_clear(cv); }
        return;
    }
    if (pr_rec >= pk_n) { pr_hold = (uint16_t)HOLD_FRAMES; return; }
    if (pr_rec > (uint16_t)0u
        && (pk_off[pr_rec] % (uint16_t)(RULER_W * 8u)) < (pk_off[(uint16_t)(pr_rec - 1u)]
                                                          % (uint16_t)(RULER_W * 8u)))
        canvas_clear(cv);
    draw_record(cv, pr_rec);
    pr_rec = (uint16_t)(pr_rec + 1u);
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
    text_puts(&a.text, 0, 1, "PACKREC  BYTE RULER");

    static TitleLayer title;
    title_begin16(&a.screen, &title, "PACKED RECORDS", "PACKREC");
    corpus_result = packrec_gate_crc();   // expected 0x4676
    title_end(&a.screen, &title, 90);

    pr_rec = (uint16_t)0u;
    pr_hold = (uint16_t)0u;

    for (;;) {
        a.t++;
        if ((a.t % (uint16_t)STEP_FRAMES) == (uint16_t)0u) {
            parse_step(&a.canvas);
            uint16_t r = pr_rec ? (uint16_t)(pr_rec - 1u) : (uint16_t)0u;
            char buf[25];
            buf[0]='R'; buf[1]='=';
            buf[2]=(char)hexd[(r >> 4) & 15u];
            buf[3]=(char)hexd[r & 15u];
            buf[4]=' '; buf[5]='O'; buf[6]='F'; buf[7]='F'; buf[8]='=';
            buf[9]=(char)hexd[(pk_off[r] >> 8) & 15u];
            buf[10]=(char)hexd[(pk_off[r] >> 4) & 15u];
            buf[11]=(char)hexd[pk_off[r] & 15u];
            buf[12]=' '; buf[13]='T'; buf[14]='=';
            buf[15]=(pk_shape[r] == (uint8_t)0u) ? 'A' : 'B';
            buf[16]=' '; buf[17]='O'; buf[18]='D'; buf[19]='D'; buf[20]='=';
            buf[21]=(char)hexd[(pk_odd_wide >> 4) & 15u];
            buf[22]=(char)hexd[pk_odd_wide & 15u];
            buf[23]=' '; buf[24]='\0';
            text_puts(&a.text, 1, 0, buf);
        }
        display_frame(&a.screen);
    }
}
