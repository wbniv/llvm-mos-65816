// Unsigned Rank Percentile Field — #98 of the compiler stress-test battery (Round 6, Cluster B).
// Re-stresses the UNSIGNED half of patch 0016 (#46 qsortviz): qsort with unsigned spaceship
// comparators (a>b)-(a<b) at uint16/uint32/uint64 forces G_UCMP at u16/u32/u64 (→ lowerThreewayCompare)
// — the unsigned three-way lowering no prior demo emitted (#46/#97 were signed G_SCMP). Builds
// default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> full 5-way bar).
//
// Visual: a 16×16 field of uint32 values, each cell recoloured by its RANK (percentile band) among
// all cells under unsigned ordering — low values one colour, high values another. Re-seeded
// periodically so the field re-sorts into fresh bands.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/ucmprank.h"

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
#define RESEED_BANDS 12u   // re-rank the field every RESEED_BANDS band-cycles

// 4-colour percentile ramp (low -> high rank).
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 2,  4, 16),    // 0: low   (deep blue)
    SNES_RGB( 4, 20, 16),    // 1:       (teal)
    SNES_RGB(26, 12,  2),    // 2:       (orange)
    SNES_RGB(30, 28, 10),    // 3: high  (bright gold)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    URField      field;
    uint16_t     seed;
    uint16_t     t;
    uint8_t      band;
    uint8_t      cycles;
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
    uint8_t y0 = (uint8_t)((uint8_t)(a->band) * (uint8_t)BAND);
    for (uint8_t cy = y0; cy < (uint8_t)(y0 + (uint8_t)BAND) && cy < (uint8_t)WIN_H; cy++) {
        for (uint8_t cx = 0u; cx < (uint8_t)WIN_W; cx++) {
            uint16_t idx = (uint16_t)((uint16_t)cy * (uint16_t)UR_GRID + (uint16_t)cx);
            cell_fill(&a->canvas, cx, cy, (uint8_t)(a->field.rank_color[idx] & 3u));
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
    buf[0]='T'; buf[1]='=';
    buf[2]=H[(a->t >> 12) & 0xFu]; buf[3]=H[(a->t >> 8) & 0xFu];
    buf[4]=H[(a->t >>  4) & 0xFu]; buf[5]=H[a->t & 0xFu];
    buf[6]=' '; buf[7]='C'; buf[8]='R'; buf[9]='C'; buf[10]='=';
    buf[11]=H[(corpus_result >> 12) & 0xFu]; buf[12]=H[(corpus_result >> 8) & 0xFu];
    buf[13]=H[(corpus_result >>  4) & 0xFu]; buf[14]=H[corpus_result & 0xFu];
    buf[15]=' '; buf[16]=' '; buf[17]=' '; buf[18]=' '; buf[19]=' '; buf[20]='\0';
    text_puts(&a->text, 1, 0, buf);
}

static void reseed_field(App *a) {
    a->seed ^= (uint16_t)(a->seed << 7); a->seed ^= (uint16_t)(a->seed >> 9); a->seed ^= (uint16_t)(a->seed << 8);
    ur_field_fill(&a->field, a->seed);
    ur_field_rank(&a->field);      // O(N^2) unsigned-ordering rank — recompute during force-blank-ish gap
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->seed = (uint16_t)0x1234u;
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    a->cycles = (uint8_t)0u;
    ur_field_fill(&a->field, a->seed);
    ur_field_rank(&a->field);
    text_puts(&a->text, 0, 2, "UNSIGNED RANK FIELD");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "UCMPRANK", "UNSIGNED THREE-WAY U64");
    corpus_result = ucmprank_gate_crc();   // runs during title; expected 0x4CDD
    title_end(&a.screen, &title, 90);
    for (;;) {
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)WIN_H) {
            a.band = (uint8_t)0u;
            a.t = (uint16_t)(a.t + (uint16_t)1u);
            update_hud(&a);
            a.cycles++;
            if (a.cycles >= (uint8_t)RESEED_BANDS) { a.cycles = (uint8_t)0u; reseed_field(&a); }
        }
        display_frame(&a.screen);
    }
}
