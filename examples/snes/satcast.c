// Saturating-Cast Kaleidoscope — #77 of the compiler stress-test demo battery.
// Renders the portable satcast kaleidoscope (examples/65816/satcast.h) into a
// 128x128 BG3 2bpp canvas; builds default-8-bit AND +mos-a16 AND +mos-xy16
// (no far pointers -> full 5-way bar).
//
// The codegen corner:
//   fminf(32767.0f, x)   → G_FMINNUM  → SDK fminf  (math.cc:18)
//   fmaxf(-32768.0f, y)  → G_FMAXNUM  → SDK fmaxf  (math.cc:19)
//   (int16_t)hi          → G_FPTOSI   → legalizer :502 NaN guard
// First demo to exercise any fminf/fmaxf operation.
// Distinct from #44 hdr-bloom (integer saturation, G_UADDO, no float cast)
// and #59 cosmzoom (exact double round-trip, no clamp, no fmin/fmax).
//
// Visual: 6-fold hex kaleidoscope on the 128x128 canvas.  Each tile is mapped
// to hex axial coords (q,r,s=-q-r); sorting |q|,|r|,|s| folds to the first
// sextant for 6-fold symmetry.  Float intensity = a²·200 − b²·50 + phase_f:
// outer tiles (large hex distance) saturate to INT16_MAX → colour 3 (gold) or
// INT16_MIN → colour 0 (indigo) depending on phase_f.  The saturation boundary
// sweeps inward as phase advances, producing a crisp pulsing ring.
// Shadow update: one tile-row per frame; full canvas is still flushed atomically.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/satcast.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define BAND        1
#define NTILES_W    16
#define NTILES_H    16

// BG3 2bpp 4-colour palette: indigo / cyan / orange / gold.
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 2,  1, 12),    // 0: deep indigo (saturated negative)
    SNES_RGB( 4, 22, 24),    // 1: teal-cyan
    SNES_RGB(26, 14,  2),    // 2: warm orange
    SNES_RGB(28, 24,  2),    // 3: bright gold (saturated positive)
};

static const int32_t SAT_A2[17] = {
    0,200,800,1800,3200,5000,7200,9800,12800,16200,20000,24200,28800,33800,39200,45000,51200
};
static const int16_t SAT_B2[17] = {
    0,50,200,450,800,1250,1800,2450,3200,4050,5000,6050,7200,8450,9800,11250,12800
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;          // animation tick
    uint16_t     phase_raw;  // phase counter (wraps uint16)
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
    for (uint8_t cy = y0; cy < (uint8_t)(y0 + (uint8_t)BAND) && cy < (uint8_t)NTILES_H; cy++) {
        for (uint8_t cx = 0u; cx < (uint8_t)NTILES_W; cx++) {
            /* All operands in sc_tile_color are integral and exactly representable as float.
               Preserve the float clamp/cast path in satcast_gate_crc(), but evaluate the identical
               live colour with integers so live tiles do not invoke the soft-float runtime. */
            int16_t q = (int16_t)cx - 8, r = (int16_t)cy - 8, s = (int16_t)(-q-r);
            uint16_t aa = (uint16_t)(q < 0 ? -q : q);
            uint16_t bb = (uint16_t)(r < 0 ? -r : r);
            uint16_t cc = (uint16_t)(s < 0 ? -s : s), tt;
            if (aa < bb) { tt=aa; aa=bb; bb=tt; }
            if (bb < cc) { tt=bb; bb=cc; cc=tt; }
            if (aa < bb) { tt=aa; aa=bb; bb=tt; }
            int32_t iv = SAT_A2[aa] - SAT_B2[bb] + (int16_t)a->phase_raw;
            if (iv < -32768) iv=-32768; else if (iv > 32767) iv=32767;
            uint8_t col = (uint8_t)(((uint16_t)((int16_t)iv) + 32768u) >> 14);
            canvas_fill_solid_tile(&a->canvas, cx, cy, col);
        }
    }
}

// Format hex uint16 into 4-char buf.
static void fmt_hex16(char *buf, uint16_t v) {
    static const char H[] = "0123456789ABCDEF";
    buf[0] = H[(v >> 12) & 0xFu];
    buf[1] = H[(v >>  8) & 0xFu];
    buf[2] = H[(v >>  4) & 0xFu];
    buf[3] = H[ v        & 0xFu];
}

static void update_hud(App *a) {
    char buf[21];
    // "PHASE=XXXX CRC=XXXX "
    buf[0]='P'; buf[1]='H'; buf[2]='A'; buf[3]='S'; buf[4]='E'; buf[5]='=';
    fmt_hex16(buf + 6, a->phase_raw);
    buf[10]=' '; buf[11]='C'; buf[12]='R'; buf[13]='C'; buf[14]='=';
    fmt_hex16(buf + 15, corpus_result);
    buf[19]=' '; buf[20] = '\0';
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
    a->phase_raw = (uint16_t)0u;
    a->band = (uint8_t)0u;
    text_puts(&a->text, 0, 2, "SATURATING-CAST KALEIDOSCOPE");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "FMIN/FMAX", "G_FPTOSI SAT CAST");
    corpus_result = satcast_gate_crc();  // runs during title; expected 0xC8CF
    title_end(&a.screen, &title, 90);
    for (;;) {
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)NTILES_H) {
            a.band = (uint8_t)0u;
            a.canvas.lo = (uint16_t)0u;                        // shadow complete: mark the WHOLE
            a.canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);      // canvas -> one atomic v-blank flush
            a.phase_raw = (uint16_t)(a.phase_raw + (uint16_t)64u);
            a.t++;
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}
