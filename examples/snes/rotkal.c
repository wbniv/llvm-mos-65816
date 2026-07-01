// Rotate-Register Kaleidoscope — #74 of the compiler stress-test demo battery.
// Renders the portable rotate-register mandala (examples/65816/rotkal.h) into a
// 128x128 BG3 2bpp canvas; builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far
// pointers -> full 5-way bar).
//
// The codegen corner: G_ROTL/G_ROTR byte/16-bit custom lowering via
// __builtin_rotateleft8/right8/rotateleft16 with BOTH constant per-ring amounts
// (ConstantAmt fast path at legalizeShiftRotate:1046-1061, S8 special:1167-1178)
// and a runtime amount for the outer 16-bit word (variable-amount lowering path).
// The first demo to exercise __builtin_rotateleft*/rotateright* — confirmed absent
// from all 76 prior headers.
//
// Visual: 8-fold-symmetric kaleidoscope mandala on the 128x128 canvas.
// The 8 ring registers rotate at different constant speeds (1,2,3,1 bits/frame left;
// 1,2,3,1 bits/frame right), producing counter-rotating petals.  The outer 16-bit
// word rotates by a runtime amount k = (frame & 14)+1, XOR'ing the top 2 bits into
// the color, producing moire shimmer beats between rings.  The mandala is tiled
// 4-fold and refreshed in 4 row-bands per frame (64 tiles/frame, fits in V-blank).
// A TextLayer HUD shows the live outer word and the gate CRC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256       // full 16x16 = 256 tiles; band flush handles budget
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/rotkal.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8               // canvas X offset in tiles (pixel x=64)
#define BOX_ROW     6               // canvas Y offset in tiles (pixel y=48)
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4               // BG3 2bpp: 4 colours
#define BAND        4               // tile-rows updated per frame (64 tiles = 1024 B DMA)
#define NTILES_W    16
#define NTILES_H    16

// BG3 2bpp palette: dark indigo, cyan, magenta, gold.
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(2,  1, 10),           // 0: dark indigo background
    SNES_RGB(2,  26, 28),          // 1: bright cyan
    SNES_RGB(26,  2, 24),          // 2: hot magenta
    SNES_RGB(28, 24,  2),          // 3: bright gold
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    RKState      state;
    uint16_t     t;          // animation tick (increments each frame)
    uint8_t      band;       // which group of BAND rows to update this frame
} App;

volatile uint16_t corpus_result;  // rotate gate CRC (read by differential gate)

// Fill an 8x8 tile at grid position (cx,cy) with solid 2bpp colour idx (0..3).
static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
    uint16_t tile = (uint16_t)((uint16_t)cy * (uint16_t)CANVAS_TILES_W + (uint16_t)cx);
    uint8_t *t = &cv->chr[tile * (uint16_t)CANVAS_TILEBYTES];
    uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
    uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
    for (uint8_t r = 0u; r < 8u; r++) { t[r * 2u] = p0; t[r * 2u + 1u] = p1; }
}

// Update one BAND of tile-rows from the current kaleidoscope state.
__attribute__((noinline))
static void field_band(App *a) {
    uint8_t y0 = (uint8_t)((uint8_t)(a->band) * (uint8_t)BAND);
    for (uint8_t cy = y0; cy < (uint8_t)(y0 + (uint8_t)BAND) && cy < (uint8_t)NTILES_H; cy++) {
        for (uint8_t cx = 0u; cx < (uint8_t)NTILES_W; cx++) {
            uint8_t col = rk_cell(&a->state, (uint16_t)cx, (uint16_t)cy);
            cell_fill(&a->canvas, cx, cy, col);
        }
    }
    uint16_t lo = (uint16_t)((uint16_t)y0 * (uint16_t)CANVAS_TILES_W);
    uint16_t hi = (uint16_t)((uint16_t)(y0 + (uint8_t)BAND) * (uint16_t)CANVAS_TILES_W - (uint16_t)1u);
    if (hi >= (uint16_t)CANVAS_NTILES) hi = (uint16_t)(CANVAS_NTILES - (uint16_t)1u);
    if (a->canvas.lo > lo) a->canvas.lo = lo;
    if (a->canvas.hi < hi) a->canvas.hi = hi;
}

// Format hex uint8 into buf[2].
static void fmt_hex8(char *buf, uint8_t v) {
    static const char HEX[] = "0123456789ABCDEF";
    buf[0] = HEX[(v >> 4) & 0xFu];
    buf[1] = HEX[v & 0xFu];
}

// Format hex uint16 into buf[4].
static void fmt_hex16(char *buf, uint16_t v) {
    fmt_hex8(buf,     (uint8_t)(v >> 8));
    fmt_hex8(buf + 2, (uint8_t)(v & 0xFFu));
}

// Update bottom HUD with outer word and ring samples.
static void update_hud(App *a) {
    char buf[21];
    // "OUT=XXXX R0=XX R1=XX"
    buf[0]='O'; buf[1]='U'; buf[2]='T'; buf[3]='=';
    fmt_hex16(buf + 4, a->state.outer);
    buf[8]=' '; buf[9]='R'; buf[10]='0'; buf[11]='=';
    fmt_hex8(buf + 12, a->state.ring[0]);
    buf[14]=' '; buf[15]='R'; buf[16]='1'; buf[17]='=';
    fmt_hex8(buf + 18, a->state.ring[1]);
    buf[20] = '\0';
    text_puts(&a->text, 1, 0, buf);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    rk_init(&a->state);
    a->t    = (uint16_t)0u;
    a->band = (uint8_t)0u;
    text_puts(&a->text, 0, 2, "ROTATE-REG KALEIDOSCOPE");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "ROTL/ROTR", "CONST + RUNTIME");
    corpus_result = rotkal_gate_crc();  // runs during title hold; expected 0x300C
    title_end(&a.screen, &title, 90);
    for (;;) {
        // Advance state: runtime k = (t & 14) + 1 (1..15, always non-zero).
        uint16_t k = (uint16_t)((uint16_t)(a.t & (uint16_t)14u) + (uint16_t)1u);
        rk_step(&a.state, k);
        a.t++;
        // Update one band of tiles.
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)NTILES_H) {
            a.band = (uint8_t)0u;
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}
