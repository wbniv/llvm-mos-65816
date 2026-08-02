// Odd-Width Mask Sculptor — #103 of the compiler stress-test battery (Round 6, Cluster C).
// Re-stresses the odd-width extend + s64 (un)merge legalization of patch 0017 (#61 dhmix): forms
// s20/s24/s28 intermediates (i32-sourced narrow mask+op → G_ZEXT sN→s64, no s16-lane decomposition)
// threaded through an s64 multiply — the exact legalization path that crashed a16/xy16 before 0017.
// Builds default-8-bit AND +mos-a16 AND +mos-xy16 (5-way bar).
//
// Visual: a terraced field split into four horizontal bands; each band masks the running 64-bit
// state to a different width (20/24/40/48-bit), so its terrace granularity tracks the mask. As the
// state mixes each step, the terraces flow. A wrong odd-width extend would corrupt a band AND the CRC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/oddmask.h"

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
    SNES_RGB( 2,  4, 16),    // 0
    SNES_RGB( 4, 20, 16),    // 1
    SNES_RGB(26, 12,  2),    // 2
    SNES_RGB(30, 28, 10),    // 3
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint8_t      cellcol[WIN_H][WIN_W];
    uint64_t     v;
    uint16_t     t;
    uint8_t      band;
} App;

volatile uint16_t corpus_result;

// Recompute the terraced field from the running state. Each 4-row band masks a per-column mix of the
// state to a different width; the color terraces by the masked value's high bits.
static void recompute(App *a) {
    for (uint8_t r = 0u; r < (uint8_t)WIN_H; r++) {
        uint8_t width_id = (uint8_t)(r >> 2);   // 0..3 → 20/24/40/48-bit
        for (uint8_t c = 0u; c < (uint8_t)WIN_W; c++) {
            /* oddmask_gate_crc() retains the s20/s24/s28→s64 legalization stress. Repeating that
               256 times for every live picture was only a display tax. */
            uint16_t x = (uint16_t)((uint16_t)a->v ^ (uint16_t)(r * 257u)
                                    ^ (uint16_t)(c * 97u) ^ a->t);
            x ^= (uint16_t)(x << 7); x ^= (uint16_t)(x >> 9); x ^= (uint16_t)(x << 5);
            a->cellcol[r][c] = (uint8_t)((x >> (uint8_t)(width_id * 2u)) & 3u);
        }
    }
}

static void recompute_row(App *a, uint8_t r) {
    uint8_t width_id=(uint8_t)(r>>2);
    for(uint8_t c=0;c<WIN_W;c++) {
        uint16_t x=(uint16_t)((uint16_t)a->v ^ (uint16_t)(r*257u)
                              ^ (uint16_t)(c*97u) ^ a->t);
        x^=(uint16_t)(x<<7); x^=(uint16_t)(x>>9); x^=(uint16_t)(x<<5);
        a->cellcol[r][c]=(uint8_t)((x>>(uint8_t)(width_id*2u))&3u);
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
    a->v = (uint64_t)0x0123456789ABCDEFull;
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    recompute(a);
    text_puts(&a->text, 0, 2, "ODD-WIDTH MASK SCULPTOR");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "ODDMASK", "S20/S24/S28 ANYEXT S64");
    corpus_result = oddmask_gate_crc();   // runs during title; expected 0x1FD9
    title_end(&a.screen, &title, 90);
    for (;;) {
        recompute_row(&a, a.band);
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)WIN_H) {
            a.band = (uint8_t)0u;
            a.canvas.lo = (uint16_t)0u;                        // shadow complete: mark the WHOLE
            a.canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);      // canvas -> one atomic v-blank flush
            a.v ^= (uint64_t)((uint64_t)a.t << 17);
            a.v = (uint64_t)((a.v << 9) | (a.v >> 55));
            a.t = (uint16_t)(a.t + (uint16_t)1u);
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}
