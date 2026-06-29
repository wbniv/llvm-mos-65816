// Sorting Race SNES demo — #17 of the compiler stress-test demo battery.
//
// Three classic comparison sorts race on the SAME shuffled array of 32 bars, stacked as three
// full-width bands (quicksort=red, heapsort=green, mergesort=blue). The recursion / soft-stack /
// frame-ABI stress lives in examples/65816/sort-race.h: sr_qsort + sr_msort are genuinely
// recursive (a pointer into the caller's array lives across the self-jsr), sr_hsort is the
// iterative contrast. corpus_result = sortrace_gate_crc() is the differential proof (8 rounds,
// each asserting all three sorts agree on the identity permutation).
//
// Animation is record/replay: at the start of each pass every sort runs to completion writing an
// op-log of (position := value) stores; the frame loop replays one op per algorithm per frame and
// repaints just the touched bar column. This keeps REAL recursion as the compiler stress while
// giving smooth animation (an iterative/explicit-stack rewrite would have erased the recursion).
//
// No far pointers, all state in bank-0/7E WRAM → builds default-8-bit AND +mos-a16 AND +mos-xy16
// → 5-way differential bar. See docs/plans/2026-06-28-17-snes-sort-race.md.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/drawable.h"
#include "snesgfx/upload.h"
#include "snesgfx/vram.h"
#include "snesgfx/title_layer.h"
#include "font8.h"
#include "../65816/sort-race.h"

// ---------------------------------- layout --------------------------------------------------

#define RF_COLS     32        // full screen width in tiles (one bar per column → SR_N == 32)
#define RF_ROWS     28        // full screen height in tiles
#define RF_MAP      0x4000u   // BG3 tilemap base word
#define FONT_BASE   256       // first font glyph tile# (font8 glyphs loaded here)
#define BAND_H      7         // tile rows per band
#define BAND_PX     (BAND_H * 8)   // 56 px tall

#define TITLE_ROW   0
#define FOOTER_ROW  27
// Band b (0=quick,1=heap,2=merge): bars in rows BAND_TOP..BAND_TOP+6, label on LABEL_ROW.
static const uint8_t BAND_TOP[3]   = { 2, 10, 18 };
static const uint8_t LABEL_ROW[3]  = { 9, 17, 25 };
static const uint8_t BAND_PAL[3]   = { 1, 2, 3 };          // BG3 2bpp palette → red / green / blue
static const char *const BAND_NAME[3] = { "QUICK", "HEAP ", "MERGE" };

// BG3 2bpp CGRAM: 4 palettes × 4 colours (indices 0..15). Pixel value 0 is transparent on a BG
// (shows the CGRAM[0] backdrop), so only colour 1 of each palette matters:
//   pal0 col1 = white (text), pal1 = red (quick), pal2 = green (heap), pal3 = blue (merge).
static const uint16_t sr_pal[16] = {
    SNES_RGB(0, 0, 0),  SNES_RGB(31, 31, 31), SNES_RGB(12, 12, 12), SNES_RGB(0, 24, 28),
    SNES_RGB(0, 0, 0),  SNES_RGB(31,  6,  6), SNES_RGB(0,  0,  0),  SNES_RGB(0,  0,  0),
    SNES_RGB(0, 0, 0),  SNES_RGB(8,  31,  8), SNES_RGB(0,  0,  0),  SNES_RGB(0,  0,  0),
    SNES_RGB(0, 0, 0),  SNES_RGB(9,  16, 31), SNES_RGB(0,  0,  0),  SNES_RGB(0,  0,  0),
};

// ---------------------------------- RaceField drawable --------------------------------------
// One custom Drawable owns the entire BG3 screen (bars + all text). Fill tiles 0..8 (bottom-up
// 2bpp fill levels) are generated procedurally in reserve(); font8 glyphs live at FONT_BASE.

typedef struct {
    Drawable base;
    uint16_t map_word;
    uint16_t shadow[RF_ROWS * RF_COLS];   // BG3 tilemap mirror (896 words)
    uint32_t dirty;                       // bit r → tilemap row r needs re-DMA (28 bits)
} RaceField;

static void _rf_reserve(Drawable *d, VramAlloc *va) {
    (void)va;
    RaceField *f = (RaceField *)d;
    // BG3 layer registers: tilemap base + char base (low nibble of BG34NBA; char base word 0).
    REG_BG3SC   = SNES_BGSC(f->map_word, 0);
    REG_BG34NBA = (uint8_t)0x00u;
    // Fill tiles 0..8 at char word 0: tile k fills the bottom k pixel-rows (colour 1 = plane 0).
    snes_vram_addr(0x0000u);
    for (uint8_t k = 0; k <= 8u; k++)
        for (uint8_t row = 0; row < 8u; row++)
            REG_VMDATA = (row >= (uint8_t)(8u - k)) ? 0x00FFu : 0x0000u;
    // Font8 glyphs at tile FONT_BASE (force-blank: direct VRAM write OK).
    snes_vram_addr((uint16_t)(FONT_BASE * 8));
    for (uint16_t i = 0; i < (uint16_t)FONT8_N * 8u; i++) REG_VMDATA = FONT8[i];
    f->base.tm_bits = TM_BG3;
    f->dirty = (uint32_t)((1uL << RF_ROWS) - 1uL);   // DMA the whole screen on the first emit()
}

static void _rf_emit(Drawable *d, UploadQueue *q) {
    RaceField *f = (RaceField *)d;
    for (uint8_t r = 0; r < RF_ROWS && q->n < UPQ_MAX_JOBS; r++) {
        if (!(f->dirty & (uint32_t)(1uL << r))) continue;
        upq_push_vram(q, (uint16_t)(f->map_word + (uint16_t)r * RF_COLS),
                      &f->shadow[(uint16_t)r * RF_COLS], 0x00u,
                      RF_COLS * 2u, VMAIN_INC_HIGH_1);
        f->dirty &= ~(uint32_t)(1uL << r);
    }
}

static const DrawableVT RF_VT = { _rf_reserve, _rf_emit };

static void rf_init(RaceField *f, uint16_t map_word) {
    f->base.vt = &RF_VT;
    f->base.tm_bits = TM_BG3;
    f->map_word = map_word;
    for (uint16_t i = 0; i < RF_ROWS * RF_COLS; i++) f->shadow[i] = (uint16_t)FONT_BASE;  // spaces
    f->dirty = 0;
}

static inline uint16_t _glyph(char c) {
    uint8_t ch = (uint8_t)c;
    return (ch >= FONT8_FIRST && ch < (uint8_t)(FONT8_FIRST + FONT8_N))
              ? (uint16_t)(FONT_BASE + (ch - FONT8_FIRST)) : (uint16_t)FONT_BASE;
}

static inline void rf_putc(RaceField *f, uint8_t row, uint8_t col, char c) {
    if (row >= RF_ROWS || col >= RF_COLS) return;
    f->shadow[(uint16_t)row * RF_COLS + col] = _glyph(c);
    f->dirty |= (uint32_t)(1uL << row);
}

static void rf_puts(RaceField *f, uint8_t row, uint8_t col, const char *s) {
    for (; *s && col < RF_COLS; s++, col++) rf_putc(f, row, col, *s);
}

// Right-justified unsigned, space-padded to `width` (<= 5), into row/col.
static void rf_putu(RaceField *f, uint8_t row, uint8_t col, uint16_t v, uint8_t width) {
    char buf[6];
    uint8_t p = width;
    buf[width] = 0;
    do { buf[--p] = (char)('0' + (uint8_t)(v % 10u)); v /= 10u; } while (v && p > 0);
    while (p > 0) buf[--p] = ' ';
    rf_puts(f, row, col, buf);
}

// Repaint bar `col` of band `b` to value `v` (0..SR_N-1): a bottom-up column of fill tiles.
static void rf_bar(RaceField *f, uint8_t b, uint8_t col, uint16_t v) {
    uint8_t  top = BAND_TOP[b];
    uint16_t pal = (uint16_t)BAND_PAL[b] << 10;
    uint16_t hpx = (uint16_t)(1u + (uint16_t)(v * (uint16_t)(BAND_PX - 1)) / (uint16_t)(SR_N - 1u));
    for (uint8_t cb = 0; cb < BAND_H; cb++) {
        uint8_t  r    = (uint8_t)(top + (BAND_H - 1) - cb);
        uint16_t base = (uint16_t)((uint16_t)cb * 8u);
        uint16_t fill = (hpx > base) ? (uint16_t)(hpx - base) : 0u;
        if (fill > 8u) fill = 8u;
        f->shadow[(uint16_t)r * RF_COLS + col] = (uint16_t)(fill | pal);
        f->dirty |= (uint32_t)(1uL << r);
    }
}

// ---------------------------------- application ---------------------------------------------

#define OPS_CAP        512u   // per-algorithm op-log capacity (max observed moves ~282 for N=32)
#define OPS_PER_FRAME  1u     // replay rate — 1 op/algo/frame is watchable
#define HOLD_FRAMES    150u   // pause on the finished race before reshuffling

typedef struct {
    Display   d;
    RaceField field;
    uint16_t  live[3][SR_N];      // current displayed values
    uint16_t  ops[3][OPS_CAP];    // op-logs (one per algorithm)
    uint16_t  nops[3];            // op count
    uint16_t  cur[3];             // replay cursor
    uint16_t  cmps[3];            // pass comparison total (HUD)
    uint8_t   done[3];
    int8_t    winner;             // first algorithm to finish this pass; -1 = none yet
    uint16_t  hold;               // post-finish countdown
    uint16_t  seed;               // animation RNG seed (advances each pass)
    uint16_t  pass;               // pass counter
} App;

volatile uint16_t corpus_result;  // differential proof channel (read from WRAM by the gate)

static void race_label(App *a, uint8_t k) {
    uint8_t row = LABEL_ROW[k];
    rf_puts(&a->field, row, 0, BAND_NAME[k]);
    rf_putc(&a->field, row, 6, 'M');
    rf_putu(&a->field, row, 7, a->cur[k], 4);
    rf_putc(&a->field, row, 12, 'C');
    rf_putu(&a->field, row, 13, a->cmps[k], 4);
    rf_puts(&a->field, row, 18, a->done[k] ? "DONE" : "    ");
}

static void race_footer(App *a) {
    if (a->winner >= 0) {
        rf_puts(&a->field, FOOTER_ROW, 0, "WINNER: ");
        rf_puts(&a->field, FOOTER_ROW, 8, BAND_NAME[(uint8_t)a->winner]);
    } else {
        rf_puts(&a->field, FOOTER_ROW, 0, "RACING...   ");
    }
}

// Start a new pass: shuffle, run all three sorts to completion recording op-logs, paint the
// initial (unsorted) bars + HUD. The runtime sorts here re-exercise the recursion every pass.
static void race_new_pass(App *a) {
    uint16_t st = a->seed;
    uint16_t base[SR_N];
    sr_shuffle(base, (uint8_t)SR_N, &st);
    a->seed = st;
    a->pass++;

    for (uint8_t k = 0; k < 3; k++) {
        uint16_t work[SR_N];
        for (uint8_t i = 0; i < SR_N; i++) { work[i] = base[i]; a->live[k][i] = base[i]; }
        SortTrace t;
        sr_trace_init(&t, a->ops[k], OPS_CAP);
        if      (k == 0) sr_qsort(work, 0, (int16_t)(SR_N - 1), &t);
        else if (k == 1) sr_hsort(work, (int16_t)SR_N, &t);
        else { uint16_t tmp[SR_N]; sr_msort(work, tmp, 0, (int16_t)(SR_N - 1), &t); }
        a->nops[k] = t.nops;
        a->cmps[k] = t.cmps;
        a->cur[k]  = 0;
        a->done[k] = 0;
    }
    a->winner = -1;
    a->hold   = 0;

    rf_puts(&a->field, TITLE_ROW, 0, "SORTING RACE");
    rf_puts(&a->field, TITLE_ROW, 22, "PASS");
    rf_putu(&a->field, TITLE_ROW, 27, a->pass, 3);
    for (uint8_t k = 0; k < 3; k++) {
        for (uint8_t c = 0; c < SR_N; c++) rf_bar(&a->field, k, c, a->live[k][c]);
        race_label(a, k);
    }
    race_footer(a);
}

static void race_step(App *a) {
    if (a->hold) { if (--a->hold == 0) race_new_pass(a); return; }

    uint8_t all_done = 1;
    for (uint8_t k = 0; k < 3; k++) {
        if (a->done[k]) continue;
        for (uint8_t s = 0; s < OPS_PER_FRAME && a->cur[k] < a->nops[k]; s++) {
            uint16_t op  = a->ops[k][a->cur[k]++];
            uint8_t  pos = (uint8_t)(op >> 8);
            uint16_t val = (uint16_t)(op & 0xFFu);
            a->live[k][pos] = val;
            rf_bar(&a->field, k, pos, val);
        }
        if (a->cur[k] >= a->nops[k]) {
            a->done[k] = 1;
            if (a->winner < 0) { a->winner = (int8_t)k; race_footer(a); }
        } else {
            all_done = 0;
        }
        race_label(a, k);
    }
    if (all_done) a->hold = HOLD_FRAMES;
}

static void app_init(App *a) {
    display_init(&a->d);
    rf_init(&a->field, RF_MAP);
    display_add(&a->d, (Drawable *)&a->field);          // reserve: BG3 regs + tiles + font
    upq_push_cgram(&a->d.q, 0, sr_pal, 0x00u, (uint8_t)sizeof sr_pal);
    a->seed = 0x1234u;
    a->pass = 0;
    race_new_pass(a);
}

int main(void) {
    static App a;
    app_init(&a);

    // Title overlay (BG2), added after the demo layer; held during the gate CRC, then torn down.
    static TitleLayer title;
    title_init(&title, "SORTING RACE", "QUICK HEAP MERGE");
    display_add(&a.d, (Drawable *)&title);
    display_frame(&a.d);

    // Self-verify: the differential gate hash (8 rounds of recursive sorts + self-check).
    corpus_result = sortrace_gate_crc();

    display_hold(&a.d, 80);
    display_hide_layer(&a.d, (Drawable *)&title);

    for (;;) {
        race_step(&a);
        display_frame(&a.d);
    }
}
