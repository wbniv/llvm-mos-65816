// Funnel-Shift Kaleidoscope — #73 of the compiler stress-test demo battery.
// Renders the portable funnel-shift mandala (examples/65816/funnelkal.h) into a
// 128x128 BG3 2bpp canvas; builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far
// pointers -> full 5-way bar).
//
// The codegen corner: G_FSHL/G_FSHR two-source funnel shift (.lower() at
// MOSLegalizerInfo.cpp:317) via __builtin_elementwise_fshl(A,B,k)/fshr with A!=B,
// so matchFunnelShiftToRotate cannot fold them to G_ROTL/G_ROTR.  The "terrible"
// default double-source shift+or expansion fires for both directions — the only
// path that exercises the uncommented "this is terrible" lowering comment at :314-316
// in the LLVM legalizer helper.  A codegen corner none of the first 72 demos ever ran.
//
// Visual: 8-fold-symmetric kaleidoscope mandala on the 128x128 canvas, updated 4
// tile-rows per frame (4-frame refresh cycle).  The 4-colour BG3 palette gives vivid
// cyan/magenta/yellow petals on a dark background; as the animation tick advances the
// funnel-shift count k changes and petals rotate/reweave.  A TextLayer HUD shows
// the live funnel count k and the corpus CRC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256       // full 16x16 = 256 tiles flush in one v-blank
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/funnelkal.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8               // canvas X offset in tiles (pixel x=64)
#define BOX_ROW     6               // canvas Y offset in tiles (pixel y=48)
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4               // BG3 2bpp: 4 colours
#define BAND        4               // tile-rows updated per frame (4 rows x 16 tiles = 64 tiles)
#define NTILES_W    16              // 128 / 8 = 16 tiles wide
#define NTILES_H    16              // 128 / 8 = 16 tiles tall

// BG3 2bpp palette (CGRAM 0..3): dark blue -> cyan -> hot pink -> bright yellow.
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(1, 1, 8),           // 0: dark blue background
    SNES_RGB(4, 28, 28),         // 1: bright cyan
    SNES_RGB(28, 4, 26),         // 2: hot pink / magenta
    SNES_RGB(28, 26, 2),         // 3: bright yellow / gold
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;              // animation tick (increments each frame)
    uint16_t     t_snap;        // tick captured at start of each band cycle
    uint8_t      band;           // which group of BAND rows to update this frame
} App;

volatile uint16_t corpus_result;  // funnel-shift gate CRC (read by differential gate)

// Fill an 8x8 tile at grid position (cx,cy) with solid 2bpp colour idx (0..3).
static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
    uint16_t tile = (uint16_t)((uint16_t)cy * (uint16_t)CANVAS_TILES_W + (uint16_t)cx);
    uint8_t *t = &cv->chr[tile * (uint16_t)CANVAS_TILEBYTES];
    uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
    uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
    for (uint8_t r = 0u; r < 8u; r++) { t[r * 2u] = p0; t[r * 2u + 1u] = p1; }
}

// Update one BAND of tile-rows from the funnel-shift mandala at snapshot tick t_snap.
__attribute__((noinline))
static void field_band(App *a, uint16_t t_snap) {
    uint8_t y0 = (uint8_t)((uint8_t)(a->band) * (uint8_t)BAND);
    for (uint8_t cy = y0; cy < (uint8_t)(y0 + (uint8_t)BAND) && cy < (uint8_t)NTILES_H; cy++) {
        for (uint8_t cx = 0u; cx < (uint8_t)NTILES_W; cx++) {
            uint16_t v   = fk_cell((uint16_t)cx, (uint16_t)cy, t_snap);
            uint8_t  col = fk_color(v);
            cell_fill(&a->canvas, cx, cy, col);
        }
    }
    // Mark the updated band dirty in the canvas dirty-range.
    uint16_t lo = (uint16_t)((uint16_t)y0 * (uint16_t)CANVAS_TILES_W);
    uint16_t hi = (uint16_t)((uint16_t)(y0 + (uint8_t)BAND) * (uint16_t)CANVAS_TILES_W - (uint16_t)1u);
    if (hi >= (uint16_t)CANVAS_NTILES) hi = (uint16_t)(CANVAS_NTILES - 1u);
    if (a->canvas.lo > lo) a->canvas.lo = lo;
    if (a->canvas.hi < hi) a->canvas.hi = hi;
}

// Format a HUD line with the current funnel count k and the gate CRC.
static void update_hud(App *a) {
    // Bottom HUD: show funnel count k for center tile (tx=8, ty=8) at current tick.
    uint16_t k = fk_shift_k(
        (uint16_t)4u, (uint16_t)4u,   // octant (ox,oy) for center tile (tx=8,ty=8)
        a->t_snap);
    // Format "FSHL/FSHR K=XX" (16 chars to fill the 20-char line)
    char buf[21];
    buf[0]='F'; buf[1]='S'; buf[2]='H'; buf[3]='L'; buf[4]='/';
    buf[5]='F'; buf[6]='S'; buf[7]='H'; buf[8]='R'; buf[9]=' ';
    buf[10]='K'; buf[11]='=';
    buf[12]=(char)('0' + (char)((k / (uint16_t)10u) % (uint16_t)10u));
    buf[13]=(char)('0' + (char)(k  % (uint16_t)10u));
    buf[14]=' '; buf[15]=' '; buf[16]=' '; buf[17]=' '; buf[18]=' '; buf[19]=' '; buf[20]='\0';
    text_puts(&a->text, 1, 0, buf);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->t = (uint16_t)0u;
    a->t_snap = (uint16_t)0u;
    a->band = (uint8_t)0u;
    text_puts(&a->text, 0, 2, "FUNNEL-SHIFT KALEIDOSCOPE");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "FUNNEL-SHIFT", "FSHL/FSHR A!=B");
    corpus_result = funnelkal_gate_crc();  // runs during title hold; expected 0xEED4
    title_end(&a.screen, &title, 90);
    for (;;) {
        a.t++;
        field_band(&a, a.t_snap);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)NTILES_H) {
            a.band = (uint8_t)0u;
            a.t_snap = a.t;   // advance snapshot only after a full refresh cycle
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}
