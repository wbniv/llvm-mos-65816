// Three-Way Merge Diff — #99 of the compiler stress-test battery (Round 6, Cluster B).
// Re-stresses patch 0016 (#46) with the three-way-compare result used AS CONTROL FLOW: a 2-input
// merge branches on the sign of (a>b)-(a<b) — advance-left / emit-both / advance-right — at s32 and
// s64, via noinline comparators that keep G_SCMP alive. Distinct from #97/#98 which fed the compare
// to qsort (compared to 0). Builds default-8-bit AND +mos-a16 AND +mos-xy16 (5-way bar).
//
// Visual (#99c 60 fps scroll-waterfall, 2026-07-27; supersedes the #99b repaint waterfall): the
// canvas's 16 tile rows are a 128-px VERTICAL SCROLL RING shown through a 15-row/120-px window —
// motion is BG3VOFS moving 1 px EVERY frame (true 60 fps), via per-scanline banded scroll
// (snesgfx/hdma_hscroll.h, double-buffered) so the HUD stays put and the ring wraps invisibly. The
// one always-off-screen row is the STAGING row: once every 8 frames the next merge round is
// painted there (16 tiles, 256 B — never a full-canvas repaint) and scrolls in at the top pixel by
// pixel. Each cell is coloured by WHICH branch of the three-way compare emitted it (advance-left /
// advance-right / EMIT-BOTH); the offset steps in whole stride units (0x10001) so consecutive
// rounds genuinely differ and the equal/emit-both branch fires periodically. The branch palette
// breathes ±2/32 luma. A wrong three-way branch would tear the ordering AND diverge the CRC.
// History: #99 shipped static rows (offset 4 orders below one stride unit — no decision ever
// flipped); #99b made it flow at ~10 Hz by full-canvas repaint. See
// docs/plans/2026-07-27-99c-trimerge-60fps-scroll-waterfall.md.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/backdrop_gradient.h"
#include "snesgfx/hdma_hscroll.h"
#include "../65816/trimerge.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 26          // bottom band scrolls +8, so row 26 lands at the old row-25 spot
#define NCOL        4
#define WIN_W       16
#define WIN_H       16          // ring height in tile rows (128 px)
#define VIS_PX      120u        // visible window: 15 rows; the 16th is the off-screen staging row
#define RING_PX     128u
#define CH_VSCROLL  6           // HDMA: ring scroll on ch6, backdrop vignette on ch7, upq GP-DMA ch0

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
    HScrollDB    vdb;                     // double-buffered vscroll band tables (bank-0 bss)
    uint16_t     pal[NCOL];               // breathing palette (queued by pointer — must persist)
    uint16_t     phase;
    uint16_t     t;
    uint8_t      pos;                     // ring offset P in [0,128): visible top = ring pixel P
} App;

volatile uint16_t corpus_result;

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color);

// Merge one fresh round and paint it into ring row `row` (16 tiles, marked dirty -> a 256 B flush;
// rows are painted once and never moved — the scroll ring does the reordering). The offset steps
// in WHOLE stride units (0x10001) — cmp(L[i],R[j]) = sign((3i'-2j')*0x10001 + 2*off), so each
// phase step moves the decision boundary by 2 units of (3i'-2j') and ties (3i'-2j' == -2m, the
// emit-both branch) fire periodically. 64-phase cycle keeps |off| <= 32*0x10001 (~2.1M): stream
// values stay well inside int32. Each output cell is coloured by WHICH branch of the three-way
// compare emitted it — advance-left (1), advance-right (2), or emit-both (3).
// Display-only incremental stream fill: same values as tm_fill32 (a[i] = (i - n/2)*u*mul + off,
// u = 0x10001) but built by repeated addition — tm_fill32's per-element 32-bit multiply is a
// __mulsi3 libcall, and 40 of them made the paint frame overrun v-blank (the measured every-9th-
// frame scroll stall). The GATE still uses the header's tm_fill32 untouched; the merge itself
// still calls the noinline tm_cmp32 (the G_SCMP under test) for every cell.
static void fill_ramp32(int32_t *dst, int32_t step, int32_t off) {
    int32_t v = (int32_t)(-(int32_t)(TM_N / 2u)) * step + off;   // one mul at entry, adds after
    for (uint16_t i = 0u; i < (uint16_t)TM_N; i++) { dst[i] = v; v += step; }
}

static void paint_row(App *a, uint8_t row) {
    int32_t off = (int32_t)((int32_t)(a->phase & 63u) - (int32_t)32) * (int32_t)0x00010001;
    fill_ramp32(_tm_l32, (int32_t)3 * (int32_t)0x00010001, off);
    fill_ramp32(_tm_r32, (int32_t)2 * (int32_t)0x00010001, (int32_t)(-off));
    uint8_t col[WIN_W];
    uint16_t i = 0u, j = 0u; uint8_t c = 0u;
    while (i < (uint16_t)TM_N && j < (uint16_t)TM_N && c < (uint8_t)WIN_W) {
        int cmp = tm_cmp32(_tm_l32[i], _tm_r32[j]);   // the three-way compare drives the branch
        if (cmp < 0)      { col[c++] = 1u; i++; }                         // advance left
        else if (cmp > 0) { col[c++] = 2u; j++; }                         // advance right
        else { col[c++] = 3u; if (c < (uint8_t)WIN_W) col[c++] = 3u; i++; j++; }  // emit both
    }
    while (c < (uint8_t)WIN_W) col[c++] = (i < (uint16_t)TM_N) ? 1u : 2u;  // drained tail
    for (uint8_t cx = 0u; cx < (uint8_t)WIN_W; cx++)
        cell_fill(&a->canvas, cx, row, col[cx]);
    uint16_t lo = (uint16_t)((uint16_t)row * (uint16_t)CANVAS_TILES_W);
    uint16_t hi = (uint16_t)(lo + (uint16_t)(WIN_W - 1u));
    if (a->canvas.lo > lo) a->canvas.lo = lo;
    if (a->canvas.hi < hi) a->canvas.hi = hi;
    a->phase = (uint16_t)(a->phase + 1u);
}

// Rebuild the per-scanline vertical-scroll band table for ring offset P (into the back half of the
// double buffer; committed through the v-blank queue so the engine never reads a half-built table).
// Screen bands (sum 224): title area 48 @ 0 · ring window part A · ring wrap part B (P > 8 only) ·
// bottom 56 @ +8 (skips the ring's last row so the staging row never shows; HUD text lives at map
// row 26, displayed at the old row-25 spot). At scanline y, mapY = y + vofs: part A shows ring
// pixels P..min(127, P+119), part B wraps to ring pixels 0..P-9.
static void build_bands(App *a, HScrollN *t) {
    HScrollW w;
    uint8_t P = a->pos;
    hscrollw_begin(&w, t);
    hscrollw_band(&w, 48u, (int16_t)0);
    if (P <= 8u) {
        hscrollw_band(&w, (uint8_t)VIS_PX, (int16_t)P);
    } else {
        hscrollw_band(&w, (uint8_t)(RING_PX - P), (int16_t)P);
        hscrollw_band(&w, (uint8_t)(P - 8u), (int16_t)((int16_t)P - (int16_t)RING_PX));
    }
    hscrollw_band(&w, 56u, (int16_t)8);
    hscrollw_end(&w);
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
// preserved so the colours still read as the -1/0/+1 branches. Pushes cgidx 1..3 only (6 B/sweep):
// colour 0 (the backdrop) is owned per-scanline by the HDMA gradient below.
static void breathe_palette(App *a) {
    uint8_t ph = (uint8_t)(a->t & 31u);
    uint8_t tri = (ph <= 16u) ? ph : (uint8_t)(32u - ph);       // 0..16..0
    int8_t d = (int8_t)((int8_t)(tri >> 2) - (int8_t)2);        // -2..+2
    for (uint8_t k = 1u; k < (uint8_t)NCOL; k++) a->pal[k] = shade(bg3_pal[k], d);
    upq_push_cgram(&a->screen.q, 1, &a->pal[1], 0x00u, (uint8_t)(sizeof a->pal - sizeof a->pal[0]));
}

// HDMA backdrop vignette (snesgfx/backdrop_gradient.h): near-black at the frame edges, deep
// blue-violet mid, so the braid box floats. Colour 0 never appears inside the painted field, so
// the gradient only shows outside the box. Channel 7 — clear of upq's GP-DMA ch0 and the title's
// HDMA channels (disarmed at title_end); armed once post-title, zero per-frame cost.
static const uint8_t grad_tab[] = {
    BDROP_SPAN(8, 0, 1,  5), BDROP_SPAN(8, 0, 1,  6), BDROP_SPAN(8, 1, 2,  8),
    BDROP_SPAN(8, 1, 2,  9), BDROP_SPAN(8, 1, 3, 10), BDROP_SPAN(8, 2, 3, 12),
    BDROP_SPAN(8, 2, 3, 13), BDROP_SPAN(8, 2, 4, 14), BDROP_SPAN(8, 2, 4, 15),
    BDROP_SPAN(8, 3, 4, 17), BDROP_SPAN(8, 3, 5, 18), BDROP_SPAN(8, 3, 5, 19),
    BDROP_SPAN(8, 4, 6, 21), BDROP_SPAN(8, 4, 6, 22), BDROP_SPAN(8, 4, 6, 22),
    BDROP_SPAN(8, 4, 6, 21), BDROP_SPAN(8, 3, 5, 19), BDROP_SPAN(8, 3, 5, 18),
    BDROP_SPAN(8, 3, 4, 17), BDROP_SPAN(8, 2, 4, 15), BDROP_SPAN(8, 2, 4, 14),
    BDROP_SPAN(8, 2, 3, 13), BDROP_SPAN(8, 2, 3, 12), BDROP_SPAN(8, 1, 3, 10),
    BDROP_SPAN(8, 1, 2,  9), BDROP_SPAN(8, 1, 2,  8), BDROP_SPAN(8, 0, 1,  6),
    BDROP_SPAN(8, 0, 1,  5),
    BDROP_END,
};

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
    uint16_t tile = (uint16_t)((uint16_t)cy * (uint16_t)CANVAS_TILES_W + (uint16_t)cx);
    uint8_t *t = &cv->chr[tile * (uint16_t)CANVAS_TILEBYTES];
    uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
    uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
    for (uint8_t r = 0u; r < 8u; r++) { t[r * 2u] = p0; t[r * 2u + 1u] = p1; }
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
    a->pos = (uint8_t)0u;
    // Pre-fill the ring bottom-up so at pos==0 the top row (0) holds the newest round.
    for (int8_t r = (int8_t)(WIN_H - 1); r >= 0; r--) paint_row(a, (uint8_t)r);
    text_puts(&a->text, 0, 2, "THREE-WAY MERGE DIFF");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "TRIMERGE", "SPACESHIP AS CONTROL FLOW");
    corpus_result = trimerge_gate_crc();   // runs during title; expected 0xCCCC
    title_end(&a.screen, &title, 90);
    build_bands(&a, &a.vdb.buf[0]);        // fill the live half before arming
    hscrolldb_arm(CH_VSCROLL, VSCROLL_BG3VOFS, &a.vdb);
    bdrop_arm(7, grad_tab);                // after title_end (which writes HDMAEN = 0)
    REG_HDMAEN = 0xC0u;                    // ch6 (ring scroll) + ch7 (vignette); title's stay off
    for (;;) {
        build_bands(&a, hscrolldb_back(&a.vdb));   // this frame's 1-px scroll step
        hscrolldb_commit(&a.vdb, &a.screen.q, CH_VSCROLL);
        uint8_t sub = (uint8_t)(a.pos & 7u);
        if (sub == 0u) {
            // The staging row (the one row fully off-screen right now) gets the next merge round;
            // its 256 B flush lands this v-blank, and it scrolls in at the top pixel by pixel.
            uint8_t staged = (uint8_t)(((uint8_t)(a.pos >> 3) + (uint8_t)(WIN_H - 1u)) & (uint8_t)(WIN_H - 1u));
            paint_row(&a, staged);
            a.t = (uint16_t)(a.t + (uint16_t)1u);
        } else if (sub == 4u) {
            // Staggered off the paint frame so no single iteration overruns the frame budget.
            breathe_palette(&a);
            update_hud(&a);
        }
        display_frame(&a.screen);
        a.pos = (uint8_t)((a.pos == 0u) ? (uint8_t)(RING_PX - 1u) : (uint8_t)(a.pos - 1u));
    }
}
