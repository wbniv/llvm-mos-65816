// Bit-Serial CRC Wall — #105 of the compiler stress-test battery (Round 6, Cluster D).
// The gate (examples/65816/crcwall.h) hashes bytes through three interleaved bit-serial CRC shift
// registers (CRC-8/16/32) under register pressure — re-stressing patch 0010 (the DEFAULT-8-bit
// coalesce-rotate-Ac miscompile that stranded a loop-carried CRC byte). Builds default-8-bit AND
// +mos-a16 AND +mos-xy16 (no far pointers → full 5-way bar); DEFAULT is the load-bearing leg.
//
// Visual: a flowing "hash marble" — each cell colour is a bit-serial CRC-8 of its (x,y,phase),
// so a corrupted loop-carried shift register would visibly scramble the marble AND diverge the CRC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/crcwall.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define BAND        4
#define GRID_W      16
#define GRID_H      16

// 4-colour marble palette (dark → light + warm accent).
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 3,  4,  9),    // 0: dark slate
    SNES_RGB(10, 12, 20),    // 1: mid blue-grey
    SNES_RGB(20, 22, 28),    // 2: light grey
    SNES_RGB(28, 18,  6),    // 3: amber vein
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
    uint8_t      band;
} App;

volatile uint16_t corpus_result;

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
    uint16_t tile = (uint16_t)((uint16_t)cy * (uint16_t)CANVAS_TILES_W + (uint16_t)cx);
    uint8_t *t = &cv->chr[tile * (uint16_t)CANVAS_TILEBYTES];
    uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
    uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
    for (uint8_t r = 0u; r < 8u; r++) { t[r * 2u] = p0; t[r * 2u + 1u] = p1; }
}

__attribute__((noinline))
static void field_band(App *a) {
    uint8_t phase = (uint8_t)(a->t >> 1);
    uint8_t y0 = (uint8_t)((uint8_t)(a->band) * (uint8_t)BAND);
    for (uint8_t cy = y0; cy < (uint8_t)(y0 + (uint8_t)BAND) && cy < (uint8_t)GRID_H; cy++) {
        for (uint8_t cx = 0u; cx < (uint8_t)GRID_W; cx++) {
            cell_fill(&a->canvas, cx, cy, cw_cell_color(cx, cy, phase));
        }
    }
    uint16_t lo = (uint16_t)((uint16_t)y0 * (uint16_t)CANVAS_TILES_W);
    uint16_t hi = (uint16_t)((uint16_t)(y0 + (uint8_t)BAND) * (uint16_t)CANVAS_TILES_W - (uint16_t)1u);
    if (hi >= (uint16_t)CANVAS_NTILES) hi = (uint16_t)(CANVAS_NTILES - (uint16_t)1u);
    if (a->canvas.lo > lo) a->canvas.lo = lo;
    if (a->canvas.hi < hi) a->canvas.hi = hi;
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='C'; buf[1]='R'; buf[2]='C'; buf[3]='8'; buf[4]='/'; buf[5]='1'; buf[6]='6'; buf[7]='/';
    buf[8]='3'; buf[9]='2'; buf[10]=' '; buf[11]='=';
    buf[12]=H[(corpus_result >> 12) & 0xFu]; buf[13]=H[(corpus_result >> 8) & 0xFu];
    buf[14]=H[(corpus_result >>  4) & 0xFu]; buf[15]=H[corpus_result & 0xFu];
    buf[16]=' '; buf[17]=' '; buf[18]=' '; buf[19]=' '; buf[20]='\0';
    text_puts(&a->text, 1, 0, buf);
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
    text_puts(&a->text, 0, 2, "CRC WALL  BIT-SERIAL");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "CRC WALL", "BIT-SERIAL SHIFT REG");
    corpus_result = crcwall_gate_crc();   // expected 0x8E47
    title_end(&a.screen, &title, 90);
    for (;;) {
        a.t++;
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)GRID_H) {
            a.band = (uint8_t)0u;
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}
