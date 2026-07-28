// Descending memmove Scroll Slabs — #79 of the compiler stress-test demo battery.
// Renders the portable memmove scroll (examples/65816/mvscrl.h) on the 128x128 BG3
// 2bpp canvas; builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers →
// full 5-way bar).
//
// The codegen corner: G_MEMMOVE at MOSLegalizerInfo.cpp:422 (.custom()).
//   memmove(&upper[1][0], &upper[0][0], 7×16) — dst > src, overlapping → Descending=true
//   memmove(&lower[0][0], &lower[1][0], 7×16) — dst < src, overlapping → Ascending
// descending detection: compareOperandLocations :3145-3152 returns −1 for G_MEMMOVE,
// sets Descending=true; offset adjusts :3231/:3247.
// SDK memmove: llvm-mos-sdk mos-platform/common/c/mem.c:15.
// Distinct from #23 lsystem (memmove incidental, non-overlapping) and #49 lzdec
// (overlapping back-ref copy byte-by-byte, never emits G_MEMMOVE).
//
// Visual (#128-era F2 scroll-ring, 2026-07-28; supersedes the per-frame band repaint): the two
// 8-tile halves are each a 64-px VERTICAL SCROLL RING shown through a 7-row/56-px window, so
// motion is BG3VOFS moving 1 px EVERY frame — true 60 fps — in OPPOSITE directions (upper flows
// down, lower flows up). Per-scanline banded scroll (snesgfx/hdma_hscroll.h, double-buffered)
// gives the two rings different VOFS on their own scanlines while the HUD stays put and each ring
// wraps invisibly. The always-off-screen 8th row of each half is that ring's STAGING row: once
// every 8 frames one mv_step runs and the two staged rows are painted (16 tiles each), then scroll
// in pixel by pixel. Rows are painted once and never moved — the scroll does the reordering.
//
// The staged rows are read from the FAR end of each buffer — upper[7] and lower[0], the rows that
// have been carried by SEVEN memmoves — not from the freshly injected end. That keeps #79's
// premise intact under the ring: what you see is memmove OUTPUT, so a dropped index high byte
// still streaks the picture. (Reading the injection end would show data the memmove never touched,
// which would look identical while proving nothing.) The visible sequence is unchanged, just
// delayed 7 steps. See docs/investigations/2026-07-27-60fps-demo-sweep.md (F2) and the #99c plan.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/hdma_hscroll.h"
#include "../65816/mvscrl.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 27   // bottom band scrolls +16, so row 27 lands at the old row-25 spot
#define NCOL        4
#define NTILES_W    16
#define NTILES_H    16
#define UPPER_ROWS  8u   // tile rows 0..7: scroll DOWN (memmove descending)
#define LOWER_ROWS  8u   // tile rows 8..15: scroll UP  (memmove ascending)
// Ring geometry. Each half is 8 tile rows = 64 px; the window shows 7 rows = 56 px and the 8th is
// the off-screen staging row. Screen bands (sum 224): 48 title/HUD @ vofs 0 · 56 upper window ·
// 56 lower window · 64 bottom @ vofs +16 (clears the canvas so the HUD sits where it always did).
#define RING_PX     64u
#define VIS_PX      56u
#define RING_SLACK  (RING_PX - VIS_PX)   /* 8 px = the staging row */
#define TOP_LINES   48u
#define BOT_LINES   64u
#define CH_VSCROLL  6    // HDMA ch6; upq's GP-DMA is ch0 and the title's channels are off by then

// 4-colour slab palette.
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 2,  2, 14),    // 0: deep indigo
    SNES_RGB( 4, 20, 16),    // 1: teal
    SNES_RGB(26, 12,  2),    // 2: orange
    SNES_RGB(28, 22,  2),    // 3: gold
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    MVState      mv;
    HScrollDB    vdb;      // double-buffered vscroll band tables (bank-0 bss)
    uint16_t     t;        // animation tick (= seed for next scroll step)
    uint8_t      pos;      // upper ring offset P in [0,64); lower runs the mirror (64-P)
} App;

volatile uint16_t corpus_result;


// Paint one canvas tile row from a memmove buffer row and dirty-mark just those 16 tiles (a 256 B
// flush). The picture MUST be a read of mv.upper/mv.lower — this demo's premise (#79) is that the
// visual IS the proof that G_MEMMOVE's Ascending and Descending paths moved the right bytes, so a
// decorative stand-in pattern would silently void it. corpus_result cannot catch that: the gate
// runs mvscrl_gate_crc() during the title, independently of this loop.
__attribute__((noinline))
static void paint_ring_row(App *a, uint8_t canvas_row, const uint8_t *src) {
    for (uint8_t cx = 0u; cx < (uint8_t)NTILES_W; cx++)
        canvas_fill_solid_tile(&a->canvas, cx, canvas_row, src[cx]);
    uint16_t lo = (uint16_t)((uint16_t)canvas_row * (uint16_t)CANVAS_TILES_W);
    uint16_t hi = (uint16_t)(lo + (uint16_t)(NTILES_W - 1));
    if (a->canvas.lo > lo) a->canvas.lo = lo;
    if (a->canvas.hi < hi) a->canvas.hi = hi;
}

// Rebuild the per-scanline BG3VOFS band table for ring offset P (into the half HDMA is NOT
// reading; committed through the v-blank queue). At scanline y the BG3 row shown is y + vofs.
// Upper ring occupies BG3 px 48..111, its window starts at scanline 48  -> vofs = P (wrap: P-64).
// Lower ring occupies BG3 px 112..175, its window starts at scanline 104 -> vofs = Q+8 (wrap: Q-56).
static void build_bands(App *a, HScrollN *t) {
    HScrollW w;
    uint8_t P = a->pos;                                              // upper: content flows DOWN
    uint8_t Q = (uint8_t)((RING_PX - P) & (uint8_t)(RING_PX - 1u));  // lower: mirror, flows UP
    hscrollw_begin(&w, t);
    hscrollw_band(&w, (uint8_t)TOP_LINES, (int16_t)0);
    if (P <= (uint8_t)RING_SLACK) {
        hscrollw_band(&w, (uint8_t)VIS_PX, (int16_t)P);
    } else {
        hscrollw_band(&w, (uint8_t)(RING_PX - P), (int16_t)P);
        hscrollw_band(&w, (uint8_t)(P - (uint8_t)RING_SLACK), (int16_t)((int16_t)P - (int16_t)RING_PX));
    }
    if (Q <= (uint8_t)RING_SLACK) {
        hscrollw_band(&w, (uint8_t)VIS_PX, (int16_t)((int16_t)Q + (int16_t)8));
    } else {
        hscrollw_band(&w, (uint8_t)(RING_PX - Q), (int16_t)((int16_t)Q + (int16_t)8));
        hscrollw_band(&w, (uint8_t)(Q - (uint8_t)RING_SLACK),
                      (int16_t)((int16_t)Q + (int16_t)8 - (int16_t)RING_PX));
    }
    hscrollw_band(&w, (uint8_t)BOT_LINES, (int16_t)16);
    hscrollw_end(&w);
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
    mv_init(&a->mv);
    a->t = (uint16_t)0u;
    a->pos = (uint8_t)0u;
    // Seed both rings coherently: at pos == 0 each window's top row is ring row 0, so canvas row r
    // holds buffer row r. From here on only staging rows are painted; the scroll does the rest.
    for (uint8_t r = 0u; r < (uint8_t)UPPER_ROWS; r++) {
        paint_ring_row(a, r, a->mv.upper[r]);
        paint_ring_row(a, (uint8_t)((uint8_t)UPPER_ROWS + r), a->mv.lower[r]);
    }
    text_puts(&a->text, 0, 2, "MEMMOVE SCROLL SLABS");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "G_MEMMOVE", "DESCEND+ASCEND");
    corpus_result = mvscrl_gate_crc();   // runs during title; expected 0x72A7
    title_end(&a.screen, &title, 90);
    update_hud(&a);
    build_bands(&a, &a.vdb.buf[0]);          // fill the live half before arming
    hscrolldb_arm(CH_VSCROLL, VSCROLL_BG3VOFS, &a.vdb);
    REG_HDMAEN = (uint8_t)(1u << CH_VSCROLL);   // after title_end, which writes HDMAEN = 0
    for (;;) {
        build_bands(&a, hscrolldb_back(&a.vdb));   // this frame's 1-px scroll step
        hscrolldb_commit(&a.vdb, &a.screen.q, CH_VSCROLL);
        uint8_t sub = (uint8_t)(a.pos & 7u);
        if (sub == 0u) {
            // One scroll step, then stage both rings' off-screen rows. This is the stress under
            // test — it must run. Read the FAR end of each buffer (upper[7] / lower[0]): those rows
            // have been carried by seven memmoves, so the picture is memmove output, not the
            // untouched injection.
            mv_step(&a.mv, a.t);
            a.t = (uint16_t)(a.t + (uint16_t)7u);
            uint8_t P = a.pos;
            uint8_t Q = (uint8_t)((RING_PX - P) & (uint8_t)(RING_PX - 1u));
            uint8_t up = (uint8_t)((uint8_t)((P >> 3) + 7u) & 7u);   // the one row fully off-screen
            uint8_t lo = (uint8_t)((uint8_t)((Q >> 3) + 7u) & 7u);
            paint_ring_row(&a, up, a.mv.upper[UPPER_ROWS - 1u]);
            paint_ring_row(&a, (uint8_t)((uint8_t)UPPER_ROWS + lo), a.mv.lower[0]);
        } else if (sub == 4u) {
            update_hud(&a);                  // staggered off the paint frame
        }
        display_frame(&a.screen);
        a.pos = (uint8_t)((a.pos == 0u) ? (uint8_t)(RING_PX - 1u) : (uint8_t)(a.pos - 1u));
    }
}
