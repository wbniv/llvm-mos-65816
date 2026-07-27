// 64-bit Multi-Key Record Sort — #100 of the compiler stress-test battery (Round 6, Cluster B final).
// Re-stresses patch 0016 (#46) at the extreme width: libc qsort of records with a CHAINED comparator
// — primary int64 spaceship, tie-broken by a second int64 spaceship → G_SCMP s64 TWICE per call,
// with a data-dependent short-circuit (the tie-break only runs when the primary is equal). Builds
// default-8-bit AND +mos-a16 AND +mos-xy16 (5-way bar).
//
// Visual: 16 sorted records as rows; left half of each row is coloured by the primary key band
// (strictly non-decreasing down the screen), right half by the secondary key (sorted within each
// primary-tie group). Re-seeds + re-sorts periodically, so the rows visibly reorder under the
// two-level key. A wrong s64 three-way lowering (primary or tie-break) reorders wrong AND diverges CRC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/keycmp64.h"

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
    SNES_RGB( 4, 20, 16),    // 1
    SNES_RGB(26, 12,  2),    // 2
    SNES_RGB(30, 28, 10),    // 3
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint8_t      cellcol[WIN_H][WIN_W];
    uint16_t     seed;
    uint16_t     t;
    uint8_t      band;
    uint8_t      cycles;
} App;

volatile uint16_t corpus_result;

static inline uint8_t k1_band(int64_t v) { return (uint8_t)(((uint32_t)((int32_t)v + 3)) & 3u); }        // -3..3 → 0..3
static inline uint8_t k2_band(int64_t v) { uint64_t u = (uint64_t)v; return (uint8_t)((u >> 62) & 3u); }  // top 2 bits

static void resort(App *a) {
    kc_fill(_kc, (uint16_t)KC_N, a->seed);
    qsort(_kc, (size_t)KC_N, sizeof _kc[0], kc_cmp);
    for (uint8_t r = 0u; r < (uint8_t)WIN_H; r++) {
        uint8_t b1 = k1_band(_kc[r].k1);
        uint8_t b2 = k2_band(_kc[r].k2);
        for (uint8_t c = 0u; c < (uint8_t)WIN_W; c++)
            a->cellcol[r][c] = (c < 8u) ? b1 : b2;
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
    a->seed = (uint16_t)0x7A5Cu;
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    a->cycles = (uint8_t)0u;
    resort(a);
    text_puts(&a->text, 0, 2, "64-BIT MULTI-KEY SORT");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "KEYCMP64", "CHAINED S64 SPACESHIP");
    corpus_result = keycmp64_gate_crc();   // runs during title; expected 0xB8AD
    title_end(&a.screen, &title, 90);
    a.seed = (uint16_t)0x7A5Cu; resort(&a);   // gate consumed _kc; restart the live view
    for (;;) {
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)WIN_H) {
            a.band = (uint8_t)0u;
            a.canvas.lo = (uint16_t)0u;                        // shadow complete: mark the WHOLE
            a.canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);      // canvas -> one atomic v-blank flush
            a.t = (uint16_t)(a.t + (uint16_t)1u);
            update_hud(&a);
            a.cycles++;
            if (a.cycles >= (uint8_t)10u) {
                a.cycles = (uint8_t)0u;
                a.seed ^= (uint16_t)(a.seed << 7); a.seed ^= (uint16_t)(a.seed >> 9); a.seed ^= (uint16_t)(a.seed << 8);
                resort(&a);
            }
        }
        display_frame(&a.screen);
    }
}
