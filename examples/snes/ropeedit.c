// Gap-Buffer Rope Editor — #96 of the compiler stress-test battery (Round 6, Cluster A, final).
// A text gap buffer whose cursor moves memmove the intervening text across the gap — both
// directions, >256 bytes each (16-bit offset) — driven by a scripted edit stream. Re-stresses
// patch 0002 (MOSInsertREPSEP::placeIntraBlock, the #23 +mos-xy16 in-place-memmove index-width fix)
// AT SCALE, as a real editor primitive. Builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far
// pointers -> full 5-way bar).
//
// Visual: the 576-byte buffer drawn as a 16×16 window of solid 2bpp colour cells (colour by byte
// class); as the cursor jumps and text is typed/deleted, the coloured text blocks slide across the
// gap. A dropped 16-bit-offset high byte would smear the text AND diverge the gate CRC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/ropeedit.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define BAND        4
#define GRID_W      24   // 576 = 24×24
#define WIN_W       16
#define WIN_H       16

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 2,  2, 14),    // 0: deep indigo (gap / fill '.')
    SNES_RGB( 4, 20, 16),    // 1: teal
    SNES_RGB(26, 12,  2),    // 2: orange
    SNES_RGB(28, 22,  2),    // 3: gold
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    Rope         rope;
    uint16_t     seed;
    uint16_t     t;
    uint8_t      band;
} App;

volatile uint16_t corpus_result;

// Colour by byte class: '.' (fill) -> 0 dark; typed text -> 1..3 by value.
static inline uint8_t byte_color(uint8_t b) {
    if (b == RE_FILL) return 0u;
    return (uint8_t)(1u + (uint8_t)(b % 3u));
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
    for (uint8_t cy = y0; cy < (uint8_t)(y0 + (uint8_t)BAND) && cy < (uint8_t)WIN_H; cy++) {
        for (uint8_t cx = 0u; cx < (uint8_t)WIN_W; cx++) {
            uint16_t idx = (uint16_t)((uint16_t)cy * (uint16_t)GRID_W + (uint16_t)cx);
            cell_fill(&a->canvas, cx, cy, byte_color(a->rope.buf[idx]));
        }
    }
    uint16_t lo = (uint16_t)((uint16_t)y0 * (uint16_t)CANVAS_TILES_W);
    uint16_t hi = (uint16_t)((uint16_t)(y0 + (uint8_t)BAND) * (uint16_t)CANVAS_TILES_W - (uint16_t)1u);
    if (hi >= (uint16_t)CANVAS_NTILES) hi = (uint16_t)(CANVAS_NTILES - (uint16_t)1u);
    if (a->canvas.lo > lo) a->canvas.lo = lo;
    if (a->canvas.hi < hi) a->canvas.hi = hi;
}

// One live edit op: jump the cursor (memmove), type a run, delete a couple.
static void rope_step(App *a) {
    a->seed ^= (uint16_t)(a->seed << 7); a->seed ^= (uint16_t)(a->seed >> 9); a->seed ^= (uint16_t)(a->seed << 8);
    uint16_t tl  = re_textlen(&a->rope);
    uint16_t pos = (uint16_t)(a->seed % (uint16_t)(tl + (uint16_t)1u));
    re_move(&a->rope, pos);
    for (uint16_t j = (uint16_t)0u; j < (uint16_t)6u; j++)
        re_insert(&a->rope, (uint8_t)((uint8_t)0x61u + (uint8_t)((uint16_t)((uint16_t)a->t + j) % (uint16_t)26u)));
    re_delete(&a->rope); re_delete(&a->rope);
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

static void live_reset(App *a) {
    re_init(&a->rope);
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)480u; i++)
        re_insert(&a->rope, (uint8_t)((uint8_t)0x41u + (uint8_t)((uint16_t)i % (uint16_t)26u)));
    a->seed = (uint16_t)0xBEEFu;
    a->t = (uint16_t)0u;
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->band = (uint8_t)0u;
    live_reset(a);
    text_puts(&a->text, 0, 2, "GAP-BUFFER ROPE EDITOR");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "ROPEEDIT", "GAP-BUFFER MEMMOVE XY16");
    corpus_result = ropeedit_gate_crc();   // runs during title; expected 0x2361
    title_end(&a.screen, &title, 90);
    live_reset(&a);          // the gate consumed a Rope; restart the live editor
    for (;;) {
        // One scripted edit op per band cycle so the drawn buffer is stable while it's drawn.
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)WIN_H) {
            a.band = (uint8_t)0u;
            rope_step(&a);
            a.t = (uint16_t)(a.t + (uint16_t)1u);
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}
