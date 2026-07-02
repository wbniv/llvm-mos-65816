// Borrow-Ladder Odometer — #110 of the compiler stress-test battery (Round 6, Cluster E).
// Re-stresses patch 0012 (LDCImm-set): a 128-bit descending odometer built from chained 16-bit
// subtracts-with-borrow whose carry-in is a set/clear i1 (SEC / LDCImm 1) before the SBC chain.
// Borrows ripple limb to limb as the number ticks down through zero. The a16/xy16 legs are
// load-bearing (0012 accum-gated); default 8-bit is the contrast. Builds all three (5-way bar).
//
// Visual: the 128 bits of the odometer drawn as a bit-grid (bright = 1); each frame it subtracts the
// decrement, so bits flip and borrows ripple across the field. A dropped/duplicated borrow (a wrong
// set-i1 carry) would corrupt the countdown AND diverge the CRC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/borrowlad.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define BAND        4
#define WIN_W       16
#define WIN_H       16

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 2,  3,  8),    // 0: bit 0 (upper half)
    SNES_RGB( 6,  8, 16),    // 1: bit 0 (lower half)
    SNES_RGB(20, 26, 12),    // 2: bit 1 (lower half)
    SNES_RGB(30, 30, 18),    // 3: bit 1 (upper half)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    U128         odo;
    U128         dec;
    uint8_t      cellcol[WIN_H][WIN_W];
    uint16_t     t;
    uint8_t      band;
} App;

volatile uint16_t corpus_result;

// Draw the 128 bits of the odometer over the 16×16 window (top and bottom halves mirror the bits with
// different palette so the ripple reads clearly).
static void recompute(App *a) {
    for (uint8_t r = 0u; r < (uint8_t)WIN_H; r++) {
        for (uint8_t c = 0u; c < (uint8_t)WIN_W; c++) {
            uint16_t bit_index = (uint16_t)((uint16_t)((uint8_t)(r & 7u)) * (uint16_t)WIN_W + (uint16_t)c);
            uint8_t limb = (uint8_t)(bit_index >> 4);           // /16
            uint8_t sh   = (uint8_t)(bit_index & 15u);          // %16
            uint8_t bit  = (uint8_t)((a->odo.w[limb] >> sh) & 1u);
            uint8_t upper = (uint8_t)(r < 8u);
            a->cellcol[r][c] = (uint8_t)(bit ? (upper ? 3u : 2u) : (upper ? 0u : 1u));
        }
    }
}

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
    uint16_t tile = (uint16_t)((uint16_t)cy * (uint16_t)CANVAS_TILES_W + (uint16_t)cx);
    uint8_t *t = &cv->chr[tile * (uint16_t)CANVAS_TILEBYTES];
    uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
    uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
    for (uint8_t r = 0u; r < 8u; r++) { t[r * 2u] = p0; t[r * 2u + 1u] = p1; }
}

__attribute__((noinline))
static void field_band(App *a) {
    uint8_t y0 = (uint8_t)((uint8_t)(a->band) * (uint8_t)BAND);
    for (uint8_t cy = y0; cy < (uint8_t)(y0 + (uint8_t)BAND) && cy < (uint8_t)WIN_H; cy++)
        for (uint8_t cx = 0u; cx < (uint8_t)WIN_W; cx++)
            cell_fill(&a->canvas, cx, cy, a->cellcol[cy][cx]);
    uint16_t lo = (uint16_t)((uint16_t)y0 * (uint16_t)CANVAS_TILES_W);
    uint16_t hi = (uint16_t)((uint16_t)(y0 + (uint8_t)BAND) * (uint16_t)CANVAS_TILES_W - (uint16_t)1u);
    if (hi >= (uint16_t)CANVAS_NTILES) hi = (uint16_t)(CANVAS_NTILES - (uint16_t)1u);
    if (a->canvas.lo > lo) a->canvas.lo = lo;
    if (a->canvas.hi < hi) a->canvas.hi = hi;
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='T'; buf[1]='=';
    buf[2]=H[(a->t >> 12) & 0xFu]; buf[3]=H[(a->t >> 8) & 0xFu];
    buf[4]=H[(a->t >>  4) & 0xFu]; buf[5]=H[a->t & 0xFu];
    buf[6]=' '; buf[7]='C'; buf[8]='R'; buf[9]='C'; buf[10]='=';
    buf[11]=H[(corpus_result >> 12) & 0xFu]; buf[12]=H[(corpus_result >> 8) & 0xFu];
    buf[13]=H[(corpus_result >>  4) & 0xFu]; buf[14]=H[corpus_result & 0xFu];
    buf[15]=' '; buf[16]=' '; buf[17]=' '; buf[18]=' '; buf[19]=' '; buf[20]='\0';
    text_puts(&a->text, 1, 0, buf);
}

static void reset_odo(App *a) {
    for (uint8_t i = 0u; i < (uint8_t)BL_LIMBS; i++) a->odo.w[i] = (uint16_t)0xFFFFu;
    a->odo.w[0] = (uint16_t)0x0003u;
    a->dec.w[0] = (uint16_t)0x9E37u; a->dec.w[1] = (uint16_t)0x79B9u;
    a->dec.w[2] = (uint16_t)0x7F4Au; a->dec.w[3] = (uint16_t)0x7C15u;
    a->dec.w[4] = (uint16_t)0xF39Cu; a->dec.w[5] = (uint16_t)0xC060u;
    a->dec.w[6] = (uint16_t)0x5CEDu; a->dec.w[7] = (uint16_t)0xC834u;
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    reset_odo(a);
    recompute(a);
    text_puts(&a->text, 0, 2, "BORROW-LADDER ODOMETER");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "BORROWLAD", "128-BIT BORROW CHAIN SBC");
    corpus_result = borrowlad_gate_crc();   // runs during title; expected 0x1BE3
    title_end(&a.screen, &title, 90);
    reset_odo(&a); recompute(&a);
    for (;;) {
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)WIN_H) {
            a.band = (uint8_t)0u;
            bl_sub(&a.odo, &a.dec);     // tick the odometer down (borrows ripple)
            recompute(&a);
            a.t = (uint16_t)(a.t + (uint16_t)1u);
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}
