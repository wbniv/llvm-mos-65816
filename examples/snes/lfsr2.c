// Dual-LFSR Scrambler — #106 of the compiler stress-test battery (Round 6, Cluster D).
// Re-stresses patch 0010 (coalesce-rotate-Ac, a DEFAULT-8-bit register-coalescer miscompile) via
// TWO loop-carried 8-bit LFSRs (Galois + Fibonacci) + a 16-bit Galois, stepped simultaneously so
// their shift registers and feedbacks are live at once — the pressure that tempts the bad Ac join.
// The DEFAULT-8-bit build is the load-bearing leg (0010 is not accum-gated); also builds +mos-a16 /
// +mos-xy16 for the 5-way contrast.
//
// Visual: two interleaved pseudo-noise fields — Galois-driven cells on one diagonal parity, Fibonacci
// on the other — colour-mapped from the LFSR outputs, scrolling as the registers advance. A coalescer
// strand corrupting a loop-carried register would freeze/streak a field AND diverge the CRC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/lfsr2.h"

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
    SNES_RGB( 2,  4, 16),    // 0
    SNES_RGB( 6, 22, 10),    // 1: galois green
    SNES_RGB(26, 10,  4),    // 2: fibonacci red
    SNES_RGB(30, 28, 10),    // 3
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint8_t      cellcol[WIN_H][WIN_W];
    uint8_t      g8;    // live Galois-8 register (scrolls the field)
    uint8_t      f8;    // live Fibonacci-8 register
    uint16_t     t;
    uint8_t      band;
} App;

volatile uint16_t corpus_result;

// Recompute the two interleaved noise fields by replaying the LFSR streams from the live seeds.
static void recompute(App *a) {
    uint8_t g = a->g8, f = a->f8;
    for (uint8_t r = 0u; r < (uint8_t)WIN_H; r++) {
        for (uint8_t c = 0u; c < (uint8_t)WIN_W; c++) {
            g = lf_gal8_next(g);
            f = lf_fib8_next(f);
            // diagonal parity picks which stream colours the cell (two interleaved fields).
            if (((uint8_t)(r + c) & 1u) == 0u)
                a->cellcol[r][c] = (uint8_t)(1u + ((g >> 3) & 1u) * 2u);   // galois -> {1,3}
            else
                a->cellcol[r][c] = (uint8_t)((f >> 2) & 3u);               // fibonacci -> {0..3}
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

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->g8 = (uint8_t)0xACu;
    a->f8 = (uint8_t)0x1Du;
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    recompute(a);
    text_puts(&a->text, 0, 2, "DUAL-LFSR SCRAMBLER");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "LFSR2", "GALOIS+FIBONACCI ROTATE");
    corpus_result = lfsr2_gate_crc();   // runs during title; expected 0x6AA3
    title_end(&a.screen, &title, 90);
    for (;;) {
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)WIN_H) {
            a.band = (uint8_t)0u;
            a.canvas.lo = (uint16_t)0u;                        // shadow complete: mark the WHOLE
            a.canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);      // canvas -> one atomic v-blank flush
            // advance both live registers a few steps so the noise fields scroll.
            a.g8 = lf_gal8_next(a.g8);
            a.g8 = lf_gal8_next(a.g8);
            a.f8 = lf_fib8_next(a.f8);
            recompute(&a);
            a.t = (uint16_t)(a.t + (uint16_t)1u);
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}
