// Serial Bit-Reversal Weave — #107 of the compiler stress-test battery (Round 6, Cluster D).
// Re-stresses patch 0010 (coalesce-rotate-Ac, a DEFAULT-8-bit register-coalescer miscompile) via a
// serial rotate-out/rotate-in bit-reversal carry loop (loop-carried `rev` register rotated on the
// back edge) — a deliberate contrast to #54 bitshuffle's __builtin_bitreverse mask-swap cascade.
// The DEFAULT-8-bit build is the load-bearing leg (0010 not accum-gated); also builds a16/xy16.
//
// Visual: a diagonal gradient displayed through its BIT-REVERSED permutation — position p shows the
// gradient sampled at bit_rev8(p), the characteristic FFT-style bit-reversal weave — with the base
// gradient scrolling so the weave flows. A coalescer strand corrupting the loop-carried `rev` would
// scramble the weave AND diverge the CRC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/bitweave.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define BAND        1
#define WIN_W       16
#define WIN_H       16

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 2,  4, 16),
    SNES_RGB( 4, 20, 16),
    SNES_RGB(26, 12,  2),
    SNES_RGB(30, 28, 10),
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint8_t      cellcol[WIN_H][WIN_W];
    uint8_t      phase;
    uint16_t     t;
    uint8_t      band;
} App;

volatile uint16_t corpus_result;

// Base gradient colour for a linear index i (0..255): a diagonal ramp that scrolls with phase.
static inline uint8_t base_color(uint8_t i, uint8_t phase) {
    return (uint8_t)((uint8_t)(((i >> 4) + (i & 0x0Fu) + phase)) & 3u);
}

// Recompute the field: position p (0..255) shows the gradient sampled at bit_rev8(p).
static void recompute(App *a) {
    for (uint8_t r = 0u; r < (uint8_t)WIN_H; r++) {
        for (uint8_t c = 0u; c < (uint8_t)WIN_W; c++) {
            uint8_t p = (uint8_t)((uint8_t)(r << 4) | c);   // 0..255 linear position
            uint8_t src = bw_rev8(p);                       // bit-reversed source index
            a->cellcol[r][c] = base_color(src, a->phase);
        }
    }
}

static void recompute_row(App *a, uint8_t r) {
    for (uint8_t c=0; c<WIN_W; c++) {
        uint8_t p=(uint8_t)((r<<4)|c);
        a->cellcol[r][c]=base_color(bw_rev8(p),a->phase);
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
            canvas_fill_solid_tile(&a->canvas, cx, cy, a->cellcol[cy][cx]);
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
    a->phase = (uint8_t)0u;
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    recompute(a);
    text_puts(&a->text, 0, 2, "SERIAL BIT-REVERSAL WEAVE");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "BITWEAVE", "ROTATE-OUT ROTATE-IN LOOP");
    corpus_result = bitweave_gate_crc();   // runs during title; expected 0x0E03
    title_end(&a.screen, &title, 90);
    for (;;) {
        recompute_row(&a, a.band);
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)WIN_H) {
            a.band = (uint8_t)0u;
            a.canvas.lo = (uint16_t)0u;                        // shadow complete: mark the WHOLE
            a.canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);      // canvas -> one atomic v-blank flush
            a.phase++;
            a.t = (uint16_t)(a.t + (uint16_t)1u);
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}
