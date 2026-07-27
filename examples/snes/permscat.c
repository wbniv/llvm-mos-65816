// Gather-Scatter Permutation — #95 of the compiler stress-test battery (Round 6, Cluster A).
// Scatters a 576-entry (>512) grid by dst[perm[i]] = src[i] each step, ping-ponging two buffers.
// The inner loop holds TWO 16-bit indices live at once — the loop counter i and the DATA-DEPENDENT
// scatter index pi = perm[i] — re-stressing patch 0002 (MOSInsertREPSEP::placeIntraBlock, the #23
// +mos-xy16 index-width fix) at its hardest. Under +mos-xy16 the scatter emits `sta abs,X` with a
// 16-bit index — the exact addressing shape the #23 bug corrupted (a stray sep #$10 zeroing X's
// high byte). Builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> full 5-way bar).
//
// Visual: a 16×16 window of the 24×24 grid drawn as solid 2bpp tiles; each step re-permutes the
// pattern, so it shuffles kaleidoscopically. perm is a bijection (pi=(i*5)%576), so every cell must
// land exactly once — a dropped index high byte would drop/duplicate a tile AND diverge the CRC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/permscat.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define BAND        4
#define WIN_W       16   // visible window columns
#define WIN_H       16   // visible window rows (top-left 16×16 of the 24×24 grid)

// 4-colour palette.
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
    uint16_t     t;      // step counter (= scatter phase)
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
    uint8_t *cur = ps_dest(a->t);   // the buffer written by the most recent ps_step
    uint8_t y0 = (uint8_t)((uint8_t)(a->band) * (uint8_t)BAND);
    for (uint8_t cy = y0; cy < (uint8_t)(y0 + (uint8_t)BAND) && cy < (uint8_t)WIN_H; cy++) {
        for (uint8_t cx = 0u; cx < (uint8_t)WIN_W; cx++) {
            uint16_t idx = (uint16_t)((uint16_t)cy * (uint16_t)PS_W + (uint16_t)cx);
            cell_fill(&a->canvas, cx, cy, (uint8_t)(cur[idx] & 3u));
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
    ps_init();
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    text_puts(&a->text, 0, 2, "GATHER-SCATTER PERM");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "PERMSCAT", "SCATTER INDEX XY16");
    corpus_result = permscat_gate_crc();   // runs during title; expected 0x0C2C
    title_end(&a.screen, &title, 90);
    ps_init();          // gate consumed the buffers; restart the live shuffle from the pattern
    a.t = (uint16_t)0u;
    for (;;) {
        // Scatter dst[perm[i]] = src[i] (two live 16-bit indices; abs,X store under xy16).
        // Idempotent within a band-draw cycle (src buffer unchanged) so the drawn buffer is stable;
        // the phase a.t advances only once the full 16-row window has been redrawn.
        ps_step(a.t);
        field_band(&a);          // reads ps_dest(a.t) = the buffer just written
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)WIN_H) {
            a.band = (uint8_t)0u;
            a.canvas.lo = (uint16_t)0u;                        // shadow complete: mark the WHOLE
            a.canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);      // canvas -> one atomic v-blank flush
            update_hud(&a);
            a.t = (uint16_t)(a.t + (uint16_t)1u);   // advance the permutation phase
        }
        display_frame(&a.screen);
    }
}
