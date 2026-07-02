// In-Place Block Rotate — #94 of the compiler stress-test battery (Round 6, Cluster A).
// Rotates a 384-entry uint16_t buffer left by a runtime k each step via the three-reversal
// identity (rev[0,k) . rev[k,n) . rev[0,n)), ALL IN PLACE. The reversal swap loop issues
// 16-bit-INDEXED loads/stores (indices 0..383 > 255) crossing the M/X width-flag boundary —
// re-stressing patch 0002 (MOSInsertREPSEP::placeIntraBlock, the #23 xy16 index-width fix) from
// a different angle than #93 ovmove (which used the SDK memmove libcall; here there is none).
// Builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> full 5-way bar).
//
// Visual: a 16×16 window of the 16×24 mosaic drawn as solid 2bpp tiles. Each cell's colour is
// the top 2 bits of its buffer entry (a diagonal barber-pole stripe); rotating the 1-D buffer
// marches the stripe -> a barber-pole marquee that shears without tearing. A dropped index high
// byte would streak the mosaic AND diverge the gate CRC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/rotslab.h"

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

// 4-colour barber-pole palette.
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
    ROTState     rot;
    uint16_t     t;      // animation tick (= step counter, feeds the runtime rotate k)
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
            uint16_t idx = (uint16_t)((uint16_t)cy * (uint16_t)ROT_W + (uint16_t)cx);
            uint8_t color = (uint8_t)((uint16_t)(a->rot.buf[idx] >> 14) & (uint16_t)3u);
            cell_fill(&a->canvas, cx, cy, color);
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

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    rot_init(&a->rot);
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    text_puts(&a->text, 0, 2, "IN-PLACE BLOCK ROTATE");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "ROTSLAB", "THREE-REVERSAL XY16");
    corpus_result = rotslab_gate_crc();   // runs during title; expected 0xB93A
    title_end(&a.screen, &title, 90);
    for (;;) {
        // Rotate the whole 384-entry buffer left by a small runtime k (16-bit-indexed reversal
        // swaps crossing the width-flag boundary). The barber-pole marches.
        uint16_t k = (uint16_t)((uint16_t)1u + (uint16_t)(a.t & (uint16_t)7u));
        rot_rotate_left(a.rot.buf, (uint16_t)ROT_N, k);
        a.t = (uint16_t)(a.t + (uint16_t)1u);
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)WIN_H) {
            a.band = (uint8_t)0u;
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}
