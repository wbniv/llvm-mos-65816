// Overlap-Move Mosaic — #93 of the compiler stress-test battery (Round 6, Cluster A).
// Scrolls a 16×24 = 384-byte mosaic in place via four overlapping memmoves per step (both
// Descending dst>src and Ascending dst<src, each count > 256 → 16-bit index). Builds
// default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers → full 5-way bar).
//
// Codegen corners re-stressed:
//   (1) #23 / patch 0002 MOSInsertREPSEP::placeIntraBlock — the +mos-xy16 in-place-memmove
//       REP/SEP index-width miscompile (a stray sep #$10 zeroing a 16-bit X's high byte). The
//       >256-byte counts force the SDK memmove to index with a 16-bit X, the exact boundary.
//   (2) #79 mvscrl — G_MEMMOVE Descending + Ascending overlap sub-paths (:422 .custom()).
//
// Visual: a 16×16 window of the mosaic shown as solid 2bpp tiles; the four overlapping memmoves
// shear it down-right (descending steps) / up-left (ascending steps). A dropped index high byte
// would streak the mosaic — and diverge the gate CRC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/ovmove.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define BAND        4
#define WIN_W       16   // visible window columns (= mosaic width)
#define WIN_H       16   // visible window rows (top 16 of the 24-row mosaic)

// 4-colour mosaic palette.
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
    OVState      ov;
    uint16_t     t;      // animation tick = seed + direction (parity)
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
    uint8_t y0 = (uint8_t)((uint8_t)(a->band) * (uint8_t)BAND);
    for (uint8_t cy = y0; cy < (uint8_t)(y0 + (uint8_t)BAND) && cy < (uint8_t)WIN_H; cy++) {
        for (uint8_t cx = 0u; cx < (uint8_t)WIN_W; cx++) {
            cell_fill(&a->canvas, cx, cy, a->ov.cell[cy][cx]);
        }
    }
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
    ov_init(&a->ov);
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    text_puts(&a->text, 0, 2, "OVERLAP-MOVE MOSAIC");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "OVMOVE", "IN-PLACE MEMMOVE XY16");
    corpus_result = ovmove_gate_crc();   // runs during title; expected 0xA990
    title_end(&a.screen, &title, 90);
    for (;;) {
        // Alternate descending/ascending overlapping memmoves each step (>256B → 16-bit index).
        ov_step(&a.ov, a.t, (uint8_t)a.t);
        a.t = (uint16_t)(a.t + (uint16_t)1u);
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)WIN_H) {
            a.band = (uint8_t)0u;
            a.canvas.lo = (uint16_t)0u;                        // shadow complete: mark the WHOLE
            a.canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);      // canvas -> one atomic v-blank flush
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}
