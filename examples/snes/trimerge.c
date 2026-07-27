// Three-Way Merge Diff — #99 of the compiler stress-test battery (Round 6, Cluster B).
// Re-stresses patch 0016 (#46) with the three-way-compare result used AS CONTROL FLOW: a 2-input
// merge branches on the sign of (a>b)-(a<b) — advance-left / emit-both / advance-right — at s32 and
// s64, via noinline comparators that keep G_SCMP alive. Distinct from #97/#98 which fed the compare
// to qsort (compared to 0). Builds default-8-bit AND +mos-a16 AND +mos-xy16 (5-way bar).
//
// Visual (#99b waterfall rework, 2026-07-27): the window is a 16-row merge-round HISTORY. Once per
// sweep a fresh round is merged at the top and older rounds flow down; each cell is coloured by
// WHICH branch of the three-way compare emitted it (advance-left / advance-right / EMIT-BOTH). The
// offset steps in whole stride units (0x10001) so consecutive rounds genuinely differ and the
// equal/emit-both branch fires periodically — the braid flows and yellow tie cells migrate through
// it. The branch palette breathes ±2/32 luma on a slow triangle wave. A wrong three-way branch
// would tear the ordering AND diverge the CRC. (Was: static rows — the old ×7 offset step was 4
// orders of magnitude below one stride unit, so no merge decision ever flipped; see
// docs/plans/2026-07-27-99b-trimerge-visual-fix.md.)
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/trimerge.h"

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
    uint8_t      cellcol[WIN_H][WIN_W];   // merge-round history (row 0 newest, flows down)
    uint16_t     pal[NCOL];               // breathing palette (queued by pointer — must persist)
    uint16_t     phase;
    uint16_t     t;
    uint8_t      band;
} App;

volatile uint16_t corpus_result;

// One waterfall step: history shifts down a row, then a fresh merge round enters at row 0. The
// offset steps in WHOLE stride units (0x10001) — cmp(L[i],R[j]) = sign((3i'-2j')*0x10001 + 2*off),
// so each phase step moves the decision boundary by 2 units of (3i'-2j') and ties (3i'-2j' == -2m,
// the emit-both branch) fire periodically. 64-phase cycle keeps |off| <= 32*0x10001 (~2.1M): stream
// values stay well inside int32. Each output cell is coloured by WHICH branch of the three-way
// compare emitted it — advance-left (1), advance-right (2), or emit-both (3).
static void push_row(App *a) {
    for (uint8_t r = (uint8_t)(WIN_H - 1u); r > 0u; r--)
        for (uint8_t c = 0u; c < (uint8_t)WIN_W; c++)
            a->cellcol[r][c] = a->cellcol[r - 1u][c];
    int32_t off = (int32_t)((int32_t)(a->phase & 63u) - (int32_t)32) * (int32_t)0x00010001;
    tm_fill32(_tm_l32, (uint16_t)TM_N, (int32_t)3, off);
    tm_fill32(_tm_r32, (uint16_t)TM_N, (int32_t)2, (int32_t)(-off));
    uint16_t i = 0u, j = 0u; uint8_t c = 0u;
    while (i < (uint16_t)TM_N && j < (uint16_t)TM_N && c < (uint8_t)WIN_W) {
        int cmp = tm_cmp32(_tm_l32[i], _tm_r32[j]);   // the three-way compare drives the branch
        if (cmp < 0)      { a->cellcol[0][c++] = 1u; i++; }                         // advance left
        else if (cmp > 0) { a->cellcol[0][c++] = 2u; j++; }                         // advance right
        else { a->cellcol[0][c++] = 3u; if (c < (uint8_t)WIN_W) a->cellcol[0][c++] = 3u; i++; j++; }  // emit both
    }
    while (c < (uint8_t)WIN_W) a->cellcol[0][c++] = (i < (uint16_t)TM_N) ? 1u : 2u;  // drained tail
    a->phase = (uint16_t)(a->phase + 1u);
}

// Shift every 5-bit channel of a BGR555 colour by d, clamped to 0..31.
static uint16_t shade(uint16_t rgb, int8_t d) {
    uint16_t out = 0u;
    for (uint8_t sh = 0u; sh < 15u; sh = (uint8_t)(sh + 5u)) {
        int8_t ch = (int8_t)((rgb >> sh) & 0x1Fu);
        ch = (int8_t)(ch + d);
        if (ch < 0) ch = 0;
        if (ch > 31) ch = 31;
        out |= (uint16_t)((uint16_t)ch << sh);
    }
    return out;
}

// Branch-palette breathing: +/-2 luma triangle over 32 sweeps; hue identity (teal/orange/yellow)
// preserved so the colours still read as the -1/0/+1 branches. 8-byte CGRAM job per sweep.
static void breathe_palette(App *a) {
    uint8_t ph = (uint8_t)(a->t & 31u);
    uint8_t tri = (ph <= 16u) ? ph : (uint8_t)(32u - ph);       // 0..16..0
    int8_t d = (int8_t)((int8_t)(tri >> 2) - (int8_t)2);        // -2..+2
    a->pal[0] = bg3_pal[0];
    for (uint8_t k = 1u; k < (uint8_t)NCOL; k++) a->pal[k] = shade(bg3_pal[k], d);
    upq_push_cgram(&a->screen.q, 0, a->pal, 0x00u, (uint8_t)sizeof a->pal);
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

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->phase = (uint16_t)0u;
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    for (uint8_t k = 0u; k < (uint8_t)WIN_H; k++) push_row(a);   // pre-fill the history window
    text_puts(&a->text, 0, 2, "THREE-WAY MERGE DIFF");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "TRIMERGE", "SPACESHIP AS CONTROL FLOW");
    corpus_result = trimerge_gate_crc();   // runs during title; expected 0xCCCC
    title_end(&a.screen, &title, 90);
    for (;;) {
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)WIN_H) {
            a.band = (uint8_t)0u;
            a.t = (uint16_t)(a.t + (uint16_t)1u);
            push_row(&a);            // waterfall: one new round at the top, history flows down
            breathe_palette(&a);
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}
